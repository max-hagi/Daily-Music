//
//  TodayViewModel.swift
//  Daily Music
//
//  Loads today's curated entry and exposes it as a LoadState the hero screen
//  renders. nil from the service means "nothing published yet" → .empty.
//

import Foundation

// A view model in the MVVM sense: it holds the screen's STATE (`state`,
// `listenersToday`) and the logic to populate it, leaving TodayView to just draw.
// Services are injected via init (dependency injection) so this is testable and
// backend-agnostic.
@MainActor
@Observable
final class TodayViewModel {
    // The whole screen is driven by this one LoadState — the view switches over it.
    private(set) var state: LoadState<DailyEntry> = .loading
    private(set) var listenersToday: Int?   // optional → nil until/unless we get a count

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
        listenersToday = nil
        do {
            // `if let entry = …` distinguishes "got a song" from "nil = nothing
            // published today" → drive the .empty state deliberately.
            if let entry = try await entries.todayEntry() {
                state = .loaded(entry)
                // Opening today's song counts toward the streak. `try?` = best-effort:
                // if recording the check-in fails, the song still shows.
                try? await checkIns.recordToday()
                listenersToday = try? await sharedStats.todaysListenerCount()
            } else {
                state = .empty
            }
        } catch {
            // Only a real failure to fetch the entry lands here → show an error UI.
            state = .failed(error)
        }
    }
}
