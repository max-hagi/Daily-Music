//
//  SupabaseReactionsService.swift
//  Daily Music
//
//  Live reactions against the `reactions` table. Owner-scoped writes via RLS;
//  aggregate counts come from the reaction_counts() SECURITY DEFINER function
//  (so it can total across every user). See the SQL in the setup notes.
//

import Foundation
import Supabase

final class SupabaseReactionsService: ReactionsService {
    private let client = Supa.client

    func myReaction(entryID: UUID) async throws -> String? {
        let rows: [ReactionRow] = try await client
            .from("reactions")
            .select("emoji")
            .eq("entry_id", value: entryID)
            .limit(1)
            .execute()
            .value
        return rows.first?.emoji
    }

    func setReaction(_ emoji: String?, entryID: UUID) async throws {
        if let emoji {
            // upsert on (user_id, entry_id): picking a new emoji REPLACES the old
            // one rather than adding a second row — one reaction per user per entry.
            let userID = try await client.auth.session.user.id
            try await client
                .from("reactions")
                .upsert(ReactionInsert(user_id: userID, entry_id: entryID, emoji: emoji),
                        onConflict: "user_id,entry_id")
                .execute()
        } else {
            // nil emoji = clear my reaction (RLS limits the delete to my own row).
            try await client
                .from("reactions")
                .delete()
                .eq("entry_id", value: entryID)
                .execute()
        }
    }

    func counts(entryID: UUID) async throws -> [String: Int] {
        // `.rpc(...)` calls a Postgres FUNCTION instead of querying a table. We use
        // one here because totaling reactions across EVERY user would be blocked by
        // RLS on the table — the function is SECURITY DEFINER, so it runs with
        // elevated rights and can aggregate. `params` are the function's arguments.
        let rows: [ReactionCountRow] = try await client
            .rpc("reaction_counts", params: ["p_entry": entryID])
            .execute()
            .value
        // Turn the [(emoji, count)] rows into a dictionary. `uniquingKeysWith` tells
        // Dictionary how to resolve duplicate keys (shouldn't happen — keep the first).
        return Dictionary(rows.map { ($0.emoji, $0.count) }, uniquingKeysWith: { a, _ in a })
    }
}

private struct ReactionRow: Decodable { let emoji: String }
private struct ReactionInsert: Encodable {
    let user_id: UUID
    let entry_id: UUID
    let emoji: String
}
private struct ReactionCountRow: Decodable {
    let emoji: String
    let count: Int
}
