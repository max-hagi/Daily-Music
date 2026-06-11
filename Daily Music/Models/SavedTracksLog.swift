//
//  SavedTracksLog.swift
//  Daily Music
//
//  Which entries the user already saved to their Apple Music playlist, so the
//  save button shows "Added" and we never double-add. UserDefaults-backed,
//  same pattern as CatchUpLog.
//

import Foundation

@MainActor
@Observable
final class SavedTracksLog {
    private(set) var savedEntryIDs: Set<UUID>

    private let defaults: UserDefaults
    private static let key = "appleMusic.savedEntryIDs"
    /// One save per daily entry — a year of daily saves fits comfortably.
    private static let maxStored = 400

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Self.key) ?? []
        savedEntryIDs = Set(stored.compactMap(UUID.init(uuidString:)))
    }

    func isSaved(_ entry: DailyEntry) -> Bool {
        savedEntryIDs.contains(entry.id)
    }

    func markSaved(_ entry: DailyEntry) {
        guard !savedEntryIDs.contains(entry.id) else { return }
        savedEntryIDs.insert(entry.id)
        var stored = defaults.stringArray(forKey: Self.key) ?? []
        stored.append(entry.id.uuidString)
        if stored.count > Self.maxStored {
            stored.removeFirst(stored.count - Self.maxStored)
        }
        defaults.set(stored, forKey: Self.key)
    }
}
