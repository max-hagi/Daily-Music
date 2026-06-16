//
//  BadgeTests.swift
//  Daily MusicTests
//
//  All unit tests for the Insights badge system: tier math, derivation, the
//  seen-store diff, and summary building.
//

import Foundation
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
}
