//
//  BadgeCenter.swift
//  Daily Music
//
//  The app-wide source of badge truth. Promoted out of the Insights tab so the
//  earn celebration can fire over any screen the instant a badge is earned, and so
//  the Insights shelf and the full Badges page read one consistent list. Assembles
//  a BadgeInputs snapshot from the live stores, runs it through a BadgeService,
//  records earn timestamps (BadgeEarnLog) for recency, and diffs against
//  BadgeSeenStore to surface newly-earned badges to celebrate.
//

import Foundation

@MainActor
@Observable
final class BadgeCenter {

    struct Summary: Equatable {
        let earnedCount: Int
        /// Tiered badges not yet maxed whose progress to the next tier is ≥ 0.5.
        let closeCount: Int
        /// The single tiered badge closest to its next tier (highest progress, unmaxed).
        let nearestGoal: EarnedBadge?
        /// Up to 5 representative badges, earned first, original order otherwise.
        let peek: [EarnedBadge]
    }

    private(set) var badges: [EarnedBadge] = []
    private(set) var summary: Summary?
    /// Earned badges, newest-earned first — drives the Insights shelf.
    private(set) var recent: [EarnedBadge] = []
    /// The live daily-ritual streak (current run), for the Badges page hero.
    private(set) var currentStreak: Int = 0
    private(set) var newlyEarned: [EarnedBadge] = []

    /// Head of the celebration queue; nil when nothing is waiting to be celebrated.
    var celebrating: EarnedBadge? { newlyEarned.first }

    private let entries: EntryService
    private let listensStore: ListensStore
    private let favoritesStore: FavoritesStore
    private let ratingsStore: RatingsStore
    private let checkIns: CheckInService
    private let snapshotStore: ArchetypeSnapshotStore
    private let seenStore: BadgeSeenStore
    private let earnLog: BadgeEarnLog

    init(
        entries: EntryService,
        listensStore: ListensStore,
        favoritesStore: FavoritesStore,
        ratingsStore: RatingsStore,
        checkIns: CheckInService,
        snapshotStore: ArchetypeSnapshotStore? = nil,
        seenStore: BadgeSeenStore = BadgeSeenStore(),
        earnLog: BadgeEarnLog = BadgeEarnLog()
    ) {
        self.entries = entries
        self.listensStore = listensStore
        self.favoritesStore = favoritesStore
        self.ratingsStore = ratingsStore
        self.checkIns = checkIns
        // Built in the body (not as a default arg) because ArchetypeSnapshotStore is
        // @MainActor — default arguments evaluate in a nonisolated context.
        self.snapshotStore = snapshotStore ?? ArchetypeSnapshotStore()
        self.seenStore = seenStore
        self.earnLog = earnLog
    }

    /// Re-derive badges from the live stores and recompute the shelf + celebration
    /// queue. Cheap and idempotent — safe to call after any badge-earning action.
    func refresh() async {
        let history = (try? await entries.publishedHistory()) ?? []
        let checkInDays = (try? await checkIns.checkInDates()) ?? []

        let inputs = BadgeInputs(
            entries: history,
            heardAt: listensStore.heardAt,
            favoriteIDs: favoritesStore.ids,
            ratings: ratingsStore.ratings,
            checkInDays: checkInDays,
            hasRevealedArchetype: snapshotStore.load().stableArchetypeID != nil
        )

        let service: BadgeService = DerivedBadgeService(inputs: inputs)
        let all = await service.badges()

        earnLog.record(all)
        badges = all
        summary = Self.makeSummary(all)
        recent = Self.sortedByRecency(all, dates: earnLog.dates())
        currentStreak = Streak.compute(from: checkInDays).current
        newlyEarned = seenStore.newlyEarned(in: all)
    }

    /// Dismiss the currently-shown celebration: mark just that badge seen and drop
    /// it, so the next newly-earned badge (if any) surfaces next.
    func acknowledgeCelebration() {
        guard let shown = newlyEarned.first else { return }
        seenStore.markSeen([shown.seenKey])
        newlyEarned.removeFirst()
    }

    // MARK: - Pure builders

    nonisolated static func makeSummary(_ badges: [EarnedBadge]) -> Summary {
        let earnedCount = badges.filter { $0.isEarned }.count

        let unmaxed = badges.filter { ($0.tier?.isMaxed == false) }
        let closeCount = unmaxed.filter { ($0.tier?.progressToNext ?? 0) >= 0.5 }.count
        let nearestGoal = unmaxed.max { ($0.tier?.progressToNext ?? 0) < ($1.tier?.progressToNext ?? 0) }

        let earned = badges.filter { $0.isEarned }
        let locked = badges.filter { !$0.isEarned }
        let peek = Array((earned + locked).prefix(5))

        return Summary(earnedCount: earnedCount, closeCount: closeCount,
                       nearestGoal: nearestGoal, peek: peek)
    }

    /// Earned badges ordered newest-first by their earn timestamp; ties (e.g. the
    /// first-run baseline) fall back to catalog order via the input ordering.
    nonisolated static func sortedByRecency(_ badges: [EarnedBadge], dates: [String: Date]) -> [EarnedBadge] {
        badges
            .enumerated()
            .filter { $0.element.isEarned }
            .sorted { a, b in
                let da = dates[a.element.seenKey]
                let db = dates[b.element.seenKey]
                switch (da, db) {
                case let (x?, y?): return x == y ? a.offset < b.offset : x > y
                case (_?, nil):    return true
                case (nil, _?):    return false
                case (nil, nil):   return a.offset < b.offset
                }
            }
            .map(\.element)
    }
}
