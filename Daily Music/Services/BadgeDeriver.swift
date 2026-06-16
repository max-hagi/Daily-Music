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

    // MARK: - Moments

    private func moment(_ def: BadgeDefinition, _ i: BadgeInputs) -> EarnedBadge {
        let earned = isMomentEarned(def.id, i)
        return EarnedBadge(definition: def, value: earned ? 1 : 0, isEarned: earned, tier: nil)
    }

    private func isMomentEarned(_ id: String, _ i: BadgeInputs) -> Bool {
        switch id {
        case "firstPress":
            return i.entries.contains { status($0, i) == .heardSameDay }
        case "perfectWeek":
            return longestSameDayRun(i) >= 7
        case "comeback":
            return hasComeback(i)
        case "nightOwl":
            return i.heardAt.values.contains { i.calendar.component(.hour, from: $0) < 5 }
        case "flawlessMonth":
            return hasFlawlessMonth(i)
        case "revealed":
            return i.hasRevealedArchetype
        default:
            return false
        }
    }

    /// Longest run of consecutive calendar days where each day's drop was heard
    /// same-day. Built from the set of same-day drop-days.
    private func longestSameDayRun(_ i: BadgeInputs) -> Int {
        let mintDays = Set(
            i.entries
                .filter { status($0, i) == .heardSameDay }
                .map { i.calendar.startOfDay(for: $0.date) })
        return longestConsecutiveRun(of: mintDays, calendar: i.calendar)
    }

    /// True if a run of ≥7 consecutive check-in days exists that is NOT the first
    /// run — i.e. the streak broke and was rebuilt to a week.
    private func hasComeback(_ i: BadgeInputs) -> Bool {
        let runs = consecutiveRuns(of: i.checkInDays, calendar: i.calendar)
        guard runs.count >= 2 else { return false }
        return runs.dropFirst().contains { $0 >= 7 }
    }

    /// True if any completed month (strictly before the current month) had at least
    /// one drop and none of its drops were missed.
    private func hasFlawlessMonth(_ i: BadgeInputs) -> Bool {
        let currentMonth = i.calendar.dateInterval(of: .month, for: i.now)?.start
        let byMonth = Dictionary(grouping: i.entries) {
            i.calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date
        }
        for (month, entries) in byMonth {
            if let currentMonth,
               i.calendar.isDate(month, equalTo: currentMonth, toGranularity: .month) { continue }
            guard !entries.isEmpty else { continue }
            let anyMissed = entries.contains { status($0, i) == .missed }
            if !anyMissed { return true }
        }
        return false
    }

    // MARK: - Run helpers (consecutive calendar days)

    private func longestConsecutiveRun(of days: Set<Date>, calendar: Calendar) -> Int {
        consecutiveRuns(of: days, calendar: calendar).max() ?? 0
    }

    /// Lengths of each maximal run of consecutive calendar days, in chronological order.
    private func consecutiveRuns(of days: Set<Date>, calendar: Calendar) -> [Int] {
        let sorted = days.map { calendar.startOfDay(for: $0) }.sorted()
        guard !sorted.isEmpty else { return [] }
        var runs: [Int] = []
        var run = 1
        for idx in 1..<sorted.count {
            let expected = calendar.date(byAdding: .day, value: 1, to: sorted[idx - 1])!
            if calendar.isDate(sorted[idx], inSameDayAs: expected) {
                run += 1
            } else {
                runs.append(run)
                run = 1
            }
        }
        runs.append(run)
        return runs
    }

    // MARK: - Helpers

    private func status(_ entry: DailyEntry, _ i: BadgeInputs) -> ListenStatus {
        ListenStatus.of(
            entryDate: entry.date, heardAt: i.heardAt[entry.id],
            calendar: i.calendar, asOf: i.now)
    }
}
