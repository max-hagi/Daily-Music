//
//  ProfileService.swift
//  Daily Music
//
//  The profile seam. `save` writes BOTH identity fields (callers pass the current
//  name and avatar), so it never accidentally clears one. The mock keeps a single
//  in-memory profile so previews and tests need no network.
//

import Foundation

protocol ProfileService: Sendable {
    func load() async throws -> UserProfile?
    func save(displayName: String?, avatarURL: String?) async throws
    /// Uploads JPEG bytes and returns the public URL string to store in `avatar_url`.
    func uploadAvatar(_ jpegData: Data) async throws -> String
}

actor MockProfileService: ProfileService {
    private var profile = UserProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
        displayName: nil,
        avatarURL: nil
    )

    func load() async throws -> UserProfile? { profile }

    func save(displayName: String?, avatarURL: String?) async throws {
        profile.displayName = displayName
        profile.avatarURL = avatarURL
    }

    func uploadAvatar(_ jpegData: Data) async throws -> String {
        "mock://avatar/\(UUID().uuidString).jpg"
    }
}
