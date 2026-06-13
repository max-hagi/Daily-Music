//
//  ListenStatus.swift
//  Daily Music
//
//  Derived display state for a drop, from (drop date, when it was heard, now).
//  Literal in code; the record-shop vocabulary lives only in these comments and
//  the UI layer. Sibling to CatchUp so the catch-up window constant is shared.
//

import Foundation

enum ListenStatus: Equatable {
    case unheard       // today's (or future) drop, not played yet   → art: "pending"
    case heardSameDay  // played on its own day                       → art: "mint"
    case caughtUp      // played late, inside the catch-up window      → art: "secondhand"
    case rescuable     // missed but still inside the window           → art: "still available"
    case missed        // window closed, never played                 → art: "missing"
}

extension ListenStatus {
    /// Single source of truth. `heardAt` is the EARLIEST listen (first-listen-wins),
    /// so the same-day vs late decision is stable.
    static func of(
        entryDate: Date,
        heardAt: Date?,
        windowDays: Int = CatchUp.windowDays,
        calendar: Calendar = .current,
        asOf now: Date = Date()
    ) -> ListenStatus {
        let entryDay = calendar.startOfDay(for: entryDate)
        let today = calendar.startOfDay(for: now)

        if let heardAt {
            let heardDay = calendar.startOfDay(for: heardAt)
            return heardDay <= entryDay ? .heardSameDay : .caughtUp
        }
        if entryDay >= today { return .unheard }
        let daysOld = calendar.dateComponents([.day], from: entryDay, to: today).day ?? 0
        return daysOld <= windowDays ? .rescuable : .missed
    }

    /// Days between the drop's day and when it was caught up. 0 for same-day.
    static func daysLate(
        entryDate: Date,
        heardAt: Date,
        calendar: Calendar = .current
    ) -> Int {
        let entryDay = calendar.startOfDay(for: entryDate)
        let heardDay = calendar.startOfDay(for: heardAt)
        return max(0, calendar.dateComponents([.day], from: entryDay, to: heardDay).day ?? 0)
    }
}
