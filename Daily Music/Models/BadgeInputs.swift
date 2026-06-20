//
//  BadgeInputs.swift
//  Daily Music
//
//  An immutable snapshot of everything the BadgeDeriver needs. Assembled by
//  BadgeCenter from the live stores, then handed to the pure deriver — which
//  keeps derivation fully testable with fixtures (no stores, no async).
//

import Foundation

struct BadgeInputs {
    /// Published catalogue entries (any order); status is derived against `heardAt`.
    let entries: [DailyEntry]
    /// entry_id → earliest heard_at (from ListensStore).
    let heardAt: [UUID: Date]
    /// Saved/favourited entry ids.
    let favoriteIDs: Set<UUID>
    /// entry_id → rating (+1 / -1 / 0). Non-zero counts as "rated".
    let ratings: [UUID: Int]
    /// All daily check-in days (for streak + comeback).
    let checkInDays: Set<Date>
    /// True once a taste archetype has been locked in (snapshot.stableArchetypeID != nil).
    let hasRevealedArchetype: Bool

    var now: Date = Date()
    var calendar: Calendar = .current
}
