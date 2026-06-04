//
//  ProfileStore.swift
//  Daily Music
//
//  Owns "who I am" for the app (Settings header now, friend bubbles later).
//  Mirrors SessionStore / FavoritesStore: wraps a service and exposes observable
//  state. After a save it re-loads so `current` reflects the source of truth.
//

import Foundation

@MainActor
@Observable
final class ProfileStore {
    private(set) var current: UserProfile?
    private let service: ProfileService

    init(service: ProfileService) { self.service = service }

    func load() async { current = try? await service.load() }

    func save(displayName: String?, avatarURL: String?) async throws {
        try await service.save(displayName: displayName, avatarURL: avatarURL)
        await load()
    }

    func uploadAvatar(_ data: Data) async throws -> String {
        try await service.uploadAvatar(data)
    }
}
