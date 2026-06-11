//
//  CatchUp.swift
//  Daily Music
//
//  The "missed drops" rule, shared by the Vault hero and the Vault tab badge.
//  A drop is missed when it was published in the last week on a day the user
//  never opened the app — AND they haven't since caught up on it in the Vault.
//  The second condition is what makes catching up satisfying: opening a missed
//  song visibly clears it from the hero and the badge (closure, not nagging).
//

import Foundation

enum CatchUp {
    /// How far back a drop still "counts" as missed. Older ones are just archive.
    static let windowDays = 7

    /// Entries from the window (excluding today — that's the Today tab's moment)
    /// published on days with no check-in, minus the ones already caught up on.
    static func missedEntries(
        in entries: [DailyEntry],
        checkInDays: Set<Date>,
        heardEntryIDs: Set<UUID>,
        calendar: Calendar = .current,
        asOf now: Date = Date()
    ) -> [DailyEntry] {
        let today = calendar.startOfDay(for: now)
        guard let cutoff = calendar.date(byAdding: .day, value: -windowDays, to: today) else { return [] }
        let openedDays = Set(checkInDays.map { calendar.startOfDay(for: $0) })

        return entries.filter { entry in
            let day = calendar.startOfDay(for: entry.date)
            return day >= cutoff
                && day < today
                && !openedDays.contains(day)
                && !heardEntryIDs.contains(entry.id)
        }
    }
}

/// Remembers which archived entries the user has opened, so missed drops clear
/// once they're caught up on. Local-only (UserDefaults): a check-in row records
/// "opened the app today", not "heard Tuesday's song" — this fills that gap.
@MainActor
@Observable
final class CatchUpLog {
    private(set) var heardEntryIDs: Set<UUID>

    private let defaults: UserDefaults
    private static let key = "vault.heardEntryIDs"
    /// Keep the log bounded — entries older than the catch-up window can't
    /// affect anything, so a generous cap is plenty.
    private static let maxStored = 120

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Self.key) ?? []
        heardEntryIDs = Set(stored.compactMap(UUID.init(uuidString:)))
    }

    func markHeard(_ entry: DailyEntry) {
        guard !heardEntryIDs.contains(entry.id) else { return }
        heardEntryIDs.insert(entry.id)
        var stored = defaults.stringArray(forKey: Self.key) ?? []
        stored.append(entry.id.uuidString)
        if stored.count > Self.maxStored {
            stored.removeFirst(stored.count - Self.maxStored)
        }
        defaults.set(stored, forKey: Self.key)
    }
}
