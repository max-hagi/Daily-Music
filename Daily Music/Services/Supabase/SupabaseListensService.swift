//
//  SupabaseListensService.swift
//  Daily Music
//
//  Live listens backed by the `listens` table. RLS scopes every read/write to
//  the signed-in user, so reads don't filter by user_id. The insert sets user_id
//  (RLS WITH CHECK requires it) and uses ON CONFLICT DO NOTHING so a later catch-up
//  never overwrites an earlier same-day heard_at (first-listen-wins).
//

import Foundation
import Supabase

final class SupabaseListensService: ListensService {
    private let client = Supa.client

    func heardEntries() async throws -> [UUID: Date] {
        let rows: [ListenRow] = try await client
            .from("listens")
            .select("entry_id,heard_at")
            .execute()
            .value
        return Dictionary(rows.map { ($0.entry_id, $0.heard_at) },
                          uniquingKeysWith: min)   // keep the earliest if duplicated
    }

    func markHeard(entryID: UUID) async throws {
        let userID = try await client.auth.session.user.id
        // ignoreDuplicates → ON CONFLICT DO NOTHING: heard_at is set once and kept.
        try await client
            .from("listens")
            .upsert(ListenInsert(user_id: userID, entry_id: entryID),
                    onConflict: "user_id,entry_id",
                    ignoreDuplicates: true)
            .execute()
    }
}

// Read shape: entry_id + heard_at. `heard_at` decodes from timestamptz via the
// Supabase client's configured date decoding (ISO-8601), as elsewhere in the app.
private struct ListenRow: Decodable {
    let entry_id: UUID
    let heard_at: Date
}

// Write shape: heard_at is omitted so the column default now() applies server-side.
private struct ListenInsert: Encodable {
    let user_id: UUID
    let entry_id: UUID
}
