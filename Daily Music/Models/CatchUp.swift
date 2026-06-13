//
//  CatchUp.swift
//  Daily Music
//
//  The "missed drops" rule, shared by the Vault hero and the Vault tab badge.
//  A drop is "rescuable" (surfaced as missed) when it's inside the catch-up
//  window and the user hasn't heard it yet; hearing it clears it. Derived from
//  ListenStatus so listen state has a single source of truth.
//

import Foundation

enum CatchUp {
    /// How far back a drop still "counts" as missed. Older ones are just archive.
    static let windowDays = 7

    /// Entries still rescuable: missed but inside the window. Drives the Vault
    /// hero and tab badge. Derived from ListenStatus, so an entry clears the
    /// moment it's heard (rescuable → caughtUp). Note: opening the app without
    /// listening no longer clears it — only an actual listen does.
    static func missedEntries(
        in entries: [DailyEntry],
        heardAt: [UUID: Date],
        calendar: Calendar = .current,
        asOf now: Date = Date()
    ) -> [DailyEntry] {
        entries.filter {
            ListenStatus.of(entryDate: $0.date, heardAt: heardAt[$0.id],
                            calendar: calendar, asOf: now) == .rescuable
        }
    }
}
