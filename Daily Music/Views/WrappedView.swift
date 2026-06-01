//
//  WrappedView.swift
//  Daily Music
//
//  A monthly "Wrapped" recap presented from Insights. A celebratory, scrollable
//  summary of the month's discovery, built from existing data.
//

import SwiftUI

struct WrappedView: View {
    // Passed IN from Insights (which already knows the favorites) rather than read
    // here — the caller owns that data.
    let favoriteIDs: Set<UUID>

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss   // to close itself (it's shown as a sheet)
    @State private var model: WrappedViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(
                        state: model.state,
                        emptyTitle: "Nothing to recap yet",
                        emptyMessage: "Open a few daily songs this month and your recap will appear here."
                    ) { recap in
                        content(recap)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Your Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if model == nil {
                model = WrappedViewModel(entries: env.entries, checkIns: env.checkIns)
            }
            await model?.load(favoriteIDs: favoriteIDs)
        }
    }

    // Assembles the recap from the same small card helpers (hero/archetype/bigStat).
    private func content(_ recap: WrappedViewModel.Recap) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                hero(recap)
                archetype(recap.profile)

                HStack(spacing: 16) {
                    // `"\(recap.songsHeard)"` interpolates the Int into a String for display.
                    bigStat("\(recap.songsHeard)", "songs heard")
                    bigStat("\(recap.artistsDiscovered)", "artists")
                }

                // Only show the top-artist card if there is one.
                if let top = recap.topArtist {
                    topArtistCard(top, plays: recap.topArtistPlays)
                }

                bigStat("\(recap.favourites)", "favourited this month")
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }

    private func hero(_ recap: WrappedViewModel.Recap) -> some View {
        VStack(spacing: 6) {
            Text("YOUR")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.85))
            Text(recap.monthName)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("in music")
                .font(.dmHeadline())
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            LinearGradient(colors: [.pink, .purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
        .shadow(color: .purple.opacity(0.3), radius: 16, y: 8)
    }

    private func archetype(_ profile: TasteProfile) -> some View {
        HStack(spacing: 16) {
            Image(systemName: profile.symbol)
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: 52, height: 52)
                .background(.tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("This month you were")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(profile.title)
                    .font(.dmHeadline())
            }
            Spacer()
        }
        .cardStyle()
    }

    private func topArtistCard(_ artist: String, plays: Int) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 52, height: 52)
                .background(.yellow.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Top artist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(artist)
                    .font(.dmHeadline())
                Text(plays == 1 ? "1 song" : "\(plays) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .cardStyle()
    }

    private func bigStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}
