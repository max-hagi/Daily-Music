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

import ImageIO
import SwiftUI
import WidgetKit

// MARK: - Timeline entry

// WidgetKit does not render your SwiftUI view directly from app state. It asks
// the provider for one or more TimelineEntry values, then renders the widget
// from those frozen snapshots. This struct is that snapshot.

struct TodayDropEntry: TimelineEntry {
    
    // Required by TimelineEntry. WidgetKit uses this to decide which entry in a
    // timeline is active at a given moment.
    
    let date: Date

    /* These are optional because the widget has a "pending" state. When
    title/artist are nil, the UI intentionally says the next drop is incoming
    instead of showing stale song text. */
    
    let title: String?
    let artist: String?

    /* Widget extensions cannot rely on the main app's in-memory image cache, so
    the provider downloads artwork and stores the UIImage directly in the entry. */
   
    let artwork: UIImage?

    // Current streak from the app's shared snapshot; nil = unknown/stale → hidden.
    var streak: Int? = nil

    // nil title = nothing published yet → the "incoming" look.
    var released: Bool { title != nil }

    static let placeholder = TodayDropEntry(
        date: .now, title: "Song of the Day", artist: "Daily Music", artwork: nil, streak: 7
    )

    // The generic pending entry used for previews/snapshots. In the timeline
    // path below we usually create a custom pending entry with a precise date.
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
        // App Group UserDefaults is the bridge between the main app and widget.
        // Regular UserDefaults would be private to each target, so the widget
        // would never see values written by the app.
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }

        // integer(forKey:) returns 0 when the key is missing, so current > 0 is
        // both "there is a saved streak" and "the streak is worth showing."
        let current = defaults.integer(forKey: "shared.streak.current")

        // validThrough is a yyyy-MM-dd string written by the app. It tells the
        // widget how long the streak snapshot can be trusted if the app stays
        // closed and cannot recompute check-ins.
        guard current > 0,
              let validThrough = defaults.string(forKey: "shared.streak.validThrough")
        else { return nil }

        // The app stores validThrough as a day string, so parse it using the same
        // calendar/date format/time zone convention as SharedStreak.dayString.
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        // Compare start-of-day values, not exact timestamps. If validThrough is
        // "2026-06-13", the streak is valid for that whole local calendar day.
        guard let limit = formatter.date(from: validThrough),
              Calendar.current.startOfDay(for: now) <= limit
        else { return nil }

        return current
    }
}

// MARK: - Provider

struct TodayDropProvider: TimelineProvider {
    // Placeholder is what WidgetKit uses in the widget gallery and sometimes
    // while the real timeline is loading. It should be fast and offline.
    func placeholder(in context: Context) -> TodayDropEntry { .placeholder }

    // Snapshot is a single best-effort entry. WidgetKit asks for this in previews
    // and transient UI states; it is not the long-lived refresh schedule.
    func getSnapshot(in context: Context, completion: @escaping (TodayDropEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }

        // Network work is async, but WidgetKit's completion callback is not, so
        // we hop into a Task and call completion when the fetch finishes.
        Task { completion(await TodayDropFetcher.fetchToday() ?? .pending) }
    }

    // Timeline is the important path. This is where we give WidgetKit dated
    // entries and a reload policy. WidgetKit can display entries at their dates
    // even if it has not granted us another network refresh yet.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayDropEntry>) -> Void) {
        Task {
            // Capture one "now" and reuse it. That keeps the fetch/retry schedule
            // internally consistent instead of calling Date() several times.
            let calendar = Calendar.current
            let now = Date()

            // This asks Supabase for "today's row whose published_at has passed."
            // nil means either there is no row yet, it is not published yet, or
            // the network/JSON decode failed.
            let entry = await TodayDropFetcher.fetchToday()

            // Got today's drop → schedule a local pending state shortly after
            // midnight so stale content does not linger if WidgetKit delays the
            // network refresh. Nothing yet (not published / offline) → retry soon.
            if let entry {
                // The schedule helper contains only date math. Keeping that pure
                // makes this policy easier to test than a full WidgetKit provider.
                let schedule = TodayDropTimelineSchedule.loadedDropSchedule(now: now, calendar: calendar)

                // This is the stale-content fix. The first timeline entry is the
                // fetched song. The second entry is already queued for just after
                // the next midnight, so WidgetKit can switch to "New drop incoming"
                // locally even before it asks the network for the next song.
                let pendingAtRollover = TodayDropEntry(
                    date: schedule.rollover,
                    title: nil,
                    artist: nil,
                    artwork: nil,
                    streak: SharedStreakReader.currentStreak(asOf: schedule.rollover)
                )

                // .after is a request to reload after this date, not a guarantee.
                // The pending rollover entry is what protects us if iOS delays.
                completion(Timeline(entries: [entry, pendingAtRollover], policy: .after(schedule.reloadAfter)))
            } else {
                // If we could not get a song, do not wait until tomorrow. Ask for
                // another timeline soon so a late publish/network blip can recover.
                let retry = TodayDropTimelineSchedule.missingDropRetryDate(now: now)

                // Use a pending entry dated at the moment this timeline was built.
                // The UI will show "New drop incoming" / "Check back soon."
                let pending = TodayDropEntry(
                    date: now,
                    title: nil,
                    artist: nil,
                    artwork: nil,
                    streak: SharedStreakReader.currentStreak(asOf: now)
                )
                completion(Timeline(entries: [pending], policy: .after(retry)))
            }
        }
    }
}

// MARK: - Fetch (public catalog row, anon key, no auth)

enum TodayDropFetcher {
    // Shape of the JSON row returned by Supabase REST. It is intentionally small:
    // the widget only needs enough data to display the card.
    private struct Row: Decodable {
        let title: String
        let artist: String
        let album_art_url: String?
    }

    static func fetchToday() async -> TodayDropEntry? {
        // Build the REST endpoint:
        //   {SUPABASE_URL}/rest/v1/daily_entries
        // URLComponents lets us add query items safely instead of hand-building
        // a URL string with escaping rules.
        guard var components = URLComponents(
            url: SupabaseConfig.url.appendingPathComponent("rest/v1/daily_entries"),
            resolvingAgainstBaseURL: false
        ) else { return nil }

        // Mirrors SupabaseEntryService.todayEntry(): today's date in the local
        // calendar, only rows whose published_at has passed.
        components.queryItems = [
            // Only request the columns the widget actually renders.
            URLQueryItem(name: "select", value: "title,artist,album_art_url"),

            // The date column is a calendar-day identity: "which daily entry is
            // this?" This uses the user's current local day.
            URLQueryItem(name: "date", value: "eq.\(Self.dayString(for: Date()))"),

            // published_at is the release gate. Future rows stay hidden even if
            // their date is today, which lets you pre-schedule entries.
            URLQueryItem(name: "published_at", value: "lte.\(ISO8601DateFormatter().string(from: Date()))"),

            // There should only be one row per day, but limit(1) keeps the REST
            // response small and makes the decode path simple.
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = components.url else { return nil }

        // Supabase REST requires the anon key in apikey and Authorization. This
        // is public catalog data, so the widget does not need a signed-in session.
        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        // Any failure becomes nil instead of crashing the widget extension. The
        // provider turns nil into a pending timeline and retries soon.
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let row = (try? JSONDecoder().decode([Row].self, from: data))?.first
        else { return nil }

        // Convert the database row into the widget's frozen timeline entry. The
        // artwork fetch is awaited here so the rendered widget has the image data.
        return TodayDropEntry(
            date: Date(),
            title: row.title,
            artist: row.artist,
            artwork: await fetchArtwork(from: row.album_art_url),
            streak: SharedStreakReader.currentStreak()
        )
    }

    // Album covers ship at 1200×1200, which decodes to a ~5.7MB bitmap. Widget
    // extensions run under a tight memory budget, and holding/rendering a bitmap
    // that large makes WidgetKit drop the image (no art, or art only on some
    // days). So we never hand the full-resolution image to SwiftUI — we cap the
    // longest edge at this many pixels, which is plenty for a Home Screen tile
    // and keeps the decoded footprint under ~1.5MB.
    private static let artworkMaxPixelSize: CGFloat = 600

    private static func fetchArtwork(from urlString: String?) async -> UIImage? {
        // Artwork is optional. If the URL is missing, invalid, unavailable, or
        // not image data, the widget falls back to the brand gradient.
        guard let urlString, let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url)
        else { return nil }
        // Decode at widget display size, not full resolution. If downsampling
        // fails we return nil (brand gradient) rather than the heavy full-size
        // image — a clean fallback is safer than re-introducing the memory spike.
        return downsampledArtwork(from: data, maxPixelSize: artworkMaxPixelSize)
    }

    /// Decodes image data straight into a thumbnail of the requested size using
    /// ImageIO. Unlike `UIImage(data:)`, this never inflates the full-resolution
    /// bitmap into memory first — ImageIO scales during decode, so the widget
    /// only ever holds the small version.
    private static func downsampledArtwork(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        // Don't cache the full-size decode; we only want the thumbnail.
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            // Always build a thumbnail even if the file lacks an embedded one.
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Decode the pixels now (on this background task) instead of lazily
            // on the main thread at render time.
            kCGImageSourceShouldCacheImmediately: true,
            // Respect EXIF orientation so covers are never sideways.
            kCGImageSourceCreateThumbnailWithTransform: true,
            // The cap that actually shrinks the bitmap.
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private static func dayString(for date: Date) -> String {
        // The daily_entries.date column is stored as yyyy-MM-dd. Use the current
        // time zone so "today" matches the user's local calendar day.
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
        // StaticConfiguration means this widget has no user-editable settings.
        // The provider supplies all entries, and the view renders each entry.
        StaticConfiguration(kind: "TodayDropWidget", provider: TodayDropProvider()) { entry in
            TodayDropWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Drop")
        .description("Don't miss out on your daily drop!")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Views

struct TodayDropWidgetView: View {
    // WidgetKit tells us which family is being rendered. One SwiftUI view can
    // branch into separate layouts for Home Screen small/medium and Lock Screen.
    @Environment(\.widgetFamily) private var family

    // This is the frozen timeline entry selected by WidgetKit for the current
    // time. The view does not fetch; it only renders this data.
    let entry: TodayDropEntry

    var body: some View {
        Group {
            // Keep each widget family in its own computed view so the layouts do
            // not become one giant nested switch.
            switch family {
            case .accessoryRectangular: accessory
            case .systemMedium: medium
            default: small
            }
        }
        // Tapping any non-accessory widget area opens the app through RootView's
        // dailymusic://today deep-link handling.
        .widgetURL(URL(string: "dailymusic://today"))
    }

    // Small: full-bleed artwork with a scrim, title bottom-aligned.
    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Only show the flame when the app has published a fresh enough
            // streak snapshot into the App Group.
            if let streak = entry.streak {
                streakPill(streak)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Push the text stack to the bottom of the artwork.
            Spacer(minLength: 0)

            Text("TODAY")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .opacity(0.8)

            // When title is nil, this is the pending rollover/retry state.
            Text(entry.title ?? "New drop incoming")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            // Hide artist in pending state because there is no song yet.
            if let artist = entry.artist {
                Text(artist)
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.8)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

        // Widget backgrounds must be supplied through containerBackground on
        // modern iOS so the system can adapt them for different surfaces.
        .containerBackground(for: .widget) { artworkBackground }
    }

    // Medium: full-bleed artwork with a scrim, text bottom-aligned — same
    // art-forward treatment as small, just with more room for the title line.
    private var medium: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Push the text block to the bottom so the artwork reads as the hero.
            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text("TODAY'S DROP")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .opacity(0.85)

                // The streak sits beside the label, over the scrim.
                if let streak = entry.streak {
                    streakPill(streak)
                }
            }

            // When title is nil, this is the pending rollover/retry state.
            Text(entry.title ?? "New drop incoming")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            HStack(spacing: 7) {
                if let artist = entry.artist {
                    Text(artist)
                        .font(.system(size: 14, weight: .medium))
                        .opacity(0.85)
                        .lineLimit(1)
                }

                // Reflects whether the entry has real song data or is one of the
                // pending entries from the timeline provider.
                Text(entry.released ? "· Listen now" : "· Check back soon")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .opacity(0.75)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .containerBackground(for: .widget) { artworkBackground }
    }

    // Lock Screen rectangular: text only, system styling.
    private var accessory: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Accessory widgets are tiny and system-styled, so we keep the view
            // mostly text and avoid artwork.
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
            // Use album art as a full-bleed background for the small widget.
            Image(uiImage: artwork)
                .resizable()
                .scaledToFill()
                .overlay {
                    // The dark gradient keeps white text readable over bright art.
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.16), .black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        } else {
            // Pending state or failed artwork fetch: use a reliable branded fill.
            brandGradient
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
