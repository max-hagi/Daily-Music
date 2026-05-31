//
//  InsightsViewModel.swift
//  Daily Music
//
//  Builds the discovery-focused Insights stats: a taste archetype and artist
//  count derived from the songs the user has actually opened (check-in dates ∩
//  published entries), plus today's shared listener count.
//

import Foundation

@MainActor
@Observable
final class InsightsViewModel {
    struct Stats {
        var tasteProfile: TasteProfile
        var artistsDiscovered: Int
        var listenersToday: Int
        /// Today's album art — used to theme the screen with its color.
        var artURL: URL?
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

    func load() async {
        state = .loading

        // Each piece degrades independently: a missing/failing optional backend
        // (e.g. the check_ins table before it's created) shouldn't blank the page.
        let dates = (try? await checkIns.checkInDates()) ?? []
        let history = (try? await entries.publishedHistory()) ?? []
        let listeners = (try? await sharedStats.todaysListenerCount()) ?? 0
        let today = (try? await entries.todayEntry()) ?? nil

        let calendar = Calendar.current
        let seen = history.filter { dates.contains(calendar.startOfDay(for: $0.date)) }

        state = .loaded(Stats(
            tasteProfile: .from(seen: seen),
            artistsDiscovered: Set(seen.map(\.artist)).count,
            listenersToday: listeners,
            artURL: today?.albumArtURL
        ))
    }
}
