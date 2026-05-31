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
    let checkIns: CheckInService
    let sharedStats: SharedStatsService
    let notifications: NotificationService
    let musicPlayer: MusicPlayer
    let session: SessionStore
    let favoritesStore: FavoritesStore

    init(
        auth: AuthService,
        entries: EntryService,
        favorites: FavoritesService,
        checkIns: CheckInService,
        sharedStats: SharedStatsService,
        notifications: NotificationService,
        musicEngine: MusicEngine
    ) {
        self.auth = auth
        self.entries = entries
        self.favorites = favorites
        self.checkIns = checkIns
        self.sharedStats = sharedStats
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
            checkIns: MockCheckInService(),
            sharedStats: MockSharedStatsService(),
            notifications: LocalNotificationService(),
            musicEngine: MockMusicEngine()
        )
    }

    /// Live entries from Supabase; auth/favorites/music still mocked until we
    /// wire each of those to its real implementation.
    static func live() -> AppEnvironment {
        AppEnvironment(
            auth: SupabaseAuthService(),
            entries: SupabaseEntryService(),
            favorites: SupabaseFavouritesService(),
            checkIns: SupabaseCheckInService(),
            sharedStats: SupabaseSharedStatsService(),
            notifications: LocalNotificationService(),
            // Apple Music infrastructure is ready in MusicKitMusicEngine.
            // Once the MusicKit capability is enabled (paid dev account),
            // swap the line below to: MusicKitMusicEngine()
            musicEngine: MockMusicEngine()
        )
    }
}
