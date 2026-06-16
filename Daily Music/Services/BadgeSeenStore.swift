//
//  BadgeSeenStore.swift
//  Daily Music
//
//  Tracks which badge tiers have already been celebrated, so an earn moment shows
//  exactly once. Mirrors ArchetypeSnapshotStore's UserDefaults pattern. Crucially,
//  nothing about whether a badge is *earned* depends on this — it only gates the
//  celebration. On the very first run it baselines (records all current earns
//  silently) so a user with existing history isn't spammed.
//

import Foundation

final class BadgeSeenStore {
    private let defaults: UserDefaults
    private static let seenKey = "badges.seenKeys"
    private static let baselinedKey = "badges.baselined"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func seenKeys() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.seenKey) ?? [])
    }

    func markSeen(_ keys: [String]) {
        var set = seenKeys()
        keys.forEach { set.insert($0) }
        defaults.set(Array(set), forKey: Self.seenKey)
    }

    /// Earned badges not yet celebrated. The first call ever baselines silently.
    func newlyEarned(in badges: [EarnedBadge]) -> [EarnedBadge] {
        let earned = badges.filter { $0.isEarned }

        guard defaults.bool(forKey: Self.baselinedKey) else {
            markSeen(earned.map(\.seenKey))
            defaults.set(true, forKey: Self.baselinedKey)
            return []
        }

        let seen = seenKeys()
        return earned.filter { !seen.contains($0.seenKey) }
    }
}
