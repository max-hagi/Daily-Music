//
//  StreakFlare.swift
//  Daily Music
//
//  Pure guard for the once-a-day streak flare: fire when today's check-in first
//  makes the streak alive, and not again until a new day. Mirrors the milestone
//  celebration guard so re-opening the app the same day never replays it.
//

import Foundation

enum StreakFlare {
    static func shouldFlare(
        lastFlareDay: Date?,
        isAliveToday: Bool,
        calendar: Calendar = .current,
        asOf now: Date = Date()
    ) -> Bool {
        guard isAliveToday else { return false }
        guard let lastFlareDay else { return true }
        return !calendar.isDate(lastFlareDay, inSameDayAs: now)
    }
}
