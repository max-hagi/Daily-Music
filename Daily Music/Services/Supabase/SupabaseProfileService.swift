//
//  SupabaseProfileService.swift
//  Daily Music
//
//  Live profile persistence: identity columns on the `profiles` row + avatar
//  bytes in the public `avatars` Storage bucket. The avatar path's folder is the
//  LOWERCASED user id — the Storage RLS policy compares it to auth.uid()::text.
//

import Foundation
import Supabase

final class SupabaseProfileService: ProfileService {
    private let client = Supa.client

    func load() async throws -> UserProfile? {
        let userID = try await client.auth.session.user.id
        let rows: [ProfileIdentityRow] = try await client
            .from("profiles")
            .select("id, display_name, avatar_url")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first.map {
            UserProfile(id: $0.id, displayName: $0.displayName, avatarURL: $0.avatarURL)
        }
    }

    func save(displayName: String?, avatarURL: String?) async throws {
        let userID = try await client.auth.session.user.id

        // Old auth users may not have a profiles row. Insert a complete row first
        // so NOT NULL columns such as settings/display_name are satisfied, but do
        // not overwrite existing rows.
        try await client
            .from("profiles")
            .upsert(
                ProfileInsert(
                    id: userID,
                    displayName: displayName,
                    avatarURL: avatarURL,
                    settings: UserSettings()
                ),
                onConflict: "id",
                ignoreDuplicates: true
            )
            .execute()

        // Patch identity fields only. This preserves any settings blob that already
        // exists or was flushed by onboarding.
        try await client
            .from("profiles")
            .update(ProfileIdentityUpdate(displayName: displayName, avatarURL: avatarURL))
            .eq("id", value: userID)
            .execute()
    }

    func uploadAvatar(_ jpegData: Data) async throws -> String {
        let userID = try await client.auth.session.user.id
        let path = "\(userID.uuidString.lowercased())/avatar_\(Int(Date().timeIntervalSince1970)).jpg"
        try await client.storage
            .from("avatars")
            .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return try client.storage.from("avatars").getPublicURL(path: path).absoluteString
    }
}

private struct ProfileIdentityRow: Decodable {
    let id: UUID
    let displayName: String?
    let avatarURL: String?
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}

private struct ProfileIdentityUpdate: Encodable {
    let displayName: String?
    let avatarURL: String?
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}

private struct ProfileInsert: Encodable {
    let id: UUID
    let displayName: String?
    let avatarURL: String?
    let settings: UserSettings
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case settings
    }
}
