//
//  TasteProfile.swift
//  Daily Music
//
//  Derives a playful "taste archetype" from the songs a user has discovered.
//  Identity, not obligation (Bourdieu's cultural capital): the app reflects who
//  you are as a listener back at you. Pure logic so it's easy to reason about
//  and tune. Today it works off artist breadth vs. depth; it gets richer once
//  genres / decades exist in the catalog.
//

import Foundation

struct TasteProfile: Equatable {
    let title: String
    let blurb: String
    let symbol: String

    /// `seen` is the set of entries the user has actually opened.
    static func from(seen: [DailyEntry]) -> TasteProfile {
        let total = seen.count
        let distinctArtists = Set(seen.map(\.artist)).count
        // Average songs heard per artist — the "depth" signal.
        let depth = distinctArtists > 0 ? Double(total) / Double(distinctArtists) : 0

        switch (total, distinctArtists, depth) {
        case (0, _, _):
            return .init(title: "New Listener",
                         blurb: "Your story starts with today's song.",
                         symbol: "sparkles")
        case (_, ..<4, _):
            return .init(title: "Just Getting Started",
                         blurb: "A few songs in — the collection is taking shape.",
                         symbol: "leaf.fill")
        case (_, _, let d) where d >= 2:
            return .init(title: "The Loyalist",
                         blurb: "You return to the artists you love and go deep.",
                         symbol: "heart.circle.fill")
        case (_, 20..., _):
            return .init(title: "Eclectic Explorer",
                         blurb: "Always chasing the next new name. Range for days.",
                         symbol: "globe.americas.fill")
        default:
            return .init(title: "Curious Wanderer",
                         blurb: "Steadily widening your taste, one day at a time.",
                         symbol: "map.fill")
        }
    }
}
