//
//  BadgesViewModel.swift
//  Daily Music
//
//  Drives the Insights badge UI. Assembles a BadgeInputs snapshot from the live
//  stores, runs it through a BadgeService, exposes the full list + a compact
//  summary for the Insights card, and diffs against BadgeSeenStore to surface
//  newly-earned badges to celebrate.
//

import Foundation

@MainActor
@Observable
final class BadgesViewModel {

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
    private(set) var newlyEarned: [EarnedBadge] = []

    private let entries: EntryService
    private let listensStore: ListensStore
    private let favoritesStore: FavoritesStore
    private let ratingsStore: RatingsStore
    private let checkIns: CheckInService
    private let snapshotStore: ArchetypeSnapshotStore
    private let seenStore: BadgeSeenStore

    init(
        entries: EntryService,
        listensStore: ListensStore,
        favoritesStore: FavoritesStore,
        ratingsStore: RatingsStore,
        checkIns: CheckInService,
        snapshotStore: ArchetypeSnapshotStore? = nil,
        seenStore: BadgeSeenStore = BadgeSeenStore()
    ) {
        self.entries = entries
        self.listensStore = listensStore
        self.favoritesStore = favoritesStore
        self.ratingsStore = ratingsStore
        self.checkIns = checkIns
        self.snapshotStore = snapshotStore ?? ArchetypeSnapshotStore()
        self.seenStore = seenStore
    }

    func load() async {
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
        badges = all
        summary = Self.makeSummary(all)
        newlyEarned = seenStore.newlyEarned(in: all)
    }

    /// Mark the current celebrations as seen and clear them.
    func acknowledgeCelebrations() {
        seenStore.markSeen(newlyEarned.map(\.seenKey))
        newlyEarned = []
    }

    // MARK: - Pure summary builder

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
}
