//
//  SpotifySession.swift
//  Daily Music
//
//  Spotify's MusicServiceConnection: capabilities are [.librarySave] only —
//  Spotify offers third-party apps no in-app playback and no rich metadata.
//  Composes the authenticator (tokens) and the library API (saves); the save
//  closure is injected so the state machine tests run without HTTP.
//

import Foundation

@MainActor
@Observable
final class SpotifySession: MusicServiceConnection {
    let service: StreamingService = .spotify
    private(set) var status: MusicConnectionStatus = .notConnected
    private(set) var isConnecting = false

    private let authenticator: SpotifyAuthenticating
    private let defaults: UserDefaults
    /// (trackID, accessToken) → performs the playlist save.
    private let save: (String, String) async throws -> Void

    init(
        authenticator: SpotifyAuthenticating,
        defaults: UserDefaults = .standard,
        save: ((String, String) async throws -> Void)? = nil
    ) {
        self.authenticator = authenticator
        self.defaults = defaults
        let api = SpotifyLibraryAPI(defaults: defaults)
        self.save = save ?? { trackID, token in
            try await api.saveToDailyPlaylist(trackID: trackID, accessToken: token)
        }
    }

    /// Launch path: tokens in the Keychain = connected. No network — the
    /// first save exercises refresh if the access token is stale.
    func restore() async {
        guard authenticator.hasStoredTokens else { return }
        status = .connected([.librarySave])
    }

    func connect() async {
        isConnecting = true
        defer { isConnecting = false }
        do {
            try await authenticator.authorize()
            status = .connected([.librarySave])
        } catch SpotifyAuthError.cancelled {
            // User closed the sheet — quiet, not an error.
        } catch {
            // Failed login (state mismatch, network) — stay disconnected.
        }
    }

    /// Wipes our tokens + cached playlist. Full revocation lives at
    /// spotify.com/account/apps.
    func disconnect() {
        authenticator.clearTokens()
        defaults.removeObject(forKey: "spotify.dailyPlaylistID")
        status = .notConnected
    }

    func saveToLibrary(_ entry: DailyEntry) async throws {
        do {
            let token = try await authenticator.validAccessToken()
            try await save(entry.spotifyTrackID, token)
        } catch SpotifyAuthError.needsReconnect {
            // Refresh token revoked — drop to disconnected so the Settings row
            // offers Connect again, and let the save button show its alert.
            authenticator.clearTokens()
            status = .notConnected
            throw SpotifyAuthError.needsReconnect
        }
    }
}
