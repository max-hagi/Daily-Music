//
//  Streak.swift
//  Daily Music
//
//  The daily-ritual streak, computed from check-in days. Designed around the
//  retention psychology that makes streaks actually work:
//  - LOSS AVERSION: a visible current streak is something to protect.
//  - GOAL GRADIENT: progress toward a named milestone ("2 days to one week")
//    motivates more than a bare counter.
//  - ABSTINENCE-VIOLATION MITIGATION: `best` is preserved forever, so a broken
//    streak never erases the user's identity as a daily listener — the known
//    failure mode where one missed day turns into churn.
//
//  A streak is "alive" until the END of the day after the last check-in: if you
//  listened yesterday but not yet today, the streak still counts (and today's
//  open extends it). Only a full missed day breaks it.
//

import Foundation

struct Streak: Equatable {
    /// Consecutive days ending today (or yesterday, if today's check-in hasn't
    /// happened yet — the streak is "at risk" but not broken).
    var current: Int
    /// The longest run ever recorded. Never decreases when a streak breaks.
    var best: Int
    /// True once today's check-in is recorded.
    var isAliveToday: Bool

    /// Milestone days, named so copy can celebrate them (goal-gradient targets).
    static let milestones: [Int] = [3, 7, 14, 30, 50, 100, 200, 365]

    /// The next milestone ahead of the current streak, nil past the last one.
    var nextMilestone: Int? {
        Self.milestones.first { $0 > current }
    }

    /// Days remaining until the next milestone (nil when past all milestones).
    var daysToNextMilestone: Int? {
        nextMilestone.map { $0 - current }
    }

    /// True on the exact day a milestone is reached — the moment to celebrate.
    var isMilestoneToday: Bool {
        isAliveToday && Self.milestones.contains(current)
    }

    /// Human label for a milestone day count ("one week", "one month", …).
    static func milestoneName(_ days: Int) -> String {
        switch days {
        case 3: "3-day spark"
        case 7: "one week"
        case 14: "two weeks"
        case 30: "one month"
        case 50: "50 days"
        case 100: "100 days"
        case 200: "200 days"
        case 365: "one year"
        default: "\(days) days"
        }
    }

    static func compute(
        from checkInDays: Set<Date>,
        calendar: Calendar = .current,
        asOf now: Date = Date()
    ) -> Streak {
        // Normalize every check-in to start-of-day so comparisons are exact.
        let days = Set(checkInDays.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        let isAliveToday = days.contains(today)

        // Current run: walk backwards from today (or yesterday when today is
        // still pending) counting consecutive days.
        var current = 0
        var cursor = isAliveToday
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        while days.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        // Best run anywhere in history: scan the sorted days once.
        var best = 0
        var run = 0
        var previousDay: Date?
        for day in days.sorted() {
            if let previousDay,
               let expected = calendar.date(byAdding: .day, value: 1, to: previousDay),
               calendar.isDate(day, inSameDayAs: expected) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previousDay = day
        }

        return Streak(current: current, best: best, isAliveToday: isAliveToday)
    }
}
