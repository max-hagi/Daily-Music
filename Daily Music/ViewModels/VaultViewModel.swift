//
//  VaultViewModel.swift
//  Daily Music
//
//  Loads the back catalogue of published entries for the Vault (newest first).
//

import Foundation

@MainActor
@Observable
final class VaultViewModel {
    private(set) var state: LoadState<[DailyEntry]> = .loading

    private let entries: EntryService

    init(entries: EntryService) {
        self.entries = entries
    }

    func load() async {
        state = .loading
        do {
            let history = try await entries.publishedHistory()
            state = history.isEmpty ? .empty : .loaded(history)
        } catch {
            state = .failed(error)
        }
    }
}
