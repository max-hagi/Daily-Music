//
//  InsightsViewModel.swift
//  Daily Music
//
//  Personal stats only. Everyone hears the same daily song, so "songs/artists
//  seen" is identical for all users and isn't personal — the only things that
//  ARE personal are (a) how many days you've shown up (check-ins) and (b) what
//  you've liked. So the archetype, genres, and artist count all come from
//  favorites; days-logged-in comes from check-ins.
//

import Foundation

@MainActor
@Observable
final class InsightsViewModel {
    // Identifiable (id = name) so ForEach can list these; Equatable so SwiftUI
    // can diff/animate them. One row of the "top genres" chart.
    struct GenreCount: Identifiable, Equatable {
        var name: String
        var count: Int
        var id: String { name }
    }

    struct Stats {
        /// Days the user opened the app (check-ins) — a count, not a streak.
        var daysLoggedIn: Int
        /// How many songs the user has hearted.
        var favorites: Int
        /// Distinct artists among the user's favorites.
        var artists: Int
        /// Genre breakdown of the user's favorites.
        var topGenres: [GenreCount]
        /// Archetype resolved from the user's favorites.
        var archetype: TasteProfile
    }

    private(set) var state: LoadState<Stats> = .loading

    private let entries: EntryService
    private let checkIns: CheckInService

    init(entries: EntryService, checkIns: CheckInService) {
        self.entries = entries
        self.checkIns = checkIns
    }

    func load(favoriteIDs: Set<UUID>) async {
        state = .loading

        // Degrade independently so a missing optional backend doesn't blank the page.
        let dates = (try? await checkIns.checkInDates()) ?? []
        let history = (try? await entries.publishedHistory()) ?? []

        let favoriteEntries = history.filter { favoriteIDs.contains($0.id) }

        // Genre breakdown of favorites.
        let genreTally = favoriteEntries
            .compactMap(\.genre)
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let topGenres = genreTally
            .map { GenreCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        let favoriteArtists = Set(favoriteEntries.map(\.artist)).count

        // Archetype is fully personal: it reasons about what you LIKED.
        let archetype = TasteProfile.resolve(.init(
            songsHeard: favoriteEntries.count,
            artistsDiscovered: favoriteArtists,
            favorites: favoriteIDs.count,
            topGenre: TasteProfile.dominantGenre(of: favoriteEntries)
        ))

        state = .loaded(Stats(
            daysLoggedIn: dates.count,
            favorites: favoriteIDs.count,
            artists: favoriteArtists,
            topGenres: topGenres,
            archetype: archetype
        ))
    }
}
