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
    @State private var showingWrapped = false   // drives the full-screen Wrapped cover

    // How many favorites "unlock" the archetype — used for the progress bar.
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
                    // Plain system spinner while the view model is built — matches
                    // Today's loading look. Kept on the page gradient so the
                    // background doesn't flash.
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(pageBackground)
                }
            }
            .navigationTitle("Insights")
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(pageBackground)
            // Like `.sheet`, but `.fullScreenCover` slides up edge-to-edge (no
            // peek of the screen behind) — fitting for the immersive Wrapped recap.
            .fullScreenCover(isPresented: $showingWrapped) {
                WrappedView(favoriteIDs: env.favoritesStore.ids)
            }
        }
        // Same live-reload trick as Favorites: re-run whenever the favorites set
        // changes, since the whole archetype/genres analysis is built from them.
        .task(id: env.favoritesStore.ids) {
            if model == nil {
                model = InsightsViewModel(
                    entries: env.entries,
                    checkIns: env.checkIns
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
                    genresHint
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
            colors: Theme.Surface.insightsBackground,
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

                // GeometryReader hands us the available size (`proxy.size`) so we can
                // draw a fill that's a FRACTION of the full width — the standard way
                // to build a custom progress bar. The track + fill are stacked
                // leading-aligned so the fill grows from the left. `max(10, …)`
                // keeps a visible nub even at 0%.
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.24))                       // track
                        Capsule()
                            .fill(.white)
                            .frame(width: max(10, proxy.size.width * unlockProgress)) // fill
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            // The card is tinted by the ARCHETYPE's colors (not the album art) — a
            // deliberate distinction: only Today themes from artwork.
            LinearGradient(colors: profile.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: profile.colors[0].opacity(0.28), radius: 18, y: 10)
    }

    // Fraction filled, capped at 1.0 (100%). Cast to Double for the division.
    private var unlockProgress: Double {
        min(Double(favoriteCount) / Double(archetypeUnlockCount), 1)
    }

    // MARK: - Metrics

    private func statStrip(_ stats: InsightsViewModel.Stats) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            insightMetric(
                value: "\(stats.daysLoggedIn)",
                label: "Days",
                symbol: "calendar",
                tint: Color(red: 0.0, green: 0.52, blue: 0.68)
            )
            insightMetric(
                value: "\(stats.favorites)",
                label: "Favorites",
                symbol: "heart.fill",
                tint: Color(red: 0.88, green: 0.18, blue: 0.42)
            )
            insightMetric(
                value: "\(stats.artists)",
                label: "Artists",
                symbol: "music.mic",
                tint: Color(red: 0.42, green: 0.31, blue: 0.7)
            )
        }
    }

    private func insightMetric(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    // Allow shrinking to 60% (and one line) so big numbers still fit.
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.Surface.cardStroke, lineWidth: 1)
        }
    }

    /// Shown when the user hasn't favorited anything with a genre yet.
    private var genresHint: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "heart.text.square")
                .font(.title2)
                .foregroundStyle(.pink)
            Text("Heart a few songs to reveal your top genres and personalize your archetype.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Surface.cardStroke, lineWidth: 1)
        }
    }

    // MARK: - Top genres (real: from favorites' genres)

    private func topGenresCard(_ genres: [InsightsViewModel.GenreCount]) -> some View {
        // `reduce(0)` sums all counts; `max(…, 1)` avoids divide-by-zero when
        // computing each bar's width fraction below.
        let total = max(genres.reduce(0) { $0 + $1.count }, 1)
        let palette: [Color] = [
            Color(red: 0.96, green: 0.28, blue: 0.55),
            Color(red: 1.0, green: 0.55, blue: 0.16),
            Color(red: 0.0, green: 0.62, blue: 0.74),
            Color(red: 0.42, green: 0.31, blue: 0.93)
        ]
        // Helper functions that build views use an explicit `return` (unlike the
        // single-expression computed `var`s elsewhere) because there's a `let`
        // statement before the view.
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Top genres")
                .font(.dmTitle())

            // `.enumerated()` gives (index, genre); `id: \.element.id` identifies
            // rows by the genre's own id (not the index). Index is used to pick a
            // bar color, wrapping with `% palette.count` so it never overflows.
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
                    // Same progress-bar pattern as the archetype card: width is this
                    // genre's share (count / total) of the available width.
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.Surface.subtleTrack)
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
        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Surface.cardStroke, lineWidth: 1)
        }
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
