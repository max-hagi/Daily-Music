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
  
    /// Which month to recap (any date inside it). Defaults to now; the
    /// 1st-of-month moment passes last month.
    var targetMonth: Date = Date()

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss   // to close itself (it's shown as a sheet)
    @State private var model: WrappedViewModel?
    @State private var showingShare = false

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
                    MusicLoadingView(title: nil, tint: .pink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Your Recap")
            .navigationBarTitleDisplayMode(.inline)
            .background(recapBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if loadedRecap != nil {
                        Button { showingShare = true } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share your recap")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShare) {
                if let recap = loadedRecap {
                    WrappedShareSheet(recap: recap)
                }
            }
        }
        .simultaneousGesture(dismissSwipeGesture)
        .task {
            if model == nil {
                model = WrappedViewModel(entries: env.entries, checkIns: env.checkIns, ratings: env.ratings)
            }
            await model?.load(favoriteIDs: favoriteIDs, month: targetMonth)
        }
    }

    private var dismissSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard value.translation.height > 120, abs(value.translation.width) < 90 else { return }
                dismiss()
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

                HStack(spacing: 16) {
                    bigStat("\(recap.favourites)", "favourited this month")
                    if recap.streak.best > 0 {
                        bigStat("\(recap.streak.best)", "best streak (days)")
                    }
                }

                Button { showingShare = true } label: {
                    Label("Share your recap", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(tint: recap.profile.colors[0]))
                .padding(.top, 4)
            }
            .padding()
        }
        .background(recapBackground)
    }

    private var loadedRecap: WrappedViewModel.Recap? {
        if case .loaded(let recap) = model?.state { return recap }
        return nil
    }

    private var recapBackground: some View {
        LinearGradient(
            colors: Theme.Surface.insightsBackground,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
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

#Preview {
    WrappedView(favoriteIDs: [
        MockEntryService.mockEntryID(0),
        MockEntryService.mockEntryID(2),
        MockEntryService.mockEntryID(5),
    ])
    .environment(AppEnvironment.mock())
}
