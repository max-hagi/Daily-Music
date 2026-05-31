//
//  InsightsViewModel.swift
//  Daily Music
//
//  Computes the Insights stats: the current streak (from check-in days) and the
//  number of songs discovered (published entries). Favourites count is read
//  straight off FavoritesStore in the view since it's already reactive.
//

import Foundation

@MainActor
@Observable
final class InsightsViewModel {
    struct Stats {
        var streak: Int
        var discovered: Int
    }

    private(set) var state: LoadState<Stats> = .loading

    private let entries: EntryService
    private let checkIns: CheckInService

    init(entries: EntryService, checkIns: CheckInService) {
        self.entries = entries
        self.checkIns = checkIns
    }

    func load() async {
        state = .loading
        do {
            let dates = try await checkIns.checkInDates()
            let history = try await entries.publishedHistory()
            state = .loaded(Stats(
                streak: Streak.current(from: dates),
                discovered: history.count
            ))
        } catch {
            state = .failed(error)
        }
    }
}
