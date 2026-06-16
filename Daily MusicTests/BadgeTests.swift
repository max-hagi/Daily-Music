//
//  BadgeTests.swift
//  Daily MusicTests
//
//  All unit tests for the Insights badge system: tier math, derivation, the
//  seen-store diff, and summary building.
//

import Foundation
import SwiftUI
import Testing
@testable import Daily_Music

struct BadgeTests {
    // MARK: - Tier math

    @Test func tierProgressBelowFirstThreshold() {
        let p = BadgeMath.tierProgress(value: 2, thresholds: [3, 7, 14])
        #expect(p.unlockedTier == 0)
        #expect(p.nextThreshold == 3)
        #expect(!p.isEarned)
        #expect(abs(p.progressToNext - (2.0 / 3.0)) < 0.0001)
    }

    @Test func tierProgressExactlyOnThreshold() {
        let p = BadgeMath.tierProgress(value: 7, thresholds: [3, 7, 14])
        #expect(p.unlockedTier == 2)
        #expect(p.nextThreshold == 14)
        #expect(abs(p.progressToNext - 0.0) < 0.0001) // at the floor of tier 3
    }

    @Test func tierProgressBetweenThresholds() {
        let p = BadgeMath.tierProgress(value: 10, thresholds: [3, 7, 14])
        #expect(p.unlockedTier == 2)
        #expect(p.nextThreshold == 14)
        // floor 7, span 7, value 10 → 3/7
        #expect(abs(p.progressToNext - (3.0 / 7.0)) < 0.0001)
    }

    @Test func tierProgressPastMax() {
        let p = BadgeMath.tierProgress(value: 99, thresholds: [3, 7, 14])
        #expect(p.unlockedTier == 3)
        #expect(p.nextThreshold == nil)
        #expect(p.isMaxed)
        #expect(p.progressToNext == 1.0)
    }

    // MARK: - Catalogue

    @Test func catalogueHasSixTieredAndSixMoments() {
        #expect(BadgeCatalog.tiered.count == 6)
        #expect(BadgeCatalog.moments.count == 6)
        #expect(BadgeCatalog.all.count == 12)
    }

    @Test func catalogueIDsAreUnique() {
        let ids = BadgeCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func tieredBadgesAreTieredAndMomentsAreMoments() {
        for def in BadgeCatalog.tiered {
            if case .tiered = def.kind {} else { Issue.record("\(def.id) not tiered") }
        }
        for def in BadgeCatalog.moments {
            #expect(def.kind == .moment)
        }
    }

    // MARK: - Deriver fixtures

    private static let cal = Calendar(identifier: .gregorian)
    private static var refNow: Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 12))!
    }
    private static func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: refNow))!
    }
    private static func entry(_ id: UUID = UUID(), daysAgo: Int, genre: String? = nil) -> DailyEntry {
        DailyEntry(
            id: id, date: day(-daysAgo), title: "T", artist: "A",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "", spotifyURI: "",
            genre: genre)
    }

    // MARK: - Deriver: tiered values

    @Test func mintCountsSameDayListensOnly() {
        let e1 = UUID(); let e2 = UUID(); let e3 = UUID()
        let inputs = BadgeInputs(
            entries: [
                Self.entry(e1, daysAgo: 0),   // heard same day → mint
                Self.entry(e2, daysAgo: 5),   // heard late → not mint
                Self.entry(e3, daysAgo: 2),   // never heard → not mint
            ],
            heardAt: [e1: Self.day(0), e2: Self.day(0)], // e2 heard today, 5 days late
            favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
            now: Self.refNow, calendar: Self.cal)

        let badges = BadgeDeriver().deriveAll(from: inputs)
        let mint = badges.first { $0.id == "mint" }!
        #expect(mint.value == 1)
    }

    @Test func crateCountsAllHeard() {
        let e1 = UUID(); let e2 = UUID()
        let inputs = BadgeInputs(
            entries: [], heardAt: [e1: Self.day(-1), e2: Self.day(-2)],
            favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
            now: Self.refNow, calendar: Self.cal)
        let crate = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "crate" }!
        #expect(crate.value == 2)
    }

    @Test func savedCountsFavorites() {
        let inputs = BadgeInputs(
            entries: [], heardAt: [:], favoriteIDs: [UUID(), UUID(), UUID()],
            ratings: [:], checkInDays: [], hasRevealedArchetype: false,
            now: Self.refNow, calendar: Self.cal)
        let saved = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "saved" }!
        #expect(saved.value == 3)
    }

    @Test func criticCountsNonZeroRatings() {
        let inputs = BadgeInputs(
            entries: [], heardAt: [:], favoriteIDs: [],
            ratings: [UUID(): 1, UUID(): -1, UUID(): 0],
            checkInDays: [], hasRevealedArchetype: false,
            now: Self.refNow, calendar: Self.cal)
        let critic = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "critic" }!
        #expect(critic.value == 2)
    }

    @Test func rescuerCountsRescuedListens() {
        let e1 = UUID()
        // Drop 40 days ago, heard today → past the catch-up window → .rescued
        let inputs = BadgeInputs(
            entries: [Self.entry(e1, daysAgo: 40)],
            heardAt: [e1: Self.day(0)],
            favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
            now: Self.refNow, calendar: Self.cal)
        let rescuer = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "rescuer" }!
        #expect(rescuer.value == 1)
    }

    @Test func streakUsesBestRun() {
        let inputs = BadgeInputs(
            entries: [], heardAt: [:], favoriteIDs: [], ratings: [:],
            checkInDays: [Self.day(0), Self.day(-1), Self.day(-2)],
            hasRevealedArchetype: false, now: Self.refNow, calendar: Self.cal)
        let streak = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "streak" }!
        #expect(streak.value == 3)
        #expect(streak.tier?.unlockedTier == 1) // met threshold 3
    }

    @Test func tieredBadgeCarriesTierProgress() {
        let inputs = BadgeInputs(
            entries: [], heardAt: [:], favoriteIDs: Set((0..<6).map { _ in UUID() }),
            ratings: [:], checkInDays: [], hasRevealedArchetype: false,
            now: Self.refNow, calendar: Self.cal)
        let saved = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "saved" }!
        #expect(saved.value == 6)
        #expect(saved.tier?.unlockedTier == 1)        // met 5
        #expect(saved.tier?.nextThreshold == 25)
        #expect(saved.isEarned)
    }

    // MARK: - Deriver: moments

    private static func mintInputs(daysAgo: [Int], checkIns: Set<Date> = [], reveal: Bool = false,
                                   heardOverride: [Int: Int] = [:]) -> BadgeInputs {
        // Each entry dropped `daysAgo` is heard same-day unless overridden via
        // heardOverride[daysAgo] = listenDaysAgo.
        var entries: [DailyEntry] = []
        var heardAt: [UUID: Date] = [:]
        for d in daysAgo {
            let id = UUID()
            entries.append(BadgeTests.entry(id, daysAgo: d))
            let listen = heardOverride[d] ?? d
            heardAt[id] = BadgeTests.day(-listen)
        }
        return BadgeInputs(
            entries: entries, heardAt: heardAt, favoriteIDs: [], ratings: [:],
            checkInDays: checkIns, hasRevealedArchetype: reveal,
            now: BadgeTests.refNow, calendar: BadgeTests.cal)
    }

    @Test func firstPressEarnedWithOneMint() {
        let badges = BadgeDeriver().deriveAll(from: Self.mintInputs(daysAgo: [1]))
        #expect(badges.first { $0.id == "firstPress" }!.isEarned)
    }

    @Test func firstPressNotEarnedWithNoMint() {
        let badges = BadgeDeriver().deriveAll(from: Self.mintInputs(daysAgo: []))
        #expect(!(badges.first { $0.id == "firstPress" }!.isEarned))
    }

    @Test func perfectWeekNeedsSevenConsecutiveSameDay() {
        let seven = BadgeDeriver().deriveAll(from: Self.mintInputs(daysAgo: Array(0...6)))
        #expect(seven.first { $0.id == "perfectWeek" }!.isEarned)

        let six = BadgeDeriver().deriveAll(from: Self.mintInputs(daysAgo: Array(0...5)))
        #expect(!(six.first { $0.id == "perfectWeek" }!.isEarned))
    }

    @Test func perfectWeekBrokenByAGap() {
        // 0,1,2,3,4,5 then skip 6, then 7 → longest run of mint days is 6, not 7
        let badges = BadgeDeriver().deriveAll(from: Self.mintInputs(daysAgo: [0,1,2,3,4,5,7]))
        #expect(!(badges.first { $0.id == "perfectWeek" }!.isEarned))
    }

    @Test func comebackNeedsAWeekRunAfterAnEarlierBreak() {
        // Earlier short run (days -20,-19), gap, then a fresh 7-day run ending today.
        let recent = (0...6).map { Self.day(-$0) }
        let earlier = [Self.day(-20), Self.day(-19)]
        let inputs = BadgeInputs(
            entries: [], heardAt: [:], favoriteIDs: [], ratings: [:],
            checkInDays: Set(recent + earlier), hasRevealedArchetype: false,
            now: Self.refNow, calendar: Self.cal)
        #expect(BadgeDeriver().deriveAll(from: inputs).first { $0.id == "comeback" }!.isEarned)
    }

    @Test func comebackNotEarnedForAFirstUnbrokenRun() {
        let inputs = BadgeInputs(
            entries: [], heardAt: [:], favoriteIDs: [], ratings: [:],
            checkInDays: Set((0...9).map { Self.day(-$0) }), // one long first run, no earlier break
            hasRevealedArchetype: false, now: Self.refNow, calendar: Self.cal)
        #expect(!(BadgeDeriver().deriveAll(from: inputs).first { $0.id == "comeback" }!.isEarned))
    }

    @Test func nightOwlEarnedForAfterMidnightListen() {
        let e = UUID()
        let lateNight = Self.cal.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 1))!
        let inputs = BadgeInputs(
            entries: [Self.entry(e, daysAgo: 6)], heardAt: [e: lateNight],
            favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
            now: Self.refNow, calendar: Self.cal)
        #expect(BadgeDeriver().deriveAll(from: inputs).first { $0.id == "nightOwl" }!.isEarned)
    }

    @Test func flawlessMonthEarnedWhenAPastMonthHasNoMisses() {
        // May 2026: two drops, both heard same day → no misses in a completed month.
        let e1 = UUID(); let e2 = UUID()
        let may1 = Self.cal.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 12))!
        let may2 = Self.cal.date(from: DateComponents(year: 2026, month: 5, day: 18, hour: 12))!
        let mkEntry: (UUID, Date) -> DailyEntry = { id, d in
            DailyEntry(id: id, date: d, title: "T", artist: "A", albumArtURL: nil,
                       journalMarkdown: "", appleMusicID: "", spotifyURI: "")
        }
        let inputs = BadgeInputs(
            entries: [mkEntry(e1, may1), mkEntry(e2, may2)],
            heardAt: [e1: may1, e2: may2],
            favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
            now: Self.refNow, calendar: Self.cal)
        #expect(BadgeDeriver().deriveAll(from: inputs).first { $0.id == "flawlessMonth" }!.isEarned)
    }

    @Test func flawlessMonthNotEarnedWithAMiss() {
        let e1 = UUID(); let e2 = UUID()
        let may1 = Self.cal.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 12))!
        let may2 = Self.cal.date(from: DateComponents(year: 2026, month: 5, day: 18, hour: 12))!
        let mkEntry: (UUID, Date) -> DailyEntry = { id, d in
            DailyEntry(id: id, date: d, title: "T", artist: "A", albumArtURL: nil,
                       journalMarkdown: "", appleMusicID: "", spotifyURI: "")
        }
        let inputs = BadgeInputs(
            entries: [mkEntry(e1, may1), mkEntry(e2, may2)],
            heardAt: [e1: may1], // e2 never heard → missed
            favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
            now: Self.refNow, calendar: Self.cal)
        #expect(!(BadgeDeriver().deriveAll(from: inputs).first { $0.id == "flawlessMonth" }!.isEarned))
    }

    @Test func flawlessMonthDefersWhileAPriorMonthDropIsStillRescuable() {
        // Viewed from July 2: a June 28 drop, unheard, is 4 days old → within the
        // 7-day window → .rescuable. June must NOT yet count as flawless.
        let now = Self.cal.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 12))!
        let e = UUID()
        let june28 = Self.cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 12))!
        let entry = DailyEntry(id: e, date: june28, title: "T", artist: "A", albumArtURL: nil,
                               journalMarkdown: "", appleMusicID: "", spotifyURI: "")
        let inputs = BadgeInputs(
            entries: [entry], heardAt: [:], favoriteIDs: [], ratings: [:], checkInDays: [],
            hasRevealedArchetype: false, now: now, calendar: Self.cal)
        #expect(!(BadgeDeriver().deriveAll(from: inputs).first { $0.id == "flawlessMonth" }!.isEarned))
    }

    @Test func revealedTracksFlag() {
        let on = Self.mintInputs(daysAgo: [], reveal: true)
        #expect(BadgeDeriver().deriveAll(from: on).first { $0.id == "revealed" }!.isEarned)
        let off = Self.mintInputs(daysAgo: [], reveal: false)
        #expect(!(BadgeDeriver().deriveAll(from: off).first { $0.id == "revealed" }!.isEarned))
    }

    // MARK: - Seen store

    private static func suiteDefaults() -> UserDefaults {
        let name = "badge.tests.\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    private static func earned(_ id: String, tier: Int?) -> EarnedBadge {
        let def = BadgeDefinition(id: id, title: id, subtitle: "", symbol: "", tint: .gray,
                                  kind: tier == nil ? .moment : .tiered(thresholds: [1]))
        let progress = tier.map { TierProgress(unlockedTier: $0, nextThreshold: nil, progressToNext: 1) }
        return EarnedBadge(definition: def, value: tier ?? 1, isEarned: true, tier: progress)
    }

    @Test func firstLoadBaselinesWithoutCelebrating() {
        let store = BadgeSeenStore(defaults: Self.suiteDefaults())
        let newly = store.newlyEarned(in: [Self.earned("mint", tier: 2)])
        #expect(newly.isEmpty) // baseline run never celebrates pre-existing badges
    }

    @Test func laterEarnsAreReportedOnce() {
        let defaults = Self.suiteDefaults()
        let store = BadgeSeenStore(defaults: defaults)
        _ = store.newlyEarned(in: [Self.earned("mint", tier: 1)]) // baseline

        let newly = store.newlyEarned(in: [Self.earned("mint", tier: 1), Self.earned("crate", tier: 1)])
        #expect(newly.map(\.id) == ["crate"])

        store.markSeen(newly.map(\.seenKey))
        let after = store.newlyEarned(in: [Self.earned("mint", tier: 1), Self.earned("crate", tier: 1)])
        #expect(after.isEmpty)
    }

    @Test func higherTierCelebratesAgain() {
        let defaults = Self.suiteDefaults()
        let store = BadgeSeenStore(defaults: defaults)
        _ = store.newlyEarned(in: [Self.earned("mint", tier: 1)]) // baseline at tier 1

        let newly = store.newlyEarned(in: [Self.earned("mint", tier: 2)]) // climbed a tier
        #expect(newly.map(\.id) == ["mint"])
    }

    @Test func acknowledgingOneBadgeStillReportsTheOthers() {
        let defaults = Self.suiteDefaults()
        let store = BadgeSeenStore(defaults: defaults)
        let a = Self.earned("mint", tier: 1)
        let b = Self.earned("crate", tier: 1)
        _ = store.newlyEarned(in: []) // baseline empty

        // Both newly earned.
        let newly = store.newlyEarned(in: [a, b])
        #expect(Set(newly.map(\.id)) == ["mint", "crate"])

        // Acknowledge ONLY the first (mimics dismissing one card).
        store.markSeen([a.seenKey])
        let remaining = store.newlyEarned(in: [a, b])
        #expect(remaining.map(\.id) == ["crate"]) // the other still surfaces
    }

    // MARK: - Summary

    @Test func summaryCountsEarnedAndClose() {
        let badges: [EarnedBadge] = [
            Self.tieredFixture("mint", value: 50, thresholds: [5, 25, 50, 100]),   // earned, mid
            Self.tieredFixture("saved", value: 4, thresholds: [5, 25]),            // not earned, close (4/5)
            Self.tieredFixture("crate", value: 1, thresholds: [10, 50]),           // not earned, far
        ]
        let summary = BadgesViewModel.makeSummary(badges)
        #expect(summary.earnedCount == 1)
        #expect(summary.closeCount == 1) // only "saved" is ≥ 0.5 to next and not maxed
    }

    @Test func summaryNearestGoalIsHighestProgressUnmaxed() {
        let badges: [EarnedBadge] = [
            Self.tieredFixture("saved", value: 4, thresholds: [5]),     // 4/5 = 0.8
            Self.tieredFixture("crate", value: 1, thresholds: [10]),    // 0.1
            Self.tieredFixture("mint", value: 5, thresholds: [5]),      // maxed → excluded
        ]
        let summary = BadgesViewModel.makeSummary(badges)
        #expect(summary.nearestGoal?.id == "saved")
    }

    @Test func summaryPeekPutsEarnedFirstAndCapsAtFive() {
        let badges: [EarnedBadge] = [
            Self.tieredFixture("a", value: 0, thresholds: [5]),
            Self.tieredFixture("b", value: 5, thresholds: [5]), // earned
            Self.tieredFixture("c", value: 0, thresholds: [5]),
            Self.tieredFixture("d", value: 5, thresholds: [5]), // earned
            Self.tieredFixture("e", value: 0, thresholds: [5]),
            Self.tieredFixture("f", value: 0, thresholds: [5]),
        ]
        let peek = BadgesViewModel.makeSummary(badges).peek
        #expect(peek.count == 5)
        #expect(peek.prefix(2).map(\.id) == ["b", "d"]) // earned first, original order preserved
    }

    private static func tieredFixture(_ id: String, value: Int, thresholds: [Int]) -> EarnedBadge {
        let def = BadgeDefinition(id: id, title: id, subtitle: "", symbol: "", tint: .gray,
                                  kind: .tiered(thresholds: thresholds))
        let p = BadgeMath.tierProgress(value: value, thresholds: thresholds)
        return EarnedBadge(definition: def, value: value, isEarned: p.isEarned, tier: p)
    }
}
