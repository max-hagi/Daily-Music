//
//  InsightsView.swift
//  Daily Music
//
//  Your listening stats. The streak (consecutive days you've opened the daily
//  song) is the hero; songs discovered and favourites are secondary cards.
//

import SwiftUI

struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: InsightsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(
                        state: model.state,
                        emptyTitle: "No stats yet",
                        emptyMessage: "Open a few daily songs to start building your stats.",
                        onRetry: { await model.load() }
                    ) { stats in
                        content(stats)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Insights")
        }
        .task {
            if model == nil {
                model = InsightsViewModel(entries: env.entries, checkIns: env.checkIns)
            }
            await model?.load()
        }
    }

    private func content(_ stats: InsightsViewModel.Stats) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                streakCard(stats.streak)

                HStack(spacing: 16) {
                    statCard(
                        value: "\(stats.discovered)",
                        label: "Songs discovered",
                        systemImage: "music.note"
                    )
                    statCard(
                        value: "\(env.favoritesStore.ids.count)",
                        label: "Favourites",
                        systemImage: "heart.fill"
                    )
                }
            }
            .padding()
        }
    }

    private func streakCard(_ streak: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 44))
                .foregroundStyle(streak > 0 ? .orange : .secondary)
            Text("\(streak)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(streak == 1 ? "day streak" : "day streak")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(streak > 0 ? "Keep it going — open tomorrow's song!" : "Open today's song to start a streak.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statCard(value: String, label: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
