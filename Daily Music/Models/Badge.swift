//
//  Badge.swift
//  Daily Music
//
//  Pure data for the Insights badge system: the catalogue of badge definitions,
//  the tier-progress math, and the EarnedBadge value the UI renders. No I/O — the
//  BadgeDeriver turns a BadgeInputs snapshot into [EarnedBadge] using these types.
//

import SwiftUI

/// How a badge progresses. Tiered badges count toward thresholds; moments are
/// a single hidden achievement.
enum BadgeKind: Equatable {
    case tiered(thresholds: [Int])
    case moment
}

/// Static description of a badge — the catalogue entry. No user state.
struct BadgeDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String      // emoji glyph rendered on the disc
    let tint: Color
    let kind: BadgeKind
}

/// Where a tiered badge sits relative to its thresholds.
struct TierProgress: Equatable {
    /// Number of thresholds met (0 = nothing earned yet).
    let unlockedTier: Int
    /// The next threshold to reach, nil once maxed.
    let nextThreshold: Int?
    /// 0…1 progress from the current tier floor to the next threshold; 1 when maxed.
    let progressToNext: Double

    var isEarned: Bool { unlockedTier > 0 }
    var isMaxed: Bool { nextThreshold == nil }
}

/// A definition joined with the user's current state. The UI renders this.
struct EarnedBadge: Identifiable, Equatable {
    let definition: BadgeDefinition
    let value: Int          // raw count (tiered) or 0/1 (moment)
    let isEarned: Bool
    let tier: TierProgress? // nil for moments

    var id: String { definition.id }

    /// Celebration key: a tiered badge can celebrate once per tier; a moment once.
    var seenKey: String {
        if let tier { return "\(definition.id):\(tier.unlockedTier)" }
        return "moment:\(definition.id)"
    }
}

/// Pure tier-progress math. `value` is the user's count; `thresholds` the badge's
/// tier ladder (any order — sorted internally).
enum BadgeMath {
    static func tierProgress(value: Int, thresholds: [Int]) -> TierProgress {
        let sorted = thresholds.sorted()
        let unlocked = sorted.filter { value >= $0 }.count

        guard unlocked < sorted.count else {
            return TierProgress(unlockedTier: unlocked, nextThreshold: nil, progressToNext: 1.0)
        }

        let next = sorted[unlocked]
        let floor = unlocked == 0 ? 0 : sorted[unlocked - 1]
        let span = next - floor
        let progress = span <= 0 ? 0 : Double(value - floor) / Double(span)
        return TierProgress(
            unlockedTier: unlocked,
            nextThreshold: next,
            progressToNext: min(max(progress, 0), 1)
        )
    }
}
