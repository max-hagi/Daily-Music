//
//  InsightsViewModel.swift
//  Daily Music
//
//  Builds the discovery-focused Insights stats: artists discovered + songs heard
//  (from check-in dates ∩ published entries), the shared listener count, the top
//  genres among the user's favorites, and the resolved taste archetype.
//

import Foundation

@MainActor
@Observable
final class InsightsViewModel {
    struct GenreCount: Identifiable, Equatable {
        var name: String
        var count: Int
        var id: String { name }
    }

    struct Stats {
        var artistsDiscovered: Int
        var songsHeard: Int
        var listenersToday: Int
        var topGenres: [GenreCount]
        var archetype: TasteProfile
    }

    private(set) var state: LoadState<Stats> = .loading

    private let entries: EntryService
    private let checkIns: CheckInService
    private let sharedStats: SharedStatsService

    init(entries: EntryService, checkIns: CheckInService, sharedStats: SharedStatsService) {
        self.entries = entries
        self.checkIns = checkIns
        self.sharedStats = sharedStats
    }

    func load(favoriteIDs: Set<UUID>) async {
        state = .loading

        // Each piece degrades independently: a missing/failing optional backend
        // (e.g. the check_ins table before it's created) shouldn't blank the page.
        let dates = (try? await checkIns.checkInDates()) ?? []
        let history = (try? await entries.publishedHistory()) ?? []
        let listeners = (try? await sharedStats.todaysListenerCount()) ?? 0

        let calendar = Calendar.current
        let seen = history.filter { dates.contains(calendar.startOfDay(for: $0.date)) }
        let favoriteEntries = history.filter { favoriteIDs.contains($0.id) }

        // Genre signal comes from favorites (those differ per user).
        let genreTally = favoriteEntries
            .compactMap(\.genre)
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let topGenres = genreTally
            .map { GenreCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        let archetype = TasteProfile.resolve(.init(
            songsHeard: seen.count,
            artistsDiscovered: Set(seen.map(\.artist)).count,
            favorites: favoriteIDs.count,
            topGenre: TasteProfile.dominantGenre(of: favoriteEntries)
        ))

        state = .loaded(Stats(
            artistsDiscovered: Set(seen.map(\.artist)).count,
            songsHeard: seen.count,
            listenersToday: listeners,
            topGenres: topGenres,
            archetype: archetype
        ))
    }
}
