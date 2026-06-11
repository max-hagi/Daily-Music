//
//  TodayDropWidget.swift
//  DailyMusicWidget
//
//  "Today's Drop" — today's hand-picked song on the Home/Lock Screen. The
//  timeline provider fetches the public daily_entries row straight from
//  Supabase REST (anon key; same public data the sign-in cover wall reads),
//  so no app-group plumbing is needed. Tapping anywhere deep-links to the
//  Today tab via dailymusic://today (handled in RootView).
//

import SwiftUI
import WidgetKit

// MARK: - Timeline entry

struct TodayDropEntry: TimelineEntry {
    let date: Date
    let title: String?
    let artist: String?
    let artwork: UIImage?
    /// Current streak from the app's shared snapshot; nil = unknown/stale → hidden.
    var streak: Int? = nil

    /// nil title = nothing published yet → the "incoming" look.
    var hasDrop: Bool { title != nil }

    static let placeholder = TodayDropEntry(
        date: .now, title: "Song of the Day", artist: "Daily Music", artwork: nil, streak: 7
    )
    static let pending = TodayDropEntry(date: .now, title: nil, artist: nil, artwork: nil)
}

/// Reads the streak snapshot the app publishes into the App Group. The widget
/// never computes streaks (check_ins lives behind auth) — and it hides the
/// flame once the snapshot can no longer be trusted (past its valid-through
/// day the streak may have broken while the app stayed closed).
enum SharedStreakReader {
    // Keep in sync with the app's SharedStreak (Daily Music/Services/SharedStreak.swift).
    static let suiteName = "group.maxhagi.Daily-Music"

    static func currentStreak(asOf now: Date = Date()) -> Int? {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        let current = defaults.integer(forKey: "shared.streak.current")
        guard current > 0,
              let validThrough = defaults.string(forKey: "shared.streak.validThrough")
        else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        guard let limit = formatter.date(from: validThrough),
              Calendar.current.startOfDay(for: now) <= limit
        else { return nil }

        return current
    }
}

// MARK: - Provider

struct TodayDropProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayDropEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TodayDropEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { completion(await TodayDropFetcher.fetchToday() ?? .pending) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayDropEntry>) -> Void) {
        Task {
            let calendar = Calendar.current
            let entry = await TodayDropFetcher.fetchToday()

            // Got today's drop → next refresh shortly after local midnight (the
            // next drop). Nothing yet (not published / offline) → retry in 30 min.
            let refresh: Date
            if entry != nil {
                let startOfToday = calendar.startOfDay(for: Date())
                let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday)
                refresh = (nextMidnight ?? Date().addingTimeInterval(86_400)).addingTimeInterval(5 * 60)
            } else {
                refresh = Date().addingTimeInterval(30 * 60)
            }

            completion(Timeline(entries: [entry ?? .pending], policy: .after(refresh)))
        }
    }
}

// MARK: - Fetch (public catalog row, anon key, no auth)

enum TodayDropFetcher {
    private struct Row: Decodable {
        let title: String
        let artist: String
        let album_art_url: String?
    }

    static func fetchToday() async -> TodayDropEntry? {
        guard var components = URLComponents(
            url: SupabaseConfig.url.appendingPathComponent("rest/v1/daily_entries"),
            resolvingAgainstBaseURL: false
        ) else { return nil }

        // Mirrors SupabaseEntryService.todayEntry(): today's date in the local
        // calendar, only rows whose published_at has passed.
        components.queryItems = [
            URLQueryItem(name: "select", value: "title,artist,album_art_url"),
            URLQueryItem(name: "date", value: "eq.\(Self.dayString(for: Date()))"),
            URLQueryItem(name: "published_at", value: "lte.\(ISO8601DateFormatter().string(from: Date()))"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let row = (try? JSONDecoder().decode([Row].self, from: data))?.first
        else { return nil }

        return TodayDropEntry(
            date: Date(),
            title: row.title,
            artist: row.artist,
            artwork: await fetchArtwork(from: row.album_art_url),
            streak: SharedStreakReader.currentStreak()
        )
    }

    private static func fetchArtwork(from urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url)
        else { return nil }
        return UIImage(data: data)
    }

    private static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

// MARK: - Widget

struct TodayDropWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayDropWidget", provider: TodayDropProvider()) { entry in
            TodayDropWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Drop")
        .description("Today's hand-picked song, right on your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Views

struct TodayDropWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayDropEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: accessory
            case .systemMedium: medium
            default: small
            }
        }
        .widgetURL(URL(string: "dailymusic://today"))
    }

    // Small: full-bleed artwork with a scrim, title bottom-aligned.
    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let streak = entry.streak {
                streakPill(streak)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Spacer(minLength: 0)
            Text("TODAY")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .opacity(0.8)
            Text(entry.title ?? "New drop incoming")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            if let artist = entry.artist {
                Text(artist)
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.8)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .containerBackground(for: .widget) { artworkBackground }
    }

    // Medium: artwork tile on the left, text on the right.
    private var medium: some View {
        HStack(spacing: 14) {
            artworkTile
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("TODAY'S DROP")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .opacity(0.75)
                    if let streak = entry.streak {
                        streakPill(streak)
                    }
                }
                Text(entry.title ?? "New drop incoming")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if let artist = entry.artist {
                    Text(artist)
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.8)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(entry.hasDrop ? "Listen now" : "Check back soon")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .opacity(0.7)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { brandGradient }
    }

    // Lock Screen rectangular: text only, system styling.
    private var accessory: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("Today's drop", systemImage: "music.note")
                .font(.caption2.weight(.semibold))
            Text(entry.title ?? "Coming soon")
                .font(.headline)
                .lineLimit(1)
            if let artist = entry.artist {
                Text(artist)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }

    /// The streak flame, mirrored from the app's toolbar pill — the Home Screen
    /// is where "don't break it" lives between sessions.
    private func streakPill(_ streak: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.orange)
            Text("\(streak)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.black.opacity(0.35), in: Capsule())
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let artwork = entry.artwork {
            Image(uiImage: artwork)
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.16), .black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        } else {
            brandGradient
        }
    }

    @ViewBuilder
    private var artworkTile: some View {
        if let artwork = entry.artwork {
            Image(uiImage: artwork)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.14))
                Image(systemName: "music.note")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    // Matches the app's splash/sign-in gradient family.
    private var brandGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.24, blue: 0.43),
                Color(red: 0.35, green: 0.25, blue: 0.95),
                Color(red: 0.0, green: 0.7, blue: 0.86),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
