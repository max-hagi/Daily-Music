//
//  AppEnvironment.swift
//  Daily Music
//
//  The composition root. One place decides which concrete services the app
//  runs with. Views depend on protocols, so switching between mock and live
//  services happens here without moving view code.
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
    let ratings: RatingService
    let catalogInfo: CatalogInfoService
    let settings: SettingsService
    let profiles: ProfileService
    let friends: FriendService
    let notifications: NotificationService
    let musicPlayer: MusicPlayer
    let session: SessionStore
    let favoritesStore: FavoritesStore
    let profileStore: ProfileStore
    let friendsStore: FriendsStore

    init(
        auth: AuthService,
        entries: EntryService,
        favorites: FavoritesService,
        checkIns: CheckInService,
        sharedStats: SharedStatsService,
        reactions: ReactionsService,
        ratings: RatingService,
        catalogInfo: CatalogInfoService,
        settings: SettingsService,
        profiles: ProfileService,
        friends: FriendService,
        notifications: NotificationService,
        musicEngine: MusicEngine
    ) {
        self.auth = auth
        self.entries = entries
        self.favorites = favorites
        self.checkIns = checkIns
        self.sharedStats = sharedStats
        self.reactions = reactions
        self.ratings = ratings
        self.catalogInfo = catalogInfo
        self.settings = settings
        self.profiles = profiles
        self.friends = friends
        self.notifications = notifications
        // These four are WRAPPERS the container builds from the injected pieces:
        // MusicPlayer wraps whichever engine (mock vs MusicKit) it's given, and the
        // stores wrap a service to add view-facing state. The container owns
        // them so they live as long as the app does.
        self.musicPlayer = MusicPlayer(engine: musicEngine)
        self.session = SessionStore(auth: auth)
        self.favoritesStore = FavoritesStore(service: favorites)
        self.profileStore = ProfileStore(service: profiles)
        self.friendsStore = FriendsStore(service: friends)
    }

    // Two factory methods that assemble a fully-wired container. Picking `mock()`
    // vs `live()` is the switch between sample data and production-backed
    // services. Add a new service by: defining its protocol + mock + Supabase
    // impl, adding a stored property above, and listing it in both factories.

    /// Sample-data environment: everything mocked except local notifications.
    static func mock() -> AppEnvironment {
        AppEnvironment(
            auth: MockAuthService(),
            entries: MockEntryService(),
            favorites: MockFavoritesService(),
            checkIns: MockCheckInService(),
            sharedStats: MockSharedStatsService(),
            reactions: MockReactionsService(),
            ratings: MockRatingService(),
            catalogInfo: MockCatalogInfoService(),
            settings: MockSettingsService(),
            profiles: MockProfileService(),
            friends: MockFriendService(),
            notifications: LocalNotificationService(),
            musicEngine: MockMusicEngine()
        )
    }

    /// Production wiring: Supabase-backed auth/content/user state, local
    /// notifications, and a mock music engine until MusicKit is enabled.
    static func live() -> AppEnvironment {
        AppEnvironment(
            auth: SupabaseAuthService(),
            entries: SupabaseEntryService(),
            favorites: SupabaseFavouritesService(),
            checkIns: SupabaseCheckInService(),
            sharedStats: SupabaseSharedStatsService(),
            reactions: SupabaseReactionsService(),
            ratings: SupabaseRatingService(),
            catalogInfo: LiveCatalogInfoService(),
            settings: SupabaseSettingsService(),
            profiles: SupabaseProfileService(),
            friends: SupabaseFriendService(),
            notifications: LocalNotificationService(),
            // Apple Music infrastructure is ready in MusicKitMusicEngine.
            // Once the MusicKit capability is enabled (paid dev account),
            // swap the line below to: MusicKitMusicEngine()
            musicEngine: MockMusicEngine()
        )
    }
}
