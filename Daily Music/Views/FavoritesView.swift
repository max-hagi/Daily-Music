//
//  FavoritesView.swift
//  Daily Music
//
//  The hearted entries, styled to match Vault/Insights: light gradient surface,
//  a gradient hero, and material card rows. Recomputes whenever the FavoritesStore
//  changes, so un-hearting anywhere updates the list live.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: FavoritesViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    // Unlike the other screens (which use LoadStateView), this one
                    // switches the state by hand so each case gets its own bespoke,
                    // on-brand layout instead of the generic placeholders.
                    switch model.state {
                    case .loaded(let entries): loaded(entries)
                    case .empty: emptyState
                    case .failed: failedState
                    case .loading: loadingState
                    }
                } else {
                    loadingState
                }
            }
            .navigationTitle("Favorites")
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: DailyEntry.self) { entry in
                EntryDetailView(entry: entry)
            }
        }
        // KEY: `.task(id: env.favoritesStore.ids)` re-runs whenever the favorites
        // SET changes. So un-hearting a song on the detail screen flips the shared
        // store, which changes `ids`, which re-runs this task → the list updates
        // live without any manual refresh wiring.
        .task(id: env.favoritesStore.ids) {
            if model == nil { model = FavoritesViewModel(entries: env.entries) }
            await model?.load(favoriteIDs: env.favoritesStore.ids)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.94, blue: 0.95),
                Color(red: 0.96, green: 0.93, blue: 0.99),
                Color(red: 1.0, green: 0.92, blue: 0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var loadingState: some View {
        MusicLoadingView(title: "Gathering your favorites", tint: .pink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
    }

    private func loaded(_ entries: [DailyEntry]) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                hero(count: entries.count)

                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        NavigationLink(value: entry) {
                            EntryRow(entry: entry)
                                .padding(Theme.Spacing.md)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(background)
    }

    private func hero(count: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Spacer()
                Text("YOUR COLLECTION")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.75))
            }
            // Inline ternary handles singular/plural ("1 favorite" vs "3 favorites").
            Text("\(count) \(count == 1 ? "favorite" : "favorites")")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("The songs that stopped you in your tracks.")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.27, blue: 0.45), Color(red: 0.79, green: 0.16, blue: 0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: Color(red: 0.96, green: 0.27, blue: 0.45).opacity(0.25), radius: 18, y: 10)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "heart.slash")
                .font(.system(size: 56))
                .foregroundStyle(.pink.opacity(0.7))
            VStack(spacing: Theme.Spacing.sm) {
                Text("No favorites yet")
                    .font(.dmTitle())
                Text("Tap the heart on any song to save it to your collection.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }

    private var failedState: some View {
        // The label/actions closure form of ContentUnavailableView lets us add a
        // custom Retry button alongside the standard "empty" presentation.
        ContentUnavailableView {
            Label("Couldn't load favorites", systemImage: "exclamationmark.triangle")
        } actions: {
            Button("Retry") {
                Task { await model?.load(favoriteIDs: env.favoritesStore.ids) }
            }
            .buttonStyle(.borderedProminent)
        }
        .background(background)
    }
}
