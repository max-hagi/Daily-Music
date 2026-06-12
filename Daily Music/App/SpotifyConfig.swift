//
//  SpotifyConfig.swift
//  Daily Music
//
//  Spotify app registration values. ALL PUBLIC — the client ID ships in the
//  binary by design (PKCE needs no secret; the secret stays in the Spotify
//  dashboard and must never enter this repo).
//

import Foundation

enum SpotifyConfig {
    static let clientID = "af09508c18cf406e963ed6fc82be10ba"
    /// Must match the dashboard registration character-exactly.
    static let redirectURI = "dailymusic://spotify-callback"
    static let callbackScheme = "dailymusic"
    /// Minimal ask: find/create + write our private playlist. No Liked Songs,
    /// no profile data beyond the id (which any token can read).
    static let scopes = "playlist-modify-private playlist-read-private"
}
