//
//  InsightsViewModel.swift
//  Daily Music
//
//  Feeds the pure TasteMirror engine: joins the user's 👍/👎 ratings with the
//  tagged published catalog, then exposes the resulting mirror as a LoadState.
//  Degrades gracefully — missing sources yield an empty mirror, not an error.
//

import Foundation

@MainActor
@Observable
final class InsightsViewModel {
    private(set) var state: LoadState<TasteMirror> = .loading
    private(set) var stableArchetype: TasteProfile?
    private(set) var nextRevealDate: Date?
    var reveal: ArchetypeRevealRequest?

    private let entries: EntryService
    private let ratings: RatingService
    private let snapshotStore: ArchetypeSnapshotStore
    private let defaults: UserDefaults

    init(
        entries: EntryService,
        ratings: RatingService,
        snapshotStore: ArchetypeSnapshotStore? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.entries = entries
        self.ratings = ratings
        self.snapshotStore = snapshotStore ?? ArchetypeSnapshotStore()
        self.defaults = defaults
        let snapshot = self.snapshotStore.load()
        stableArchetype = TasteProfile.profile(id: snapshot.stableArchetypeID)
    }

    func load() async {
        if case .loaded = state {} else { state = .loading }

        let history = (try? await entries.publishedHistory()) ?? []
        let myRatings = (try? await ratings.myRatings()) ?? [:]
        let rated = history.compactMap { entry in
            myRatings[entry.id].map { RatedSong(entry: entry, value: $0) }
        }
        // Merge the onboarding taste-seed so the profile is established at onboarding
        // and evolves as real daily ratings accumulate.
        let mirror = TasteMirror.build(from: rated + SeedRatings.load())
        let snapshot = snapshotStore.evaluate(
            candidate: mirror.archetype,
            hasCompletedOnboarding: defaults.bool(forKey: "hasCompletedOnboarding")
        )
        stableArchetype = TasteProfile.profile(id: snapshot.stableArchetypeID)
        nextRevealDate = snapshot.lastEvaluatedAt.map { $0.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence) }
        reveal = makeReveal(from: snapshot, mirror: mirror)
        state = .loaded(mirror)
    }

    func acknowledgeReveal() {
        let snapshot = snapshotStore.acknowledgeReveal()
        stableArchetype = TasteProfile.profile(id: snapshot.stableArchetypeID)
        reveal = nil
    }

    private func makeReveal(from snapshot: ArchetypeSnapshot, mirror: TasteMirror) -> ArchetypeRevealRequest? {
        guard let pending = snapshot.pendingRevealArchetypeID,
              let newProfile = TasteProfile.profile(id: pending) else { return nil }
        let previous = TasteProfile.profile(id: snapshot.previousArchetypeID)
        let kind: ArchetypeRevealRequest.Kind = previous == nil ? .firstUnlock : .weeklyChange
        return ArchetypeRevealRequest(
            previousProfile: previous,
            newProfile: newProfile,
            reason: revealReason(for: mirror, fallback: newProfile),
            kind: kind
        )
    }

    private func revealReason(for mirror: TasteMirror, fallback: TasteProfile) -> String {
        guard let modifier = mirror.winningModifier else {
            if let mood = mirror.mood.topStandout?.name.lowercased() {
                return "Your \(mood) picks are shaping the center of your taste."
            }
            return "Your recent ratings shifted the shape of your taste."
        }

        switch modifier.dimensionID {
        case "decade":
            return "\(modifier.categoryName) songs are glowing brighter in your daily picks."
        case "theme":
            return "Songs about \(modifier.categoryName.lowercased()) are rising through your taste."
        case "genre":
            return "\(modifier.categoryName) tracks are taking the lead in your mirror."
        default:
            return "\(fallback.title) is where your taste is landing this week."
        }
    }
}
