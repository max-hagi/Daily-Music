//
//  InsightsView.swift
//  Daily Music
//
//  Taste-focused stats with an archetype-led presentation. The archetype is
//  resolved from real metrics (TasteProfile), so it changes as taste develops —
//  no hardcoded data. Insights uses its own palette (the archetype's color),
//  not the album art (that's Today's job).
//

import SwiftUI

struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: InsightsViewModel?
    @State private var showingWrapped = false

    private let archetypeUnlockCount = 8

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(
                        state: model.state,
                        emptyTitle: "No stats yet",
                        emptyMessage: "Open a few daily songs to start your collection.",
                        onRetry: { await model.load(favoriteIDs: env.favoritesStore.ids) }
                    ) { stats in
                        content(stats)
                    }
                } else {
                    MusicLoadingView(title: "Reading your taste", tint: .orange)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(pageBackground)
                }
            }
            .navigationTitle("Insights")
            .toolbarBackground(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showingWrapped) {
                WrappedView(favoriteIDs: env.favoritesStore.ids)
            }
        }
        .task(id: env.favoritesStore.ids) {
            if model == nil {
                model = InsightsViewModel(
                    entries: env.entries,
                    checkIns: env.checkIns,
                    sharedStats: env.sharedStats
                )
            }
            await model?.load(favoriteIDs: env.favoritesStore.ids)
        }
    }

    private var favoriteCount: Int { env.favoritesStore.ids.count }

    private func content(_ stats: InsightsViewModel.Stats) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                archetypeCard(stats.archetype)
                statStrip(stats)
                if stats.topGenres.isEmpty {
                    depthCard(stats)
                } else {
                    topGenresCard(stats.topGenres)
                }
                wrappedButton(stats.archetype)
            }
            .padding()
        }
        .background(pageBackground)
        .animation(.easeInOut(duration: 0.4), value: stats.archetype.title)
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.95, blue: 0.9),
                Color(red: 0.9, green: 0.98, blue: 0.98),
                Color(red: 0.99, green: 0.91, blue: 0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Archetype hero

    private func archetypeCard(_ profile: TasteProfile) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .top) {
                Image(systemName: profile.symbol)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Spacer()

                Text(favoriteCount >= archetypeUnlockCount ? "UNLOCKED" : "TASTE ARCHETYPE")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.72))
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(profile.title)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(profile.blurb)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Favorites analyzed")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                    Spacer()
                    Text("\(min(favoriteCount, archetypeUnlockCount))/\(archetypeUnlockCount)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.24))
                        Capsule()
                            .fill(.white)
                            .frame(width: max(10, proxy.size.width * unlockProgress))
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            LinearGradient(colors: profile.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: profile.colors[0].opacity(0.28), radius: 18, y: 10)
    }

    private var unlockProgress: Double {
        min(Double(favoriteCount) / Double(archetypeUnlockCount), 1)
    }

    // MARK: - Metrics

    private func statStrip(_ stats: InsightsViewModel.Stats) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            insightMetric(
                value: "\(stats.artistsDiscovered)",
                label: "Artists",
                symbol: "music.mic",
                tint: Color(red: 0.0, green: 0.52, blue: 0.68)
            )
            insightMetric(
                value: "\(favoriteCount)",
                label: "Favorites",
                symbol: "heart.fill",
                tint: Color(red: 0.88, green: 0.18, blue: 0.42)
            )
        }
    }

    private func insightMetric(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Honest depth signal (real: songs per artist)

    private func depthCard(_ stats: InsightsViewModel.Stats) -> some View {
        let depth = stats.artistsDiscovered > 0 ? Double(stats.songsHeard) / Double(stats.artistsDiscovered) : 0
        let progress = min(max((depth - 1) / 2, 0), 1) // depth 1→0 (all unique), 3+→full
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("Listening depth", systemImage: "arrow.down.to.line")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(depthLabel(progress))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.08))
                    Capsule().fill(Color.orange.gradient)
                        .frame(width: max(12, proxy.size.width * progress))
                }
            }
            .frame(height: 9)
            Text(depth > 0 ? String(format: "About %.1f songs per artist", depth) : "Listen to a few songs to see this")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func depthLabel(_ value: Double) -> String {
        switch value {
        case 0.66...: "Going deep"
        case 0.25...: "Building"
        default: "Exploring"
        }
    }

    // MARK: - Top genres (real: from favorites' genres)

    private func topGenresCard(_ genres: [InsightsViewModel.GenreCount]) -> some View {
        let total = max(genres.reduce(0) { $0 + $1.count }, 1)
        let palette: [Color] = [
            Color(red: 0.96, green: 0.28, blue: 0.55),
            Color(red: 1.0, green: 0.55, blue: 0.16),
            Color(red: 0.0, green: 0.62, blue: 0.74),
            Color(red: 0.42, green: 0.31, blue: 0.93)
        ]
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Top genres")
                .font(.dmTitle())

            ForEach(Array(genres.prefix(4).enumerated()), id: \.element.id) { index, genre in
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text(genre.name)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(genre.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.black.opacity(0.08))
                            Capsule().fill(palette[index % palette.count].gradient)
                                .frame(width: max(12, proxy.size.width * Double(genre.count) / Double(total)))
                        }
                    }
                    .frame(height: 9)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: - Wrapped

    private func wrappedButton(_ profile: TasteProfile) -> some View {
        Button {
            showingWrapped = true
        } label: {
            Label("See your month", systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: profile.colors[0]))
        .padding(.top, Theme.Spacing.xs)
    }
}
