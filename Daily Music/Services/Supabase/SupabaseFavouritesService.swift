//
//  SupabaseFavouritesService.swift
//  Daily Music
//
//  Live favourites backed by the `favourites` table (note the British spelling
//  to match the schema). RLS scopes every read/write to the signed-in user, so
//  the queries here don't filter by user_id — the database does it for us. The
//  insert still sets user_id because the RLS WITH CHECK requires it to match.
//

import Foundation
import Supabase

final class SupabaseFavouritesService: FavoritesService {
    private let client = Supa.client

    func favoriteIDs() async throws -> Set<UUID> {
        let rows: [FavouriteRow] = try await client
            .from("favourites")
            .select("entry_id")
            .execute()
            .value
        return Set(rows.map(\.entry_id))
    }

    func setFavorite(_ isFavorite: Bool, entryID: UUID) async throws {
        if isFavorite {
            let userID = try await client.auth.session.user.id
            try await client
                .from("favourites")
                .insert(FavouriteInsert(user_id: userID, entry_id: entryID))
                .execute()
        } else {
            // RLS limits this to the current user's own row.
            try await client
                .from("favourites")
                .delete()
                .eq("entry_id", value: entryID)
                .execute()
        }
    }
}

private struct FavouriteRow: Decodable {
    let entry_id: UUID
}

private struct FavouriteInsert: Encodable {
    let user_id: UUID
    let entry_id: UUID
}
