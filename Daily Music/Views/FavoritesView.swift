//
//  FavoritesView.swift
//  Daily Music
//
//  The hearted entries. Recomputes whenever the FavoritesStore set changes, so
//  un-hearting something here (or on another screen) updates the list live.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: FavoritesViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(
                        state: model.state,
                        emptyTitle: "No favorites yet",
                        emptyMessage: "Tap the heart on a song to save it here."
                    ) { entries in
                        List(entries) { entry in
                            NavigationLink(value: entry) {
                                EntryRow(entry: entry)
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: DailyEntry.self) { entry in
                EntryDetailView(entry: entry)
            }
        }
        .task(id: env.favoritesStore.ids) {
            if model == nil { model = FavoritesViewModel(entries: env.entries) }
            await model?.load(favoriteIDs: env.favoritesStore.ids)
        }
    }
}
