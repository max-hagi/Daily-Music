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
        // No user filter here ON PURPOSE: Row-Level Security on the table already
        // restricts SELECT to the current user's rows, so the query stays simple.
        let rows: [FavouriteRow] = try await client
            .from("favourites")
            .select("entry_id")   // only need the entry_id column
            .execute()
            .value
        return Set(rows.map(\.entry_id))   // collapse the [row] into a Set of IDs
    }

    func setFavorite(_ isFavorite: Bool, entryID: UUID) async throws {
        if isFavorite {
            // We DO set user_id on insert because the RLS WITH CHECK policy requires
            // the new row's user_id to equal the caller. Fetch it from the session.
            let userID = try await client.auth.session.user.id
            try await client
                .from("favourites")
                .insert(FavouriteInsert(user_id: userID, entry_id: entryID))   // Encodable → JSON body
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

// Read shape (Decodable): we only pull entry_id back.
private struct FavouriteRow: Decodable {
    let entry_id: UUID
}

// Write shape (Encodable): the JSON body sent on insert. Split read/write structs
// keep each minimal — you only encode what the DB needs.
private struct FavouriteInsert: Encodable {
    let user_id: UUID
    let entry_id: UUID
}
