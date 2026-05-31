//
//  DailyEntry.swift
//  Daily Music
//
//  The core content unit: one curated song + journal entry for a given day.
//  Mirrors the `daily_entries` table in Supabase (see the v1 design spec).
//

import Foundation

struct DailyEntry: Identifiable, Hashable, Codable {
    let id: UUID
    /// The calendar day this entry belongs to. One entry per day.
    let date: Date
    let title: String
    let artist: String
    let albumArtURL: URL?
    /// The journal piece, authored as Markdown.
    let journalMarkdown: String
    /// Apple Music catalog ID — drives the 30-sec preview + add-to-playlist.
    let appleMusicID: String
    /// Spotify URI (e.g. "spotify:track:...") — used for the deep-link-out button.
    let spotifyURI: String
    /// Curated genre (e.g. "Pop", "Alternative"). Drives genre-based taste
    /// archetypes + the top-genres signal. nil until set on the entry.
    var genre: String? = nil

    /// Deep link that opens this track in the Apple Music app (or the web fallback).
    var appleMusicURL: URL? {
        URL(string: "https://music.apple.com/song/\(appleMusicID)")
    }

    /// Deep link that opens this track in the Spotify app (or the web fallback).
    var spotifyURL: URL? {
        // spotify:track:ID  →  https://open.spotify.com/track/ID
        let trackID = spotifyURI.split(separator: ":").last.map(String.init) ?? spotifyURI
        return URL(string: "https://open.spotify.com/track/\(trackID)")
    }
}
