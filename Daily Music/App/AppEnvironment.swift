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
    let listens: ListensService
    let checkIns: CheckInService
    let sharedStats: SharedStatsService
    let reactions: ReactionsService
    let ratings: RatingService
    let catalogInfo: CatalogInfoService
    let settings: SettingsService
    let profiles: ProfileService
    let friends: FriendService
    let friendNudges: FriendNudgeService
    let notifications: NotificationService
    let pushRegistration: PushRegistrationService
    let musicPlayer: MusicPlayer
    let session: SessionStore
    let favoritesStore: FavoritesStore
    let listensStore: ListensStore
    let ratingsStore: RatingsStore
    let profileStore: ProfileStore
    let friendsStore: FriendsStore
    let friendNudgeStore: FriendNudgeStore
    let appleMusic: AppleMusicSession
    let spotify: SpotifySession
    let savedTracks: SavedTracksLog
    /// The four redesign taste-call choices (spec §11), one shared instance so the
    /// live Vault reads the locked picks (and a debug gallery can bind to the same).
    let variants = VariantConfig()
    /// Every connectable service, in priority order (Apple Music first; both
    /// can't grant saves simultaneously today — its flag is off).
    var musicServices: [any MusicServiceConnection] { [appleMusic, spotify] }

    /// The connected service that can take a library save right now, if any —
    /// drives the save button's visibility and routing.
    var librarySaveService: (any MusicServiceConnection)? {
        musicServices.first { $0.status.capabilities.contains(.librarySave) }
    }

    init(
        auth: AuthService,
        entries: EntryService,
        favorites: FavoritesService,
        listens: ListensService,
        checkIns: CheckInService,
        sharedStats: SharedStatsService,
        reactions: ReactionsService,
        ratings: RatingService,
        catalogInfo: CatalogInfoService,
        settings: SettingsService,
        profiles: ProfileService,
        friends: FriendService,
        friendNudges: FriendNudgeService,
        notifications: NotificationService,
        pushRegistration: PushRegistrationService,
        musicEngine: MusicEngine,
        fullMusicEngine: MusicEngine? = nil,
        appleMusicAuthorizer: AppleMusicAuthorizing,
        appleMusicLibrary: AppleMusicLibraryWriting = MusicKitLibraryWriter(),
        spotify: SpotifySession
    ) {
        self.auth = auth
        self.entries = entries
        self.favorites = favorites
        self.listens = listens
        self.checkIns = checkIns
        self.sharedStats = sharedStats
        self.reactions = reactions
        self.ratings = ratings
        // The Apple Music session must exist before the player (routing) and
        // the enriched catalog (capability gating) — both read it.
        self.appleMusic = AppleMusicSession(authorizer: appleMusicAuthorizer, library: appleMusicLibrary)
        self.spotify = spotify
        self.savedTracks = SavedTracksLog()
        // Enriched lookup decorates the base when the flag is on; the session's
        // capabilities gate it per-call, so non-connected users hit the base path.
        self.catalogInfo = FeatureFlags.appleMusicConnect
            ? EnrichedCatalogInfoService(base: catalogInfo, session: appleMusic)
            : catalogInfo
        self.settings = settings
        self.profiles = profiles
        self.friends = friends
        self.friendNudges = friendNudges
        self.notifications = notifications
        self.pushRegistration = pushRegistration
        // These four are WRAPPERS the container builds from the injected pieces:
        // MusicPlayer wraps whichever engine (mock vs MusicKit) it's given, and the
        // stores wrap a service to add view-facing state. The container owns
        // them so they live as long as the app does.
        self.musicPlayer = MusicPlayer(
            engine: musicEngine,
            fullEngine: fullMusicEngine,
            appleMusic: appleMusic
        )
        self.session = SessionStore(auth: auth)
        self.favoritesStore = FavoritesStore(service: favorites)
        self.listensStore = ListensStore(service: listens)
        self.ratingsStore = RatingsStore(service: ratings)
        self.profileStore = ProfileStore(service: profiles)
        self.friendsStore = FriendsStore(service: friends)
        self.friendNudgeStore = FriendNudgeStore(service: friendNudges)
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
            listens: MockListensService(),
            checkIns: MockCheckInService(),
            sharedStats: MockSharedStatsService(),
            reactions: MockReactionsService(),
            ratings: MockRatingService(),
            catalogInfo: MockCatalogInfoService(),
            settings: MockSettingsService(),
            profiles: MockProfileService(),
            friends: MockFriendService(),
            friendNudges: MockFriendNudgeService(),
            notifications: LocalNotificationService(),
            pushRegistration: MockPushRegistrationService(),
            musicEngine: MockMusicEngine(),
            // A second mock engine + auto-authorizing mock authorizer make every
            // connected state (full playback, saves, rich metadata) explorable
            // in the simulator without the MusicKit entitlement.
            fullMusicEngine: MockMusicEngine(),
            appleMusicAuthorizer: MockAppleMusicAuthorizer(),
            appleMusicLibrary: MockAppleMusicLibraryWriter(),
            // Connect-on-tap with a stubbed save so simulator saves never hit HTTP.
            spotify: SpotifySession(
                authenticator: MockSpotifyAuthenticator(),
                save: { _, _ in try? await Task.sleep(for: .milliseconds(400)) }
            )
        )
    }

    /// Production wiring: Supabase-backed auth/content/user state, local
    /// notifications, and a mock music engine until MusicKit is enabled.
    static func live() -> AppEnvironment {
        let catalog = LiveCatalogInfoService()
        return AppEnvironment(
            auth: SupabaseAuthService(),
            entries: SupabaseEntryService(),
            favorites: SupabaseFavouritesService(),
            listens: SupabaseListensService(),
            checkIns: SupabaseCheckInService(),
            sharedStats: SupabaseSharedStatsService(),
            reactions: SupabaseReactionsService(),
            ratings: SupabaseRatingService(),
            catalogInfo: catalog,
            settings: SupabaseSettingsService(),
            profiles: SupabaseProfileService(),
            friends: SupabaseFriendService(),
            friendNudges: SupabaseFriendNudgeService(),
            notifications: LocalNotificationService(),
            pushRegistration: SupabasePushRegistrationService(),
            // Free 30-sec previews via the iTunes lookup — the universal floor.
            musicEngine: PreviewMusicEngine(catalog: catalog),
            // Dormant until FeatureFlags.appleMusicConnect: no full engine means
            // routing can never leave the preview path.
            fullMusicEngine: FeatureFlags.appleMusicConnect ? FullTrackMusicEngine() : nil,
            appleMusicAuthorizer: MusicKitAuthorizer(),
            spotify: SpotifySession(authenticator: SpotifyAuthenticator())
        )
    }
}
