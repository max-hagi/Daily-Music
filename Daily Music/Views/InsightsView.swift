//
//  InsightsView.swift
//  Daily Music
//
//  Discovery-focused stats: your taste archetype (identity), artists discovered
//  (a collection that only grows — no streak/loss-aversion), and how many people
//  shared today's song (the daily ritual / belonging).
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
                        emptyMessage: "Open a few daily songs to start your collection.",
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
            VStack(spacing: 20) {
                archetypeCard(stats.tasteProfile)
                artistsCard(stats.artistsDiscovered)
                listenersCard(stats.listenersToday)
            }
            .padding()
        }
    }

    private func archetypeCard(_ profile: TasteProfile) -> some View {
        VStack(spacing: 12) {
            Image(systemName: profile.symbol)
                .font(.system(size: 40))
                .foregroundStyle(.white)
            Text("You're a")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Text(profile.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(profile.blurb)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [Color.purple, Color.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: .indigo.opacity(0.3), radius: 16, y: 8)
    }

    private func artistsCard(_ count: Int) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "music.mic")
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: 52, height: 52)
                .background(.tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(count == 1 ? "artist discovered" : "artists discovered")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func listenersCard(_ count: Int) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.title2)
                .foregroundStyle(.pink)
                .frame(width: 52, height: 52)
                .background(.pink.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(count.formatted())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("listened to today's song")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
