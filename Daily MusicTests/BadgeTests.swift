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
}
