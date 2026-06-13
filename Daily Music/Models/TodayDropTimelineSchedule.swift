//
//  TodayDropTimelineSchedule.swift
//  Daily Music
//
//  Pure date math for the Today widget timeline. The widget itself fetches data;
//  this helper only decides when stale content should roll over and retry.
//

import Foundation

struct TodayDropTimelineSchedule {
    let rollover: Date
    let reloadAfter: Date

    static let rolloverDelay: TimeInterval = 5 * 60
    static let reloadDelayAfterRollover: TimeInterval = 10 * 60
    static let missingDropRetryDelay: TimeInterval = 15 * 60

    static func loadedDropSchedule(now: Date, calendar: Calendar = .current) -> TodayDropTimelineSchedule {
        let startOfToday = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday)
        let rollover = (nextMidnight ?? now.addingTimeInterval(86_400)).addingTimeInterval(rolloverDelay)

        return TodayDropTimelineSchedule(
            rollover: rollover,
            reloadAfter: rollover.addingTimeInterval(reloadDelayAfterRollover)
        )
    }

    static func missingDropRetryDate(now: Date) -> Date {
        now.addingTimeInterval(missingDropRetryDelay)
    }
}
