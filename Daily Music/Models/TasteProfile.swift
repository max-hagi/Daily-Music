//
//  TasteProfile.swift
//  Daily Music
//
//  The taste-archetype engine. A fixed catalogue of named profiles, each with a
//  rule, color, and copy. `resolve` walks the rules in order (most specific
//  first) and returns the first match, falling back to a default.
//
//  Today the rules use the data we actually have — songs heard, artists
//  discovered, favorites, and listening depth — so every archetype is earned,
//  not hardcoded. Genre-flavored archetypes (e.g. "Pop Perfectionist") plug in
//  here once a `genre` field exists on entries: add a Metrics.topGenre and a
//  rule that reads it. Names/rules/colors below are meant to be edited freely.
//

import SwiftUI

struct TasteProfile: Equatable {
    let title: String
    let blurb: String
    let symbol: String
    let colors: [Color]

    struct Metrics {
        var songsHeard: Int
        var artistsDiscovered: Int
        var favorites: Int
        /// Average songs per artist — the "depth" signal.
        var depth: Double { artistsDiscovered > 0 ? Double(songsHeard) / Double(artistsDiscovered) : 0 }
    }

    static func resolve(_ m: Metrics) -> TasteProfile {
        rules.first { $0.match(m) }?.profile ?? steadyListener
    }

    static func from(seen: [DailyEntry], favorites: Int = 0) -> TasteProfile {
        resolve(Metrics(
            songsHeard: seen.count,
            artistsDiscovered: Set(seen.map(\.artist)).count,
            favorites: favorites
        ))
    }

    // MARK: - Archetype catalogue (edit names / rules / colors freely)

    private struct Rule {
        let match: (Metrics) -> Bool
        let profile: TasteProfile
    }

    private static let rules: [Rule] = [
        Rule(match: { $0.songsHeard == 0 }, profile: newListener),
        Rule(match: { $0.songsHeard < 5 }, profile: TasteProfile(
            title: "Curious Newcomer",
            blurb: "A few songs in — your taste is just starting to take shape.",
            symbol: "leaf.fill",
            colors: [Color(red: 0.18, green: 0.72, blue: 0.51), Color(red: 0.05, green: 0.55, blue: 0.55)]
        )),
        Rule(match: { $0.favorites >= 8 && $0.favorites >= $0.songsHeard / 2 }, profile: TasteProfile(
            title: "The Devotee",
            blurb: "You don't just listen — you fall in love. Hearts everywhere.",
            symbol: "heart.fill",
            colors: [Color(red: 0.96, green: 0.27, blue: 0.45), Color(red: 0.79, green: 0.13, blue: 0.55)]
        )),
        Rule(match: { $0.depth >= 2 }, profile: TasteProfile(
            title: "Deep Diver",
            blurb: "You return to the artists you love and really go deep.",
            symbol: "arrow.down.circle.fill",
            colors: [Color(red: 0.42, green: 0.31, blue: 0.93), Color(red: 0.24, green: 0.18, blue: 0.66)]
        )),
        Rule(match: { $0.artistsDiscovered >= 20 }, profile: TasteProfile(
            title: "Eclectic Explorer",
            blurb: "Always chasing the next new name. Range for days.",
            symbol: "globe.americas.fill",
            colors: [Color(red: 1.0, green: 0.55, blue: 0.16), Color(red: 0.0, green: 0.62, blue: 0.74)]
        )),
        Rule(match: { $0.favorites >= 15 }, profile: TasteProfile(
            title: "The Collector",
            blurb: "A curator at heart — your favorites shelf runs deep.",
            symbol: "square.stack.3d.up.fill",
            colors: [Color(red: 0.95, green: 0.61, blue: 0.07), Color(red: 0.85, green: 0.35, blue: 0.13)]
        )),
        Rule(match: { $0.songsHeard >= 40 }, profile: TasteProfile(
            title: "Connoisseur",
            blurb: "Seasoned ears. You've heard a lot and know exactly what you like.",
            symbol: "crown.fill",
            colors: [Color(red: 0.36, green: 0.28, blue: 0.92), Color(red: 0.13, green: 0.16, blue: 0.45)]
        )),
    ]

    private static let newListener = TasteProfile(
        title: "New Listener",
        blurb: "Your story starts with today's song.",
        symbol: "sparkles",
        colors: [Color(red: 0.45, green: 0.5, blue: 0.62), Color(red: 0.28, green: 0.32, blue: 0.45)]
    )

    private static let steadyListener = TasteProfile(
        title: "Steady Listener",
        blurb: "Showing up for the music, one day at a time.",
        symbol: "music.note",
        colors: [Color(red: 0.21, green: 0.49, blue: 0.93), Color(red: 0.11, green: 0.31, blue: 0.7)]
    )
}
