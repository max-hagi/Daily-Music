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

/// The static catalogue of every badge. IDs are stable (used as seen-keys), so
/// never rename an id once shipped.
enum BadgeCatalog {
    // Tiered — counts
    static let dailyStreak = BadgeDefinition(
        id: "streak", title: "Daily Streak", subtitle: "Days in a row",
        symbol: "🔥", tint: .orange, kind: .tiered(thresholds: [3, 7, 14, 30, 100]))
    static let mint = BadgeDefinition(
        id: "mint", title: "Mint Collector", subtitle: "Heard on its drop day",
        symbol: "💿", tint: .teal, kind: .tiered(thresholds: [5, 25, 50, 100, 250]))
    static let crate = BadgeDefinition(
        id: "crate", title: "Crate Digger", subtitle: "Songs collected",
        symbol: "🗄️", tint: .indigo, kind: .tiered(thresholds: [10, 50, 100, 250]))
    static let saved = BadgeDefinition(
        id: "saved", title: "Kept Forever", subtitle: "Songs saved",
        symbol: "❤️", tint: .pink, kind: .tiered(thresholds: [5, 25, 50, 100]))
    static let critic = BadgeDefinition(
        id: "critic", title: "Critic", subtitle: "Songs rated",
        symbol: "⚖️", tint: .yellow, kind: .tiered(thresholds: [10, 50, 100, 250]))
    static let rescuer = BadgeDefinition(
        id: "rescuer", title: "Rescuer", subtitle: "Salvaged missed drops",
        symbol: "🛟", tint: .purple, kind: .tiered(thresholds: [1, 5, 10, 25]))

    // Moments — one-time, hidden until earned
    static let firstPress = BadgeDefinition(
        id: "firstPress", title: "First Press", subtitle: "Your first mint song",
        symbol: "✨", tint: .teal, kind: .moment)
    static let perfectWeek = BadgeDefinition(
        id: "perfectWeek", title: "Perfect Week", subtitle: "7 same-day pickups in a row",
        symbol: "🗓️", tint: .orange, kind: .moment)
    static let comeback = BadgeDefinition(
        id: "comeback", title: "Comeback", subtitle: "Rebuilt a streak to a week",
        symbol: "🌱", tint: .green, kind: .moment)
    static let nightOwl = BadgeDefinition(
        id: "nightOwl", title: "Night Owl", subtitle: "Caught a drop after midnight",
        symbol: "🦉", tint: .indigo, kind: .moment)
    static let flawlessMonth = BadgeDefinition(
        id: "flawlessMonth", title: "Flawless Month", subtitle: "A month with no misses",
        symbol: "🌕", tint: .yellow, kind: .moment)
    static let revealed = BadgeDefinition(
        id: "revealed", title: "Revealed", subtitle: "Unlocked your archetype",
        symbol: "🔮", tint: .purple, kind: .moment)

    static let tiered: [BadgeDefinition] = [dailyStreak, mint, crate, saved, critic, rescuer]
    static let moments: [BadgeDefinition] = [firstPress, perfectWeek, comeback, nightOwl, flawlessMonth, revealed]
    static let all: [BadgeDefinition] = tiered + moments
}
