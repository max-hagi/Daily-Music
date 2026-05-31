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
        /// Dominant genre among the user's favorites — personalizes the archetype
        /// (everyone hears the same songs, so genre signal comes from favorites).
        var topGenre: String? = nil
        /// Average songs per artist — the "depth" signal.
        var depth: Double { artistsDiscovered > 0 ? Double(songsHeard) / Double(artistsDiscovered) : 0 }
    }

    static func resolve(_ m: Metrics) -> TasteProfile {
        // Genre-based archetypes win when we have a clear favorite genre…
        if let genre = m.topGenre, let profile = genreArchetypes[genre] {
            return profile
        }
        // …otherwise fall back to behavior-based archetypes.
        return rules.first { $0.match(m) }?.profile ?? steadyListener
    }

    static func from(seen: [DailyEntry], favorites: Int = 0, topGenre: String? = nil) -> TasteProfile {
        resolve(Metrics(
            songsHeard: seen.count,
            artistsDiscovered: Set(seen.map(\.artist)).count,
            favorites: favorites,
            topGenre: topGenre
        ))
    }

    /// Most common non-nil genre among the given entries (e.g. a user's favorites).
    static func dominantGenre(of entries: [DailyEntry]) -> String? {
        let counts = entries.compactMap(\.genre).reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key
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

    /// Genre → archetype. Edit names/colors and add genres freely as the catalogue
    /// grows. Keys must match the `genre` strings you store on entries.
    private static let genreArchetypes: [String: TasteProfile] = [
        "Pop": TasteProfile(
            title: "Pop Perfectionist",
            blurb: "Crisp hooks, polished production, and choruses that land exactly where they should.",
            symbol: "sparkles",
            colors: [Color(red: 0.96, green: 0.28, blue: 0.55), Color(red: 0.55, green: 0.24, blue: 0.9)]
        ),
        "Alternative": TasteProfile(
            title: "Indie Heart",
            blurb: "You go for feeling over formula — songs with a little ache in them.",
            symbol: "guitars.fill",
            colors: [Color(red: 0.2, green: 0.6, blue: 0.55), Color(red: 0.1, green: 0.36, blue: 0.55)]
        ),
        "Synthwave": TasteProfile(
            title: "Neon Romantic",
            blurb: "Midnight drives and analog glow. You like your nostalgia in widescreen.",
            symbol: "bolt.horizontal.fill",
            colors: [Color(red: 0.85, green: 0.16, blue: 0.62), Color(red: 0.27, green: 0.2, blue: 0.78)]
        ),
        "Electronic": TasteProfile(
            title: "Pulse Seeker",
            blurb: "You chase the build, the drop, the groove that won't sit still.",
            symbol: "waveform.path.ecg",
            colors: [Color(red: 0.0, green: 0.7, blue: 0.78), Color(red: 0.18, green: 0.32, blue: 0.86)]
        ),
        "Rock": TasteProfile(
            title: "Rock Purist",
            blurb: "Guitars, grit, and a good riff. You like it loud and honest.",
            symbol: "flame.fill",
            colors: [Color(red: 0.82, green: 0.22, blue: 0.18), Color(red: 0.5, green: 0.12, blue: 0.1)]
        ),
        "Hip-Hop": TasteProfile(
            title: "Rhythm Scholar",
            blurb: "Bars, flow, and production you feel in your chest. Word is bond.",
            symbol: "mic.fill",
            colors: [Color(red: 0.95, green: 0.6, blue: 0.05), Color(red: 0.6, green: 0.18, blue: 0.4)]
        ),
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
