//
//  TodayViewModel.swift
//  Daily Music
//
//  Loads today's curated entry and exposes it as a LoadState the hero screen
//  renders. nil from the service means "nothing published yet" → .empty.
//

import Foundation

@MainActor
@Observable
final class TodayViewModel {
    private(set) var state: LoadState<DailyEntry> = .loading

    private let entries: EntryService

    init(entries: EntryService) {
        self.entries = entries
    }

    func load() async {
        state = .loading
        do {
            if let entry = try await entries.todayEntry() {
                state = .loaded(entry)
            } else {
                state = .empty
            }
        } catch {
            state = .failed(error)
        }
    }
}
