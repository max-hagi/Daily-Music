//
//  SharedStreak.swift
//  Daily Music
//
//  Publishes the current streak to the App Group so the widget can show the
//  flame. The widget never computes streaks (check_ins lives behind auth) —
//  it just reads this snapshot and hides the flame once it can no longer be
//  trusted (an unopened day past the grace window means the streak may have
//  broken while the app was closed).
//

import Foundation
import WidgetKit

enum SharedStreak {
    static let suiteName = "group.maxhagi.Daily-Music"
    static let currentKey = "shared.streak.current"
    /// Last day (yyyy-MM-dd) the streak can still be extended — the day after
    /// the last counted check-in. Past it, the widget hides the flame.
    static let validThroughKey = "shared.streak.validThrough"

    static func publish(_ streak: Streak, calendar: Calendar = .current, asOf now: Date = Date()) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        let today = calendar.startOfDay(for: now)
        let lastCounted = streak.isAliveToday
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let validThrough = calendar.date(byAdding: .day, value: 1, to: lastCounted) ?? lastCounted

        defaults.set(streak.current, forKey: currentKey)
        defaults.set(Self.dayString(validThrough), forKey: validThroughKey)

        WidgetCenter.shared.reloadTimelines(ofKind: "TodayDropWidget")
    }

    static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
