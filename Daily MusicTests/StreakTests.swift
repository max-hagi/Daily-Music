import Foundation
import Testing
@testable import Daily_Music

struct StreakTests {
    private let calendar = Calendar(identifier: .gregorian)

    /// Noon on a fixed reference day so start-of-day math is deterministic.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 12))!
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
    }

    @Test func emptyHistoryHasNoStreak() {
        let streak = Streak.compute(from: [], calendar: calendar, asOf: now)
        #expect(streak.current == 0)
        #expect(streak.best == 0)
        #expect(!streak.isAliveToday)
    }

    @Test func consecutiveDaysEndingTodayCount() {
        let streak = Streak.compute(from: [day(0), day(-1), day(-2)], calendar: calendar, asOf: now)
        #expect(streak.current == 3)
        #expect(streak.isAliveToday)
    }

    @Test func streakSurvivesUntilEndOfToday() {
        // Checked in yesterday + before, but not yet today: at risk, not broken.
        let streak = Streak.compute(from: [day(-1), day(-2)], calendar: calendar, asOf: now)
        #expect(streak.current == 2)
        #expect(!streak.isAliveToday)
    }

    @Test func fullMissedDayBreaksTheRun() {
        // Last check-in was the day before yesterday → current resets.
        let streak = Streak.compute(from: [day(-2), day(-3)], calendar: calendar, asOf: now)
        #expect(streak.current == 0)
        #expect(streak.best == 2)   // the old run is preserved as best
    }

    @Test func bestKeepsTheLongestHistoricRun() {
        // A 4-day run last month, a 2-day run ending today.
        let history = [day(-30), day(-31), day(-32), day(-33), day(0), day(-1)]
        let streak = Streak.compute(from: Set(history), calendar: calendar, asOf: now)
        #expect(streak.current == 2)
        #expect(streak.best == 4)
    }

    @Test func timeOfDayWithinCheckInsDoesNotMatter() {
        // Check-ins recorded at arbitrary times still normalize to whole days.
        let lateYesterday = calendar.date(byAdding: .hour, value: 23, to: day(-1))!
        let streak = Streak.compute(from: [day(0), lateYesterday], calendar: calendar, asOf: now)
        #expect(streak.current == 2)
    }

    @Test func milestoneProgressSupportsGoalGradientCopy() {
        let streak = Streak(current: 5, best: 5, isAliveToday: true)
        #expect(streak.nextMilestone == 7)
        #expect(streak.daysToNextMilestone == 2)
        #expect(!streak.isMilestoneToday)
    }

    @Test func milestoneDayIsDetected() {
        let streak = Streak(current: 7, best: 7, isAliveToday: true)
        #expect(streak.isMilestoneToday)
        #expect(Streak.milestoneName(7) == "one week")
    }

    @Test func milestoneNotCelebratedWhileAtRisk() {
        // 7-day count carried from yesterday without today's check-in.
        let streak = Streak(current: 7, best: 7, isAliveToday: false)
        #expect(!streak.isMilestoneToday)
    }
}
