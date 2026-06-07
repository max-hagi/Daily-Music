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

    /// Server source of truth: has this user finished the first-run wizard?
    var isOnboarded: Bool { current?.isOnboarded ?? false }

    func load() async { current = try? await service.load() }

    func save(displayName: String?, avatarURL: String?) async throws {
        try await service.save(displayName: displayName, avatarURL: avatarURL)
        await load()
    }

    /// Stamps `onboarded_at` on the server, then reloads so `current.isOnboarded`
    /// reflects it. Called once when the wizard's Finish step succeeds.
    func markOnboarded() async throws {
        try await service.markOnboarded()
        await load()
    }

    func uploadAvatar(_ data: Data) async throws -> String {
        try await service.uploadAvatar(data)
    }
}
