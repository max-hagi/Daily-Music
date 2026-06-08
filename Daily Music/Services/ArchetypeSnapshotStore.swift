//
//  ArchetypeSnapshotStore.swift
//  Daily Music
//
//  Tiny local persistence wrapper for the stable Insights archetype snapshot.
//

import Foundation

@MainActor
final class ArchetypeSnapshotStore {
    private let defaults: UserDefaults
    private let key: String
    private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        key: String = "insights.archetypeSnapshot",
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.key = key
        self.now = now
    }

    func load() -> ArchetypeSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(ArchetypeSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    func save(_ snapshot: ArchetypeSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    @discardableResult
    func evaluate(candidate: TasteProfile?, hasCompletedOnboarding: Bool) -> ArchetypeSnapshot {
        let evaluated = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: load(),
            candidate: candidate,
            now: now(),
            hasCompletedOnboarding: hasCompletedOnboarding
        )
        save(evaluated)
        return evaluated
    }

    @discardableResult
    func acknowledgeReveal() -> ArchetypeSnapshot {
        let acknowledged = ArchetypeSnapshotEvaluator.acknowledgeReveal(load())
        save(acknowledged)
        return acknowledged
    }
}
