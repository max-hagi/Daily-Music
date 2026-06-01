//
//  FavoritesViewModel.swift
//  Daily Music
//
//  Resolves the hearted entry IDs (from FavoritesStore) into full entries by
//  cross-referencing the published history. Recomputed whenever the favorites
//  set changes so the list stays live.
//

import Foundation

@MainActor
@Observable
final class FavoritesViewModel {
    private(set) var state: LoadState<[DailyEntry]> = .loading

    private let entries: EntryService

    init(entries: EntryService) {
        self.entries = entries
    }

    // Takes the favorite IDs as a PARAMETER (from FavoritesStore) rather than
    // owning them — so this VM stays a pure "IDs in → entries out" transform and
    // the store remains the single source of truth.
    func load(favoriteIDs: Set<UUID>) async {
        state = .loading
        do {
            let history = try await entries.publishedHistory()
            // Keep only the entries whose id is in the favorites set.
            let favorites = history.filter { favoriteIDs.contains($0.id) }
            state = favorites.isEmpty ? .empty : .loaded(favorites)
        } catch {
            state = .failed(error)
        }
    }
}
