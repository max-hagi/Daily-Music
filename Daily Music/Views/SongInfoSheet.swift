//
//  SongInfoSheet.swift
//  Daily Music
//
//  The "more info" panel. Real catalog facts from the free iTunes lookup API
//  plus the song's curated tags, presented as a visual scan-friendly sheet.
//

import SwiftUI

struct SongInfoSheet: View {
    let entry: DailyEntry
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage("settings.preferredStreamingService") private var preferredRaw = StreamingService.appleMusic.rawValue
    @State private var info: CatalogInfo?
    @State private var loaded = false
    @State private var palette = ArtworkPalette()
    @State private var selectedDetent: PresentationDetent = .large

    private var preferred: StreamingService { StreamingService(rawValue: preferredRaw) ?? .appleMusic }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    hero
                    quickFacts
                    if hasTags { curatedTags }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(sheetBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.accent)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .task(id: entry.id) {
            await palette.load(from: entry.albumArtURL)
            info = try? await env.catalogInfo.info(appleMusicID: entry.appleMusicID)
            loaded = true
        }
    }

    private var hero: some View {
        Button {
            if let albumDestinationURL { openURL(albumDestinationURL) }
        } label: {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                AlbumArtView(url: entry.albumArtURL, cornerRadius: 16)
                    .frame(width: 96, height: 96)
                    .shadow(color: palette.accent.opacity(0.24), radius: 14, y: 8)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(entry.title)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(entry.artist)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let albumName {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "opticaldisc")
                            Text(albumName)
                            ServiceLogo(service: preferred, size: 13)
                            Image(systemName: "arrow.up.forward")
                                .font(.caption.weight(.bold))
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.md)
            .glassCardStyle(tint: palette.accent.opacity(0.12))
        }
        .buttonStyle(.plain)
        .disabled(albumDestinationURL == nil)
        .accessibilityHint(albumDestinationURL == nil ? "" : "Opens the album in \(preferred.displayName)")
    }

    private var quickFacts: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "More info", symbol: "info.circle", accent: palette.accent)

            VStack(spacing: 0) {
                if !loaded {
                    LoadingInfoRow(accent: palette.accent)
                }

                ForEach(facts) { fact in
                    CompactInfoRow(item: fact, accent: palette.accent)
                    if fact.id != facts.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .glassCardStyle(tint: palette.accent.opacity(0.10))
        }
    }

    private var curatedTags: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Feel", symbol: "tag", accent: palette.accent)

            LazyVGrid(columns: tagColumns, alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(tags) { tag in
                    TagPill(item: tag, accent: palette.accent)
                }
            }

            if let energy = entry.energy {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("Energy")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(energy)/5")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(palette.accent)
                    }
                    EnergyDots(value: energy, accent: palette.accent)
                }
                .padding(Theme.Spacing.md)
                .glassCardStyle(tint: palette.accent.opacity(0.08))
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private var sheetBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    palette.accent.opacity(0.32),
                    Color(.systemBackground),
                    palette.accent.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let image = palette.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 46)
                    .saturation(1.2)
                    .opacity(0.14)
                    .ignoresSafeArea()
            }
        }
    }

    private var facts: [InfoItem] {
        [
            InfoItem(title: "Released", value: releaseText, symbol: "calendar"),
            InfoItem(title: "Song age", value: songAgeText, symbol: "hourglass"),
            InfoItem(title: "Length", value: info?.durationText, symbol: "timer"),
            InfoItem(title: "Genre", value: info?.genre ?? entry.genre, symbol: "music.note.list")
        ].compactMap { item in
            guard let value = item.value, !value.isEmpty else { return nil }
            return item
        }
    }

    private var tags: [InfoItem] {
        [
            InfoItem(title: "Mood", value: entry.mood, symbol: "face.smiling"),
            InfoItem(title: "Theme", value: entry.theme, symbol: "quote.bubble"),
            InfoItem(title: "Language", value: entry.language, symbol: "globe"),
            InfoItem(title: "Curated genre", value: entry.genre, symbol: "slider.horizontal.3")
        ].compactMap { item in
            guard let value = item.value, !value.isEmpty else { return nil }
            return item
        }
    }

    private var albumName: String? { info?.album }

    private var releaseText: String? {
        info?.releaseYear ?? entry.year.map(String.init)
    }

    private var songAgeText: String? {
        guard let releaseText, let releaseYear = Int(releaseText) else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date())
        let age = max(currentYear - releaseYear, 0)

        if age == 0 { return "New this year" }
        if age == 1 { return "1 year old" }
        return "\(age) years old"
    }

    private var albumDestinationURL: URL? {
        guard let albumName else { return nil }
        switch preferred {
        case .appleMusic:
            return info?.albumURL ?? searchURL(base: "https://music.apple.com/us/search", queryName: "term", query: "\(entry.artist) \(albumName)")
        case .spotify:
            return searchPathURL(base: "https://open.spotify.com/search", query: "\(entry.artist) \(albumName)")
        case .tidal:
            return searchURL(base: "https://tidal.com/search", queryName: "q", query: "\(entry.artist) \(albumName)")
        case .ytMusic:
            return searchURL(base: "https://music.youtube.com/search", queryName: "q", query: "\(entry.artist) \(albumName)")
        }
    }

    private func searchURL(base: String, queryName: String, query: String) -> URL? {
        var components = URLComponents(string: base)
        components?.queryItems = [URLQueryItem(name: queryName, value: query)]
        return components?.url
    }

    private func searchPathURL(base: String, query: String) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "\(base)/\(encoded)")
    }

    private var hasTags: Bool {
        entry.mood != nil || entry.decade != nil || entry.energy != nil
            || entry.theme != nil || entry.genre != nil || entry.language != nil
    }

    private var tagColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 128), spacing: Theme.Spacing.sm)]
    }
}

private struct InfoItem: Identifiable {
    let title: String
    let value: String?
    let symbol: String

    var id: String { "\(title)-\(value ?? "")" }
}

private struct SectionHeader: View {
    let title: String
    let symbol: String
    let accent: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.headline.weight(.heavy))
            .foregroundStyle(.primary)
            .symbolRenderingMode(.hierarchical)
            .tint(accent)
    }
}

private struct LoadingInfoRow: View {
    let accent: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ProgressView()
                .tint(accent)
            Text("Loading catalog details")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
    }
}

private struct CompactInfoRow: View {
    let item: InfoItem
    let accent: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: item.symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.12), in: Circle())

            Text(item.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            Spacer(minLength: Theme.Spacing.sm)

            Text(item.value ?? "")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
    }
}

private struct TagPill: View {
    let item: InfoItem
    let accent: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: item.symbol)
                .font(.caption.weight(.bold))
            Text(item.value ?? "")
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .background(accent.opacity(0.12), in: Capsule())
        .overlay {
            Capsule().stroke(accent.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct EnergyDots: View {
    let value: Int
    let accent: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(1...5, id: \.self) { index in
                Capsule()
                    .fill(index <= value ? accent : Color.secondary.opacity(0.18))
                    .frame(height: 10)
            }
        }
    }
}
