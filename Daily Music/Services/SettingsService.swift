//
//  SettingsService.swift
//  Daily Music
//
//  Syncs the user's preferences to their account. v1 mock keeps them in memory;
//  SupabaseSettingsService persists them in the `profiles` row so they follow
//  the account across devices.
//

import Foundation

protocol SettingsService {
    /// The saved settings for the current user, or nil if none stored yet.
    func load() async throws -> UserSettings?
    func save(_ settings: UserSettings) async throws
}

actor MockSettingsService: SettingsService {
    private var stored: UserSettings?
    func load() async throws -> UserSettings? { stored }
    func save(_ settings: UserSettings) async throws { stored = settings }
}
