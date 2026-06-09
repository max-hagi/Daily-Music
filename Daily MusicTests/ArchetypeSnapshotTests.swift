import Foundation
import Testing
@testable import Daily_Music

struct ArchetypeSnapshotTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func nilCandidateLeavesSnapshotUnchanged() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "party_animal",
            previousArchetypeID: nil,
            pendingRevealArchetypeID: nil,
            lastEvaluatedAt: start,
            lastRevealedArchetypeID: nil,
            hasPlayedFirstUnlockReveal: true
        )

        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: snapshot,
            candidate: nil,
            now: start.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence + 1),
            hasCompletedOnboarding: true
        )

        #expect(result == snapshot)
    }

    @Test func firstPostOnboardingCandidateCreatesFirstUnlockRevealOnce() {
        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: .empty,
            candidate: .partyAnimal,
            now: start,
            hasCompletedOnboarding: true
        )

        #expect(result.stableArchetypeID == "party_animal")
        #expect(result.previousArchetypeID == nil)
        #expect(result.pendingRevealArchetypeID == "party_animal")
        #expect(result.hasPlayedFirstUnlockReveal == false)
        #expect(result.lastEvaluatedAt == start)
    }

    @Test func candidateBeforeOnboardingStoresStableWithoutReveal() {
        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: .empty,
            candidate: .partyAnimal,
            now: start,
            hasCompletedOnboarding: false
        )

        #expect(result.stableArchetypeID == "party_animal")
        #expect(result.pendingRevealArchetypeID == nil)
        #expect(result.hasPlayedFirstUnlockReveal == false)
    }

    @Test func acknowledgingFirstUnlockClearsPendingAndRecordsReveal() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "party_animal",
            previousArchetypeID: nil,
            pendingRevealArchetypeID: "party_animal",
            lastEvaluatedAt: start,
            lastRevealedArchetypeID: nil,
            hasPlayedFirstUnlockReveal: false
        )

        let acknowledged = ArchetypeSnapshotEvaluator.acknowledgeReveal(snapshot)

        #expect(acknowledged.pendingRevealArchetypeID == nil)
        #expect(acknowledged.lastRevealedArchetypeID == "party_animal")
        #expect(acknowledged.hasPlayedFirstUnlockReveal == true)
    }

    @Test func sameCandidateAfterCadenceUpdatesEvaluationWithoutReveal() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "party_animal",
            previousArchetypeID: nil,
            pendingRevealArchetypeID: nil,
            lastEvaluatedAt: start,
            lastRevealedArchetypeID: "party_animal",
            hasPlayedFirstUnlockReveal: true
        )
        let later = start.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence + 1)

        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: snapshot,
            candidate: .partyAnimal,
            now: later,
            hasCompletedOnboarding: true
        )

        #expect(result.stableArchetypeID == "party_animal")
        #expect(result.pendingRevealArchetypeID == nil)
        #expect(result.lastEvaluatedAt == later)
    }

    @Test func differentCandidateBeforeCadenceDoesNotReveal() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "party_animal",
            previousArchetypeID: nil,
            pendingRevealArchetypeID: nil,
            lastEvaluatedAt: start,
            lastRevealedArchetypeID: "party_animal",
            hasPlayedFirstUnlockReveal: true
        )
        let soon = start.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence - 1)

        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: snapshot,
            candidate: .theMelancholic,
            now: soon,
            hasCompletedOnboarding: true
        )

        #expect(result == snapshot)
    }

    @Test func differentCandidateAfterCadenceCreatesWeeklyChangeReveal() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "party_animal",
            previousArchetypeID: nil,
            pendingRevealArchetypeID: nil,
            lastEvaluatedAt: start,
            lastRevealedArchetypeID: "party_animal",
            hasPlayedFirstUnlockReveal: true
        )
        let later = start.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence + 1)

        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: snapshot,
            candidate: .theMelancholic,
            now: later,
            hasCompletedOnboarding: true
        )

        #expect(result.stableArchetypeID == "the_melancholic")
        #expect(result.previousArchetypeID == "party_animal")
        #expect(result.pendingRevealArchetypeID == "the_melancholic")
        #expect(result.lastEvaluatedAt == later)
    }

    @Test func deferredFirstUnlockFiresAfterOnboardingCompletes() {
        let preOnboarding = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: .empty,
            candidate: .partyAnimal,
            now: start,
            hasCompletedOnboarding: false
        )
        // Onboarding completes; re-evaluate within cadence
        let postOnboarding = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: preOnboarding,
            candidate: .partyAnimal,
            now: start.addingTimeInterval(60),
            hasCompletedOnboarding: true
        )

        #expect(postOnboarding.stableArchetypeID == "party_animal")
        #expect(postOnboarding.pendingRevealArchetypeID == "party_animal")
        #expect(postOnboarding.hasPlayedFirstUnlockReveal == false)
    }

    @Test func pendingRevealIsNotOverwritten() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "the_melancholic",
            previousArchetypeID: "party_animal",
            pendingRevealArchetypeID: "the_melancholic",
            lastEvaluatedAt: start,
            lastRevealedArchetypeID: "party_animal",
            hasPlayedFirstUnlockReveal: true
        )
        let later = start.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence + 1)

        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: snapshot,
            candidate: .theOutsider,
            now: later,
            hasCompletedOnboarding: true
        )

        #expect(result == snapshot)
    }
}
