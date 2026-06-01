//
//  FavoritesService.swift
//  Daily Music
//
//  Tracks which entries a user has hearted. The mock keeps them in memory;
//  SupabaseFavouritesService reads/writes the `favourites` table (RLS scoped
//  to the signed-in user). The protocol deals only in entry IDs — the views
//  resolve IDs back to entries via EntryService.
//

import Foundation

// The seam deals only in entry IDs (a Set<UUID> — unordered, no duplicates,
// O(1) membership checks). The UI maps those IDs back to full entries via
// EntryService, which keeps "what's favorited" and "what the entry is" separate.
protocol FavoritesService {
    func favoriteIDs() async throws -> Set<UUID>
    func setFavorite(_ isFavorite: Bool, entryID: UUID) async throws
}

// `actor` is like a class, but Swift guarantees its mutable state is accessed by
// ONE task at a time — no data races on `ids` even if several screens toggle
// favorites concurrently. The trade-off: reaching into an actor from outside is
// `await`ed (the protocol methods are already async, so that's free here).
actor MockFavoritesService: FavoritesService {
    private var ids: Set<UUID> = []

    func favoriteIDs() async throws -> Set<UUID> { ids }

    func setFavorite(_ isFavorite: Bool, entryID: UUID) async throws {
        // Set insert/remove are no-ops if the element is already present/absent,
        // so this is naturally idempotent.
        if isFavorite { ids.insert(entryID) } else { ids.remove(entryID) }
    }
}
