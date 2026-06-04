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
        let userID = try await client.auth.session.user.id
        let rows: [ReactionRow] = try await client
            .from("reactions")
            .select("emoji")
            .eq("user_id", value: userID)
            .eq("entry_id", value: entryID)
            .limit(1)
            .execute()
            .value
        return rows.first?.emoji
    }

    func setReaction(_ emoji: String?, entryID: UUID) async throws {
        let userID = try await client.auth.session.user.id

        if let emoji {
            // upsert on (user_id, entry_id): picking a new emoji REPLACES the old
            // one rather than adding a second row — one reaction per user per entry.
            try await client
                .from("reactions")
                .upsert(ReactionInsert(user_id: userID, entry_id: entryID, emoji: emoji),
                        onConflict: "user_id,entry_id")
                .execute()
        } else {
            // nil emoji = clear my reaction. Filter by user_id explicitly so the UI
            // reflects exactly the current user's stored row, independent of RLS shape.
            try await client
                .from("reactions")
                .delete()
                .eq("user_id", value: userID)
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

    func myReactions() async throws -> [UUID: String] {
        // RLS already restricts SELECT to our own rows, so no user filter is needed
        // for correctness — but we pass it explicitly to match the other methods.
        let userID = try await client.auth.session.user.id
        let rows: [MyReactionRow] = try await client
            .from("reactions")
            .select("entry_id, emoji")
            .eq("user_id", value: userID)
            .execute()
            .value
        return Dictionary(rows.map { ($0.entry_id, $0.emoji) }, uniquingKeysWith: { a, _ in a })
    }
}

private struct ReactionRow: Decodable { let emoji: String }
private struct MyReactionRow: Decodable { let entry_id: UUID; let emoji: String }
private struct ReactionInsert: Encodable {
    let user_id: UUID
    let entry_id: UUID
    let emoji: String
}
private struct ReactionCountRow: Decodable {
    let emoji: String
    let count: Int
}
