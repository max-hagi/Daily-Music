//
//  InsightsView.swift
//  Daily Music
//
//  Discovery-focused stats, styled to match the rest of the app: light surface,
//  generous spacing, big rounded type, and accents drawn from today's album art.
//  Real data only — taste archetype, artists discovered, listeners today.
//

import SwiftUI

struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: InsightsViewModel?
    @State private var palette = ArtworkPalette()
    @State private var showingWrapped = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(
                        state: model.state,
                        emptyTitle: "No stats yet",
                        emptyMessage: "Open a few daily songs to start your collection.",
                        onRetry: { await model.load() }
                    ) { stats in
                        content(stats)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Insights")
            .fullScreenCover(isPresented: $showingWrapped) {
                WrappedView(favoriteIDs: env.favoritesStore.ids)
            }
        }
        .task {
            if model == nil {
                model = InsightsViewModel(
                    entries: env.entries,
                    checkIns: env.checkIns,
                    sharedStats: env.sharedStats
                )
            }
            await model?.load()
            if case .loaded(let stats)? = model?.state {
                await palette.load(from: stats.artURL)
            }
        }
    }

    private var accent: Color { palette.accent }

    private func content(_ stats: InsightsViewModel.Stats) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                heroCard(stats.tasteProfile)

                HStack(spacing: Theme.Spacing.md) {
                    statCard(
                        value: "\(stats.artistsDiscovered)",
                        label: stats.artistsDiscovered == 1 ? "Artist discovered" : "Artists discovered",
                        symbol: "music.mic"
                    )
                    statCard(
                        value: stats.listenersToday.formatted(),
                        label: "Listening today",
                        symbol: "person.2.fill"
                    )
                }

                wrappedButton
            }
            .padding()
        }
        .animation(.easeInOut(duration: 0.5), value: accent)
    }

    // MARK: Cards

    private func heroCard(_ profile: TasteProfile) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Image(systemName: profile.symbol)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("YOUR TASTE")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.8))
                Text(profile.title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(profile.blurb)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [accent, accent.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
        .shadow(color: accent.opacity(0.3), radius: 16, y: 8)
    }

    private func statCard(value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var wrappedButton: some View {
        Button {
            showingWrapped = true
        } label: {
            Label("See your month", systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: accent))
        .padding(.top, Theme.Spacing.xs)
    }
}
