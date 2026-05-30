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

    func load(favoriteIDs: Set<UUID>) async {
        state = .loading
        do {
            let history = try await entries.publishedHistory()
            let favorites = history.filter { favoriteIDs.contains($0.id) }
            state = favorites.isEmpty ? .empty : .loaded(favorites)
        } catch {
            state = .failed(error)
        }
    }
}
