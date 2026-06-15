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

    @Test func todaysDropHeardTodayIsHeardSameDay() {
        // Today's drop, played today → mint. Guards the same-day `<=` boundary the
        // spec's mint rule calls out (today's same-day listen counts as full credit).
        let status = ListenStatus.of(entryDate: day(0), heardAt: day(0), calendar: calendar, asOf: now)
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

struct SleeveTreatmentTests {
    // The sleeve renders 4 treatments (§10.3); ListenStatus has 5 cases. This is
    // the collapse: the two "invitation" states both render pending.

    @Test func todaysUnheardDropIsPending() {
        #expect(SleeveTreatment(.unheard) == .pending)
    }

    @Test func rescuableRendersAsPendingNotAGap() {
        // Spec §1: still inside the window → pending-styled "still available",
        // never an empty/missing sleeve.
        #expect(SleeveTreatment(.rescuable) == .pending)
    }

    @Test func heardSameDayIsMint() {
        #expect(SleeveTreatment(.heardSameDay) == .mint)
    }

    @Test func caughtUpIsSecondhand() {
        #expect(SleeveTreatment(.caughtUp) == .secondhand)
    }

    @Test func missedIsMissing() {
        #expect(SleeveTreatment(.missed) == .missing)
    }
}

struct VariantConfigTests {
    @Test func defaultsMatchLockedPicks() {
        // Guards the shipped product decision (spec §11 defaults + the user's
        // one change: moment = playful). Changing a default must break this.
        let c = VariantConfig()
        #expect(c.missingSleeve == .blank)
        #expect(c.secondhand == .wornCornerStamp)
        #expect(c.crateFeel == .centerTilt)
        #expect(c.momentTiming == .playful)
    }
}

struct CrateLayoutTests {
    @Test func countLabelPluralisesAndShowsMonth() {
        #expect(CrateLayout.collectionCountLabel(total: 3, thisMonth: 3) == "3 records · 3 this month")
    }

    @Test func countLabelSingularRecord() {
        #expect(CrateLayout.collectionCountLabel(total: 1, thisMonth: 1) == "1 record · 1 this month")
    }

    @Test func countLabelDropsMonthClauseWhenZero() {
        #expect(CrateLayout.collectionCountLabel(total: 5, thisMonth: 0) == "5 records")
    }

    @Test func countLabelHandlesEmptyCollection() {
        #expect(CrateLayout.collectionCountLabel(total: 0, thisMonth: 0) == "0 records")
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

    @Test func collectedThisMonthCountsOnlyThisMonth() async {
        let store = ListensStore(service: MockListensService(), defaults: freshDefaults())
        store.markHeard(entry())
        store.markHeard(entry())
        #expect(store.collectedThisMonth() == 2)
        #expect(store.collectedThisMonth(asOf: .distantFuture) == 0)
    }
}

struct CrateMonthSectionTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func entry(_ y: Int, _ m: Int, _ d: Int) -> DailyEntry {
        let date = calendar.date(from: DateComponents(year: y, month: m, day: d))!
        return DailyEntry(id: UUID(), date: date, title: "S", artist: "A",
                          albumArtURL: nil, journalMarkdown: "", appleMusicID: "1",
                          spotifyURI: "spotify:track:1")
    }

    @Test func groupsEntriesByMonthNewestFirst() {
        let jun2 = entry(2026, 6, 2)
        let jun20 = entry(2026, 6, 20)
        let may = entry(2026, 5, 9)
        let sections = CrateLayout.monthSections(
            for: [jun20, jun2, may], calendar: calendar   // already newest-first
        )
        #expect(sections.count == 2)
        #expect(sections[0].entries.map(\.id) == [jun20.id, jun2.id])  // June, newest-first
        #expect(sections[1].entries.map(\.id) == [may.id])             // then May
    }

    @Test func monthSectionTitleIsMonthAndYear() {
        let sections = CrateLayout.monthSections(for: [entry(2026, 6, 2)], calendar: calendar)
        #expect(sections[0].title == "June 2026")
    }

    @Test func emptyInputYieldsNoSections() {
        #expect(CrateLayout.monthSections(for: [], calendar: calendar).isEmpty)
    }
}

struct VaultNudgeTests {
    private let calendar = Calendar(identifier: .gregorian)
    private func month(_ y: Int, _ m: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: 1))!
    }

    @Test func rescuableTakesTopPriority() {
        let line = VaultNudge.line(
            total: 47, rescuable: 2, collectedToday: true,
            daysToNextMilestone: 1, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "2 waiting to be rescued")
    }

    @Test func rescuableSingularGrammar() {
        let line = VaultNudge.line(
            total: 47, rescuable: 1, collectedToday: false,
            daysToNextMilestone: nil, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "1 waiting to be rescued")
    }

    @Test func milestoneProximityWhenNothingRescuable() {
        let line = VaultNudge.line(
            total: 47, rescuable: 0, collectedToday: true,
            daysToNextMilestone: 2, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "2 days to your next pressing")
    }

    @Test func milestoneProximitySingularDay() {
        let line = VaultNudge.line(
            total: 47, rescuable: 0, collectedToday: true,
            daysToNextMilestone: 1, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "1 day to your next pressing")
    }

    @Test func defaultIsCountAndProvenance() {
        let line = VaultNudge.line(
            total: 47, rescuable: 0, collectedToday: false,
            daysToNextMilestone: nil, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "47 records · started April 2026")
    }

    @Test func defaultSingularRecordNoProvenanceWhenStartUnknown() {
        let line = VaultNudge.line(
            total: 1, rescuable: 0, collectedToday: false,
            daysToNextMilestone: nil, startedMonth: nil, calendar: calendar
        )
        #expect(line == "1 record")
    }

    @Test func milestoneProximityIgnoredWhenNotCollectedToday() {
        // Only nudge toward the next pressing on a day you've collected — otherwise
        // fall through to the default count line.
        let line = VaultNudge.line(
            total: 47, rescuable: 0, collectedToday: false,
            daysToNextMilestone: 2, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "47 records · started April 2026")
    }
}
