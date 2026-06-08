//
//  ArchetypeSnapshot.swift
//  Daily Music
//
//  Stabilizes the user's visible archetype so the taste mirror can keep updating
//  daily while identity changes feel earned and ceremonial.
//

import Foundation

struct ArchetypeSnapshot: Codable, Equatable {
    var stableArchetypeID: String?
    var previousArchetypeID: String?
    var pendingRevealArchetypeID: String?
    var lastEvaluatedAt: Date?
    var lastRevealedArchetypeID: String?
    var hasPlayedFirstUnlockReveal: Bool

    static let empty = ArchetypeSnapshot(
        stableArchetypeID: nil,
        previousArchetypeID: nil,
        pendingRevealArchetypeID: nil,
        lastEvaluatedAt: nil,
        lastRevealedArchetypeID: nil,
        hasPlayedFirstUnlockReveal: false
    )
}

enum ArchetypeSnapshotEvaluator {
    static let cadence: TimeInterval = 7 * 24 * 60 * 60

    static func evaluate(
        snapshot: ArchetypeSnapshot,
        candidate: TasteProfile?,
        now: Date,
        hasCompletedOnboarding: Bool
    ) -> ArchetypeSnapshot {
        guard let candidate else { return snapshot }
        guard snapshot.pendingRevealArchetypeID == nil else { return snapshot }

        var next = snapshot

        guard let stableID = snapshot.stableArchetypeID else {
            next.stableArchetypeID = candidate.id
            next.lastEvaluatedAt = now
            if hasCompletedOnboarding, !snapshot.hasPlayedFirstUnlockReveal {
                next.pendingRevealArchetypeID = candidate.id
            }
            return next
        }

        guard let lastEvaluatedAt = snapshot.lastEvaluatedAt,
              now.timeIntervalSince(lastEvaluatedAt) >= cadence else {
            // Deferred first-unlock: evaluate() was called before onboarding completed,
            // so stableID was written but pendingReveal was skipped. Fire it now.
            if hasCompletedOnboarding, !snapshot.hasPlayedFirstUnlockReveal,
               snapshot.pendingRevealArchetypeID == nil {
                next.pendingRevealArchetypeID = stableID
                return next
            }
            return snapshot
        }

        next.lastEvaluatedAt = now

        guard stableID != candidate.id else { return next }

        next.previousArchetypeID = stableID
        next.stableArchetypeID = candidate.id
        next.pendingRevealArchetypeID = candidate.id
        return next
    }

    static func acknowledgeReveal(_ snapshot: ArchetypeSnapshot) -> ArchetypeSnapshot {
        var next = snapshot
        if let pending = snapshot.pendingRevealArchetypeID {
            next.lastRevealedArchetypeID = pending
        }
        next.pendingRevealArchetypeID = nil
        next.hasPlayedFirstUnlockReveal = true
        return next
    }
}

struct ArchetypeRevealRequest: Identifiable, Equatable {
    enum Kind: Equatable {
        case firstUnlock
        case weeklyChange
    }

    let id: String
    let previousProfile: TasteProfile?
    let newProfile: TasteProfile
    let reason: String
    let kind: Kind

    init(previousProfile: TasteProfile?, newProfile: TasteProfile, reason: String, kind: Kind) {
        self.previousProfile = previousProfile
        self.newProfile = newProfile
        self.reason = reason
        self.kind = kind
        self.id = "\(kind)-\(newProfile.id)"
    }
}
