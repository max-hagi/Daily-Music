//
//  FavoritesFilter.swift
//  Daily Music
//
//  Pure search + facet narrowing for the Favorites collection. `query` is free
//  text over title + artist; `genres`/`decades`/`moods` are OR within a dimension
//  and AND across dimensions. A nil entry value never matches a constrained
//  dimension.
//

import Foundation

struct FavoritesFilter: Equatable {
    var query: String = ""
    var genres: Set<String> = []
    var decades: Set<String> = []
    var moods: Set<String> = []

    /// True when the facet menu has any selection (drives the toolbar icon's filled state).
    var hasFacetFilters: Bool {
        !genres.isEmpty || !decades.isEmpty || !moods.isEmpty
    }

    /// True when anything (search or facets) is narrowing the list.
    var isActive: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty || hasFacetFilters
    }

    func matches(_ entry: DailyEntry) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            let hay = "\(entry.title) \(entry.artist)".lowercased()
            if !hay.contains(q) { return false }
        }
        if !genres.isEmpty { guard let g = entry.genre, genres.contains(g) else { return false } }
        if !decades.isEmpty { guard let d = entry.decade, decades.contains(d) else { return false } }
        if !moods.isEmpty { guard let m = entry.mood, moods.contains(m) else { return false } }
        return true
    }
}

/// Distinct, non-empty, sorted facet values present in `favorites` — used to build
/// the filter sheet so it only offers values that actually exist.
func favoritesFacets(in favorites: [DailyEntry])
    -> (genres: [String], decades: [String], moods: [String]) {
    func distinct(_ values: [String?]) -> [String] {
        Array(Set(values.compactMap { $0 }.filter { !$0.isEmpty })).sorted()
    }
    return (
        genres: distinct(favorites.map(\.genre)),
        decades: distinct(favorites.map(\.decade)),
        moods: distinct(favorites.map(\.mood))
    )
}
