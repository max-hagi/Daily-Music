//
//  BadgeDeriver.swift
//  Daily Music
//
//  Pure derivation: BadgeInputs → [EarnedBadge]. No stores, no async, no UI —
//  every value comes from the snapshot, so the whole thing is unit-testable with
//  fixtures. The view model assembles the inputs; this just does the math.
//

import Foundation

struct BadgeDeriver {

    func deriveAll(from inputs: BadgeInputs) -> [EarnedBadge] {
        BadgeCatalog.tiered.map { tiered($0, inputs) }
            + BadgeCatalog.moments.map { moment($0, inputs) }
    }

    // MARK: - Tiered

    private func tiered(_ def: BadgeDefinition, _ i: BadgeInputs) -> EarnedBadge {
        guard case .tiered(let thresholds) = def.kind else {
            return EarnedBadge(definition: def, value: 0, isEarned: false, tier: nil)
        }
        let value = tieredValue(def.id, i)
        let progress = BadgeMath.tierProgress(value: value, thresholds: thresholds)
        return EarnedBadge(definition: def, value: value, isEarned: progress.isEarned, tier: progress)
    }

    private func tieredValue(_ id: String, _ i: BadgeInputs) -> Int {
        switch id {
        case "streak":
            return Streak.compute(from: i.checkInDays, calendar: i.calendar, asOf: i.now).best
        case "mint":
            return i.entries.filter { status($0, i) == .heardSameDay }.count
        case "crate":
            return i.heardAt.count
        case "saved":
            return i.favoriteIDs.count
        case "critic":
            return i.ratings.values.filter { $0 != 0 }.count
        case "rescuer":
            return i.entries.filter { status($0, i) == .rescued }.count
        default:
            return 0
        }
    }

    // MARK: - Moments (stub until Task 5)

    private func moment(_ def: BadgeDefinition, _ i: BadgeInputs) -> EarnedBadge {
        EarnedBadge(definition: def, value: 0, isEarned: false, tier: nil)
    }

    // MARK: - Helpers

    private func status(_ entry: DailyEntry, _ i: BadgeInputs) -> ListenStatus {
        ListenStatus.of(
            entryDate: entry.date, heardAt: i.heardAt[entry.id],
            calendar: i.calendar, asOf: i.now)
    }
}
