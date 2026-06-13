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

    @Test func dropsWithinWindowNotHeardAreRescuable() {
        let rescuable = entry(daysAgo: 2)
        let heard = entry(daysAgo: 1)
        let missed = CatchUp.missedEntries(
            in: [rescuable, heard],
            heardAt: [heard.id: day(-1)],
            calendar: calendar, asOf: now
        )
        #expect(missed.map(\.id) == [rescuable.id])
    }

    @Test func todayIsNeverMissed() {
        let todays = entry(daysAgo: 0)
        let missed = CatchUp.missedEntries(
            in: [todays], heardAt: [:], calendar: calendar, asOf: now
        )
        #expect(missed.isEmpty)
    }

    @Test func dropsOlderThanTheWindowAreJustArchive() {
        let old = entry(daysAgo: 8)
        let missed = CatchUp.missedEntries(
            in: [old], heardAt: [:], calendar: calendar, asOf: now
        )
        #expect(missed.isEmpty)
    }

    @Test func catchingUpClearsTheEntry() {
        let target = entry(daysAgo: 3)
        let missed = CatchUp.missedEntries(
            in: [target], heardAt: [target.id: day(-1)], calendar: calendar, asOf: now
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

struct ListenStatusTests {
    private let calendar = Calendar(identifier: .gregorian)

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 12))!
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
    }

    @Test func todaysDropNotYetHeardIsUnheard() {
        let status = ListenStatus.of(entryDate: day(0), heardAt: nil, calendar: calendar, asOf: now)
        #expect(status == .unheard)
    }

    @Test func futureDropIsUnheard() {
        let status = ListenStatus.of(entryDate: day(1), heardAt: nil, calendar: calendar, asOf: now)
        #expect(status == .unheard)
    }

    @Test func heardOnItsOwnDayIsHeardSameDay() {
        let status = ListenStatus.of(entryDate: day(-2), heardAt: day(-2), calendar: calendar, asOf: now)
        #expect(status == .heardSameDay)
    }

    @Test func heardLaterIsCaughtUp() {
        // Dropped 5 days ago, heard 2 days ago.
        let status = ListenStatus.of(entryDate: day(-5), heardAt: day(-2), calendar: calendar, asOf: now)
        #expect(status == .caughtUp)
    }

    @Test func missedButStillInsideWindowIsRescuable() {
        let status = ListenStatus.of(entryDate: day(-3), heardAt: nil, calendar: calendar, asOf: now)
        #expect(status == .rescuable)
    }

    @Test func atWindowEdgeIsStillRescuable() {
        // Exactly windowDays (7) old, never heard → still rescuable, not missed.
        let status = ListenStatus.of(entryDate: day(-7), heardAt: nil, calendar: calendar, asOf: now)
        #expect(status == .rescuable)
    }

    @Test func pastTheWindowNeverHeardIsMissed() {
        let status = ListenStatus.of(entryDate: day(-8), heardAt: nil, calendar: calendar, asOf: now)
        #expect(status == .missed)
    }

    @Test func daysLateIsTheGapBetweenDropAndListen() {
        #expect(ListenStatus.daysLate(entryDate: day(-5), heardAt: day(-2), calendar: calendar) == 3)
        #expect(ListenStatus.daysLate(entryDate: day(-2), heardAt: day(-2), calendar: calendar) == 0)
    }
}

struct ListensServiceTests {
    private func makeEntryID() -> UUID { UUID() }

    @Test func markingHeardRecordsTheEntry() async throws {
        let service = MockListensService()
        let id = makeEntryID()
        try await service.markHeard(entryID: id)
        let heard = try await service.heardEntries()
        #expect(heard[id] != nil)
    }

    @Test func firstListenWinsSoHeardAtIsNeverOverwritten() async throws {
        let service = MockListensService()
        let id = makeEntryID()
        try await service.markHeard(entryID: id)
        let first = try await service.heardEntries()[id]
        try await Task.sleep(for: .milliseconds(10))
        try await service.markHeard(entryID: id)   // second mark must be ignored
        let second = try await service.heardEntries()[id]
        #expect(first == second)
    }
}

@MainActor
struct ListensStoreTests {
    private func entry(_ id: UUID = UUID(), date: Date = Date()) -> DailyEntry {
        DailyEntry(id: id, date: date, title: "Song", artist: "Artist",
                   albumArtURL: nil, journalMarkdown: "", appleMusicID: "1",
                   spotifyURI: "spotify:track:1")
    }

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "listens-tests-\(UUID().uuidString)")!
    }

    @Test func markingHeardUpdatesStateAndCount() async {
        let store = ListensStore(service: MockListensService(), defaults: freshDefaults())
        let e = entry()
        store.markHeard(e)
        #expect(store.isHeard(e))
        #expect(store.collectionCount == 1)
    }

    @Test func markHeardIsIdempotent() async {
        let store = ListensStore(service: MockListensService(), defaults: freshDefaults())
        let e = entry()
        store.markHeard(e)
        let first = store.heardAt[e.id]
        store.markHeard(e)
        #expect(store.heardAt[e.id] == first)
        #expect(store.collectionCount == 1)
    }

    @Test func cachePersistsAcrossInstances() async {
        let defaults = freshDefaults()
        let e = entry()
        let store = ListensStore(service: MockListensService(), defaults: defaults)
        store.markHeard(e)
        let restored = ListensStore(service: MockListensService(), defaults: defaults)
        #expect(restored.isHeard(e))
    }

    @Test func legacyHeardIDsAreMigratedOnce() async {
        let defaults = freshDefaults()
        let legacyID = UUID()
        defaults.set([legacyID.uuidString], forKey: "vault.heardEntryIDs")
        let store = ListensStore(service: MockListensService(), defaults: defaults)
        #expect(store.heardAt[legacyID] != nil)
    }

    @Test func loadMergesServerRowsKeepingEarliest() async {
        let defaults = freshDefaults()
        let e = entry()
        let service = MockListensService()
        try? await service.markHeard(entryID: e.id)   // server has a row
        let store = ListensStore(service: service, defaults: defaults)
        await store.load()
        #expect(store.isHeard(e))
    }
}
