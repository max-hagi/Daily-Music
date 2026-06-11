//
//  ReminderCopy.swift
//  Daily Music
//
//  Copy for the daily reminder notifications. Identical daily notifications
//  train people to swipe them away within a week, so the copy rotates through
//  a curiosity-driven pool (the "variable reward" half of the habit loop — the
//  song is unknown until you open). The very next reminder can additionally
//  carry the user's streak ("12-day streak on the line"), the loss-aversion
//  nudge — but ONLY the next one, because a streak number baked into a
//  notification scheduled days ahead would be stale by the time it fires.
//

import Foundation

enum ReminderCopy {
    struct Content: Equatable {
        let title: String
        let body: String
    }

    /// Rotating pool. Voice: short, curious, never guilt-trippy.
    static let pool: [Content] = [
        Content(title: "Today's song is ready",
                body: "Your daily track and journal entry are waiting."),
        Content(title: "A new song just dropped",
                body: "One song, one story — see what today brought."),
        Content(title: "What's playing today?",
                body: "Today's hand-picked track is live. Have a listen."),
        Content(title: "Your daily discovery is here",
                body: "A song you (probably) haven't heard, picked for today."),
        Content(title: "One song, once a day",
                body: "Today's drop won't repeat. Hear it while it's live."),
        Content(title: "Today's story is waiting",
                body: "A track and the story behind it, ready now."),
        Content(title: "Press play on today",
                body: "Your song of the day just landed."),
    ]

    /// Copy for the reminder that fires on `date`.
    /// - Parameters:
    ///   - isNextReminder: true only for the soonest scheduled reminder — the
    ///     only one whose streak number is guaranteed fresh.
    ///   - streak: the user's current streak when scheduling, if known.
    static func content(
        for date: Date,
        isNextReminder: Bool,
        streak: Int?,
        calendar: Calendar = .current
    ) -> Content {
        if isNextReminder, let streak, streak >= 2 {
            return Content(
                title: "Your \(streak)-day streak is on the line",
                body: "Today's song is ready — keep the run alive."
            )
        }
        // Deterministic rotation keyed by the fire date, so re-scheduling on
        // every app open doesn't shuffle the copy users will actually see.
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        return pool[dayOfYear % pool.count]
    }
}
