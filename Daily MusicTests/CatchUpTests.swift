import Foundation
import Testing
@testable import Daily_Music

struct CatchUpTests {
    private let calendar = Calendar(identifier: .gregorian)

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 12))!
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
    }

    private func entry(daysAgo: Int) -> DailyEntry {
        DailyEntry(
            id: UUID(), date: day(-daysAgo), title: "Song \(daysAgo)", artist: "Artist",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "1",
            spotifyURI: "spotify:track:1"
        )
    }

    @Test func dropsOnUnopenedDaysCountAsMissed() {
        let missedEntry = entry(daysAgo: 2)
        let heardEntry = entry(daysAgo: 1)
        let missed = CatchUp.missedEntries(
            in: [missedEntry, heardEntry],
            checkInDays: [day(-1)],          // opened yesterday, not 2 days ago
            heardEntryIDs: [],
            calendar: calendar, asOf: now
        )
        #expect(missed.map(\.id) == [missedEntry.id])
    }

    @Test func todayIsNeverMissed() {
        let todays = entry(daysAgo: 0)
        let missed = CatchUp.missedEntries(
            in: [todays], checkInDays: [], heardEntryIDs: [],
            calendar: calendar, asOf: now
        )
        #expect(missed.isEmpty)
    }

    @Test func dropsOlderThanTheWindowAreJustArchive() {
        let old = entry(daysAgo: 8)
        let missed = CatchUp.missedEntries(
            in: [old], checkInDays: [], heardEntryIDs: [],
            calendar: calendar, asOf: now
        )
        #expect(missed.isEmpty)
    }

    @Test func catchingUpClearsTheEntry() {
        let target = entry(daysAgo: 3)
        let missed = CatchUp.missedEntries(
            in: [target], checkInDays: [], heardEntryIDs: [target.id],
            calendar: calendar, asOf: now
        )
        #expect(missed.isEmpty)
    }

    @Test func logPersistsAndRestoresHeardIDs() async {
        let suiteName = "catchup-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let target = entry(daysAgo: 2)
        let log = await CatchUpLog(defaults: defaults)
        await log.markHeard(target)
        await #expect(log.heardEntryIDs.contains(target.id))

        let restored = await CatchUpLog(defaults: defaults)
        await #expect(restored.heardEntryIDs.contains(target.id))
    }
}

struct TodayDropTimelineScheduleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    @Test func fetchedDropRollsOverToPendingShortlyAfterNextMidnight() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 21))!
        let expectedRollover = calendar.date(from: DateComponents(year: 2026, month: 6, day: 13, hour: 0, minute: 5))!

        let schedule = TodayDropTimelineSchedule.loadedDropSchedule(now: now, calendar: calendar)

        #expect(schedule.rollover == expectedRollover)
        #expect(schedule.reloadAfter == expectedRollover.addingTimeInterval(10 * 60))
    }

    @Test func missingDropRetriesSoon() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 13, hour: 0, minute: 5))!

        let retry = TodayDropTimelineSchedule.missingDropRetryDate(now: now)

        #expect(retry == now.addingTimeInterval(15 * 60))
    }
}
