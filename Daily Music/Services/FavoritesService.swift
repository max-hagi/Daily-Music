//
//  FavoritesService.swift
//  Daily Music
//
//  Tracks which entries a user has hearted. v1 keeps them in memory; later a
//  SupabaseFavoritesService reads/writes the `favorites` table (RLS scoped to
//  the signed-in user). The protocol deals only in entry IDs — the views
//  resolve IDs back to entries via EntryService.
//

import Foundation

protocol FavoritesService {
    func favoriteIDs() async throws -> Set<UUID>
    func setFavorite(_ isFavorite: Bool, entryID: UUID) async throws
}

actor MockFavoritesService: FavoritesService {
    private var ids: Set<UUID> = []

    func favoriteIDs() async throws -> Set<UUID> { ids }

    func setFavorite(_ isFavorite: Bool, entryID: UUID) async throws {
        if isFavorite { ids.insert(entryID) } else { ids.remove(entryID) }
    }
}
