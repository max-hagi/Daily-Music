//
//  DailyEntry.swift
//  Daily Music
//
//  The core content unit: one curated song + journal entry for a given day.
//  Mirrors the `daily_entries` table in Supabase (see the v1 design spec).
//

import Foundation

// A plain value type (struct) describing one day's content. The three protocols
// it conforms to each unlock a SwiftUI/Swift capability for free:
//   • Identifiable — gives it a stable `id`, so SwiftUI's List/ForEach can track
//     each row across updates without us writing `id:` everywhere.
//   • Hashable     — lets it be used as a Set element, dictionary key, or as the
//     value in a NavigationLink/navigationDestination.
//   • Codable      — lets Swift automatically convert it to/from JSON, which is
//     how Supabase rows are decoded into this struct (see SupabaseEntryService).
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

    // These are COMPUTED properties: they store nothing, they run their body
    // every time you read them (derived from the stored fields above). Handy for
    // values that are always re-derivable, like turning an ID into a deep link.

    /// Deep link that opens this track in the Apple Music app (or the web fallback).
    var appleMusicURL: URL? {
        URL(string: "https://music.apple.com/song/\(appleMusicID)")
    }

    /// Deep link that opens this track in the Spotify app (or the web fallback).
    var spotifyURL: URL? {
        // spotify:track:ID  →  https://open.spotify.com/track/ID
        // Split on ":", take the last chunk (the bare ID); `.map(String.init)`
        // converts the Substring to a String, and `?? spotifyURI` is the fallback
        // if the split somehow produced nothing.
        let trackID = spotifyURI.split(separator: ":").last.map(String.init) ?? spotifyURI
        return URL(string: "https://open.spotify.com/track/\(trackID)")
    }
}
