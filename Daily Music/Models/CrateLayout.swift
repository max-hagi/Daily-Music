//
//  CrateLayout.swift
//  Daily Music
//
//  Pure layout helpers for the Crate (the Vault browse, spec §10.4) and its
//  one-line collection count (§10.1). No UI, fully unit-tested.
//

import Foundation

enum CrateLayout {
    /// The Vault's one-line count, e.g. "3 records · 3 this month". The month
    /// clause is dropped when nothing was collected this month, so the line never
    /// reads "· 0 this month".
    static func collectionCountLabel(total: Int, thisMonth: Int) -> String {
        let noun = total == 1 ? "record" : "records"
        guard thisMonth > 0 else { return "\(total) \(noun)" }
        return "\(total) \(noun) · \(thisMonth) this month"
    }

    /// One month's worth of entries for the Crate shelves.
    struct MonthSection: Identifiable {
        let id: Date          // first-of-month, used as stable identity
        let title: String     // e.g. "June 2026"
        let entries: [DailyEntry]
    }

    /// Group newest-first entries into ordered month buckets (months newest-first,
    /// entries kept in their incoming newest-first order within each month).
    static func monthSections(
        for entries: [DailyEntry],
        calendar: Calendar = .current
    ) -> [MonthSection] {
        var order: [Date] = []
        var buckets: [Date: [DailyEntry]] = [:]
        for entry in entries {
            let monthStart = calendar.dateInterval(of: .month, for: entry.date)?.start
                ?? calendar.startOfDay(for: entry.date)
            if buckets[monthStart] == nil { order.append(monthStart) }
            buckets[monthStart, default: []].append(entry)
        }
        return order.map { start in
            MonthSection(
                id: start,
                title: start.formatted(.dateTime.month(.wide).year()),
                entries: buckets[start] ?? []
            )
        }
    }
}

/// The Vault header's secondary line — a context-aware nudge chosen by priority.
/// Pure and unit-tested; the view passes in counts/dates and renders the string.
enum VaultNudge {
    static func line(
        total: Int,
        rescuable: Int,
        collectedToday: Bool,
        daysToNextMilestone: Int?,
        startedMonth: Date?,
        calendar: Calendar = .current
    ) -> String {
        // 1. Something to reclaim wins — it's the strongest pull back in.
        if rescuable > 0 {
            return "\(rescuable) waiting to be rescued"
        }
        // 2. On a day you've collected, nudge toward the next streak pressing.
        if collectedToday, let days = daysToNextMilestone, days > 0 {
            let noun = days == 1 ? "day" : "days"
            return "\(days) \(noun) to your next pressing"
        }
        // 3. Default: the hero count, with provenance when we know the start month.
        let recordNoun = total == 1 ? "record" : "records"
        guard let startedMonth else { return "\(total) \(recordNoun)" }
        let month = startedMonth.formatted(.dateTime.month(.wide).year())
        return "\(total) \(recordNoun) · started \(month)"
    }
}
