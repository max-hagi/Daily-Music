//
//  CheckInService.swift
//  Daily Music
//
//  Records one "check-in" per day the user opens the daily song, which is what
//  the streak counts. v1 ships a mock with a few seeded days; the live version
//  (SupabaseCheckInService) writes to the `check_ins` table.
//

import Foundation

protocol CheckInService {
    /// Idempotently record that the user opened today's song.
    func recordToday() async throws
    /// All days (start-of-day) the user has checked in.
    func checkInDates() async throws -> Set<Date>
}

/// In-memory stand-in seeded with a 3-day streak ending today, so the Insights
/// screen shows something meaningful without a backend.
actor MockCheckInService: CheckInService {
    private var days: Set<Date>

    init() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        days = [
            today,
            cal.date(byAdding: .day, value: -1, to: today)!,
            cal.date(byAdding: .day, value: -2, to: today)!,
        ]
    }

    func recordToday() async throws {
        days.insert(Calendar.current.startOfDay(for: Date()))
    }

    func checkInDates() async throws -> Set<Date> { days }
}
