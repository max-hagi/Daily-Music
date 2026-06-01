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

// The dependency container, injected into the view tree (see Daily_MusicApp).
// Each stored property is typed as a PROTOCOL (AuthService, EntryService, …) not
// a concrete class. That's the key to the mock/live swap: views only know the
// protocol, so we can hand them mocks in development and real Supabase-backed
// implementations in production without touching a single view.
// @MainActor + @Observable for the same reasons as ArtworkPalette: UI-thread
// safe, and views re-render when observed sub-objects change.
@MainActor
@Observable
final class AppEnvironment {
    let auth: AuthService
    let entries: EntryService
    let favorites: FavoritesService
    let checkIns: CheckInService
    let sharedStats: SharedStatsService
    let reactions: ReactionsService
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
        reactions: ReactionsService,
        notifications: NotificationService,
        musicEngine: MusicEngine
    ) {
        self.auth = auth
        self.entries = entries
        self.favorites = favorites
        self.checkIns = checkIns
        self.sharedStats = sharedStats
        self.reactions = reactions
        self.notifications = notifications
        // These three are WRAPPERS the container builds from the injected pieces:
        // MusicPlayer wraps whichever engine (mock vs MusicKit) it's given, and the
        // two stores wrap a service to add view-facing state. The container owns
        // them so they live as long as the app does.
        self.musicPlayer = MusicPlayer(engine: musicEngine)
        self.session = SessionStore(auth: auth)
        self.favoritesStore = FavoritesStore(service: favorites)
    }

    // Two factory methods that assemble a fully-wired container. Picking `mock()`
    // vs `live()` in Daily_MusicApp is the single switch between fake and real
    // backends. Add a new service by: defining its protocol + mock + Supabase
    // impl, adding a stored property above, and listing it in both factories.

    /// The v1 environment: everything mocked except local notifications.
    static func mock() -> AppEnvironment {
        AppEnvironment(
            auth: MockAuthService(),
            entries: MockEntryService(),
            favorites: MockFavoritesService(),
            checkIns: MockCheckInService(),
            sharedStats: MockSharedStatsService(),
            reactions: MockReactionsService(),
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
            reactions: SupabaseReactionsService(),
            notifications: LocalNotificationService(),
            // Apple Music infrastructure is ready in MusicKitMusicEngine.
            // Once the MusicKit capability is enabled (paid dev account),
            // swap the line below to: MusicKitMusicEngine()
            musicEngine: MockMusicEngine()
        )
    }
}
