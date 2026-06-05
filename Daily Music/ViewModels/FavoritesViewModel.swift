//
//  FavoritesViewModel.swift
//  Daily Music
//
//  Resolves the hearted entry IDs (from FavoritesStore) into full entries by
//  cross-referencing the published history. Recomputed whenever the favorites
//  set changes so the list stays live.
//

import Foundation
import SwiftUI

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
        // Only show the spinner on the FIRST load. On later refreshes (e.g. after
        // un-hearting a song) keep the current rows visible so the change animates
        // instead of flashing a spinner.
        if case .loaded = state {} else { state = .loading }
        do {
            let history = try await entries.publishedHistory()
            // Keep only the entries whose id is in the favorites set.
            let favorites = history.filter { favoriteIDs.contains($0.id) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                state = favorites.isEmpty ? .empty : .loaded(favorites)
            }
        } catch {
            state = .failed(error)
        }
    }

    /// Instantly drop one entry from the displayed list so a swipe-to-remove
    /// animates out immediately, before the network write returns.
    func remove(id: UUID) {
        guard case .loaded(let favorites) = state else { return }
        let remaining = favorites.filter { $0.id != id }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state = remaining.isEmpty ? .empty : .loaded(remaining)
        }
    }
}
