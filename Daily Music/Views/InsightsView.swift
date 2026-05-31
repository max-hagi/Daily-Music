//
//  InsightsView.swift
//  Daily Music
//
//  Discovery-focused stats: your taste archetype (identity), artists discovered
//  (a collection that only grows), and how many people shared today's song.
//

import SwiftUI

struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: InsightsViewModel?
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
                    MusicLoadingView(title: "Finding your signal", tint: Theme.Brand.gradient[2])
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(insightsBackground)
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
        }
    }

    private func content(_ stats: InsightsViewModel.Stats) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                heroCard(stats.tasteProfile)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                    metricTile(
                        value: "\(stats.artistsDiscovered)",
                        label: stats.artistsDiscovered == 1 ? "artist" : "artists",
                        symbol: "music.mic",
                        tint: .cyan
                    )
                    metricTile(
                        value: stats.listenersToday.formatted(),
                        label: "listeners today",
                        symbol: "person.2.fill",
                        tint: .pink
                    )
                }

                discoveryMix(stats)
                wrappedButton
            }
            .padding()
        }
        .background(insightsBackground)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var insightsBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.07, blue: 0.12),
                Color(red: 0.09, green: 0.12, blue: 0.24),
                Color(red: 0.05, green: 0.17, blue: 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var wrappedButton: some View {
        Button {
            showingWrapped = true
        } label: {
            Label("See your month", systemImage: "sparkles")
                .font(.dmHeadline())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: .orange))
        .padding(.top, 4)
    }

    private func heroCard(_ profile: TasteProfile) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .top) {
                Image(systemName: profile.symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Spacer()

                Text("TASTE SIGNAL")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.68))
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(profile.title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(profile.blurb)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.2, blue: 0.46),
                    Color(red: 0.36, green: 0.28, blue: 0.92),
                    Color(red: 0.0, green: 0.62, blue: 0.76)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
        .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
    }

    private func metricTile(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func discoveryMix(_ stats: InsightsViewModel.Stats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Label("Discovery mix", systemImage: "waveform")
                    .font(.dmHeadline())
                    .foregroundStyle(.white)
                Spacer()
                Text("Live")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.green.opacity(0.16), in: Capsule())
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(discoveryLevels(for: stats).indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(discoveryColor(at: index).gradient)
                        .frame(height: discoveryLevels(for: stats)[index])
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 86)
            .accessibilityHidden(true)

            Text("Your profile updates as more songs move from daily picks into your personal history.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(Theme.Spacing.lg)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        }
    }

    private func discoveryLevels(for stats: InsightsViewModel.Stats) -> [CGFloat] {
        let artistSignal = min(CGFloat(stats.artistsDiscovered) / 8, 1)
        let listenerSignal = min(CGFloat(stats.listenersToday) / 250, 1)
        return [
            28 + artistSignal * 42,
            44 + listenerSignal * 34,
            36 + artistSignal * 26,
            62 + listenerSignal * 20,
            34 + artistSignal * 46,
            50 + listenerSignal * 28,
            40 + artistSignal * 32
        ]
    }

    private func discoveryColor(at index: Int) -> Color {
        [Color.cyan, Color.orange, Color.pink, Color.indigo][index % 4]
    }
}
