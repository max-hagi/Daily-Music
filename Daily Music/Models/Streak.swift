//
//  Streak.swift
//  Daily Music
//
//  Pure streak math, kept separate from any view or service so it's trivial to
//  reason about and test. "Current streak" = the run of consecutive days ending
//  today (or yesterday, if today's song hasn't been opened yet — so an active
//  streak still shows until the day lapses).
//

import Foundation

enum Streak {
    static func current(
        from checkInDays: Set<Date>,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let startOfToday = calendar.startOfDay(for: today)
        let days = Set(checkInDays.map { calendar.startOfDay(for: $0) })

        // Anchor at today if checked in today, otherwise yesterday.
        var cursor: Date
        if days.contains(startOfToday) {
            cursor = startOfToday
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
                  days.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
