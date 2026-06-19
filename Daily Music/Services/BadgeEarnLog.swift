//
//  BadgeEarnLog.swift
//  Daily Music
//
//  Persists WHEN each badge tier was first earned, so the Insights shelf and the
//  Badges page can show "recently earned" order. Keyed by EarnedBadge.seenKey, so
//  climbing a tier records a fresh timestamp and jumps to the front. Independent of
//  BadgeSeenStore: seen-state gates the celebration, this only orders. The first
//  call naturally baselines every current earn at one timestamp (they're all
//  unstamped), so a user with existing history isn't given a fake recency order
//  spread across days.
//

import Foundation

final class BadgeEarnLog {
    private let defaults: UserDefaults
    private static let datesKey = "badges.earnLog.dates"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// seenKey → first-earned date.
    func dates() -> [String: Date] {
        let raw = defaults.dictionary(forKey: Self.datesKey) as? [String: Double] ?? [:]
        return raw.mapValues { Date(timeIntervalSinceReferenceDate: $0) }
    }

    /// Stamp each earned badge's seenKey the first time it's seen, leaving existing
    /// timestamps untouched. The first call stamps every current earn at `now`
    /// (they're all new), which is the silent baseline; later calls stamp only
    /// newly-earned keys.
    func record(_ badges: [EarnedBadge], now: Date = Date()) {
        var raw = defaults.dictionary(forKey: Self.datesKey) as? [String: Double] ?? [:]
        let stamp = now.timeIntervalSinceReferenceDate

        var changed = false
        for badge in badges where badge.isEarned && raw[badge.seenKey] == nil {
            raw[badge.seenKey] = stamp
            changed = true
        }
        if changed { defaults.set(raw, forKey: Self.datesKey) }
    }
}
