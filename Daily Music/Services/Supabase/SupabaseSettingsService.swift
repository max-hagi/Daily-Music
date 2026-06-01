//
//  SupabaseSettingsService.swift
//  Daily Music
//
//  Persists the user's preferences in their `profiles` row (a JSONB `settings`
//  column), scoped to the signed-in user by RLS. The settings blob is stored as
//  nested JSON, so adding new preference fields never needs a schema migration.
//

import Foundation
import Supabase

final class SupabaseSettingsService: SettingsService {
    private let client = Supa.client

    func load() async throws -> UserSettings? {
        let userID = try await client.auth.session.user.id
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select("settings")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first?.settings
    }

    func save(_ settings: UserSettings) async throws {
        let userID = try await client.auth.session.user.id
        try await client
            .from("profiles")
            .upsert(ProfileUpsert(id: userID, settings: settings), onConflict: "id")
            .execute()
    }
}

private struct ProfileRow: Decodable {
    let settings: UserSettings
}

private struct ProfileUpsert: Encodable {
    let id: UUID
    let settings: UserSettings
}
