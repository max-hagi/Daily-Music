//
//  DailyEntry.swift
//  Daily Music
//
//  The core content unit: one curated song + journal entry for a given day.
//  This is the app-facing model that Supabase rows map into.
//

import Foundation

// A plain value type (struct) describing one day's content. The three protocols
// it conforms to each unlock a SwiftUI/Swift capability for free:
//   • Identifiable — gives it a stable `id`, so SwiftUI's List/ForEach can track
//     each row across updates without us writing `id:` everywhere.
//   • Hashable     — lets it be used as a Set element, dictionary key, or as the
//     value in a NavigationLink/navigationDestination.
//   • Codable      — lets Swift automatically convert it to/from JSON when needed.
//     Live Supabase rows decode into DailyEntryRow, then map into this model.
struct DailyEntry: Identifiable, Hashable, Codable {
    let id: UUID
    /// The calendar day this entry belongs to. One entry per day.
    let date: Date
    let title: String
    let artist: String
    // URL? (optional) because the artwork link may be missing or unparseable.
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
    /// Release year (e.g. 1986). Decade is derived from it. nil until tagged.
    var year: Int? = nil
    /// Emotional tone — one of `Mood`'s raw values. nil until tagged.
    var mood: String? = nil
    /// Arousal/intensity, 1 (intimate) … 5 (explosive). nil until tagged.
    var energy: Int? = nil
    /// What the song is about — one of `Theme`'s raw values. nil until tagged.
    var theme: String? = nil
    /// Language/origin (e.g. "English"). nil/blank treated as untagged.
    var language: String? = nil

    // These are COMPUTED properties: they store nothing, they run their body
    // every time you read them (derived from the stored fields above). Handy for
    // values that are always re-derivable, like turning an ID into a deep link.

    /// Deep link that opens this track in the Apple Music app (or the web fallback).
    var appleMusicURL: URL? {
        URL(string: "https://music.apple.com/song/\(appleMusicID)")
    }

    /// The bare Spotify track ID — "spotify:track:X" → "X" (already-bare IDs
    /// pass through). Used by deep links and the Web API save.
    var spotifyTrackID: String {
        spotifyURI.split(separator: ":").last.map(String.init) ?? spotifyURI
    }

    /// Deep link that opens this track in the Spotify app (or the web fallback).
    var spotifyURL: URL? {
        URL(string: "https://open.spotify.com/track/\(spotifyTrackID)")
    }

    /// Decade label derived from `year`, e.g. 1986 → "1980s". nil if untagged.
    var decade: String? {
        guard let year else { return nil }
        return "\((year / 10) * 10)s"
    }
}
