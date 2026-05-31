//
//  AppEnvironment.swift
//  Daily Music
//
//  The composition root. One place that decides which concrete services the app
//  runs with. v1 wires the mocks; to go live you change the initializers here
//  (e.g. SupabaseEntryService()) and nothing in the views needs to move.
//
//  Injected into SwiftUI via `.environment(...)` and read with
//  `@Environment(AppEnvironment.self)`.
//

import SwiftUI

@MainActor
@Observable
final class AppEnvironment {
    let auth: AuthService
    let entries: EntryService
    let favorites: FavoritesService
    let notifications: NotificationService
    let musicPlayer: MusicPlayer
    let session: SessionStore
    let favoritesStore: FavoritesStore

    init(
        auth: AuthService,
        entries: EntryService,
        favorites: FavoritesService,
        notifications: NotificationService,
        musicEngine: MusicEngine
    ) {
        self.auth = auth
        self.entries = entries
        self.favorites = favorites
        self.notifications = notifications
        self.musicPlayer = MusicPlayer(engine: musicEngine)
        self.session = SessionStore(auth: auth)
        self.favoritesStore = FavoritesStore(service: favorites)
    }

    /// The v1 environment: everything mocked except local notifications.
    static func mock() -> AppEnvironment {
        AppEnvironment(
            auth: MockAuthService(),
            entries: MockEntryService(),
            favorites: MockFavoritesService(),
            notifications: LocalNotificationService(),
            musicEngine: MockMusicEngine()
        )
    }

    /// Live entries from Supabase; auth/favorites/music still mocked until we
    /// wire each of those to its real implementation.
    static func live() -> AppEnvironment {
        AppEnvironment(
            auth: MockAuthService(),
            entries: SupabaseEntryService(),
            favorites: MockFavoritesService(),
            notifications: LocalNotificationService(),
            musicEngine: MockMusicEngine()
        )
    }
}
