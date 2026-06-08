import Foundation
import Testing
@testable import Daily_Music

struct ArchetypeSnapshotTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func nilCandidateLeavesSnapshotUnchanged() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "euphoric_default",
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
            candidate: .euphoricFestivalKid,
            now: start,
            hasCompletedOnboarding: true
        )

        #expect(result.stableArchetypeID == "euphoric_festival_kid")
        #expect(result.previousArchetypeID == nil)
        #expect(result.pendingRevealArchetypeID == "euphoric_festival_kid")
        #expect(result.hasPlayedFirstUnlockReveal == false)
        #expect(result.lastEvaluatedAt == start)
    }

    @Test func candidateBeforeOnboardingStoresStableWithoutReveal() {
        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: .empty,
            candidate: .euphoricFestivalKid,
            now: start,
            hasCompletedOnboarding: false
        )

        #expect(result.stableArchetypeID == "euphoric_festival_kid")
        #expect(result.pendingRevealArchetypeID == nil)
        #expect(result.hasPlayedFirstUnlockReveal == false)
    }

    @Test func acknowledgingFirstUnlockClearsPendingAndRecordsReveal() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "euphoric_festival_kid",
            previousArchetypeID: nil,
            pendingRevealArchetypeID: "euphoric_festival_kid",
            lastEvaluatedAt: start,
            lastRevealedArchetypeID: nil,
            hasPlayedFirstUnlockReveal: false
        )

        let acknowledged = ArchetypeSnapshotEvaluator.acknowledgeReveal(snapshot)

        #expect(acknowledged.pendingRevealArchetypeID == nil)
        #expect(acknowledged.lastRevealedArchetypeID == "euphoric_festival_kid")
        #expect(acknowledged.hasPlayedFirstUnlockReveal == true)
    }

    @Test func sameCandidateAfterCadenceUpdatesEvaluationWithoutReveal() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "euphoric_festival_kid",
            previousArchetypeID: nil,
            pendingRevealArchetypeID: nil,
            lastEvaluatedAt: start,
            lastRevealedArchetypeID: "euphoric_festival_kid",
            hasPlayedFirstUnlockReveal: true
        )
        let later = start.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence + 1)

        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: snapshot,
            candidate: .euphoricFestivalKid,
            now: later,
            hasCompletedOnboarding: true
        )

        #expect(result.stableArchetypeID == "euphoric_festival_kid")
        #expect(result.pendingRevealArchetypeID == nil)
        #expect(result.lastEvaluatedAt == later)
    }

    @Test func differentCandidateBeforeCadenceDoesNotReveal() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "euphoric_festival_kid",
            previousArchetypeID: nil,
            pendingRevealArchetypeID: nil,
            lastEvaluatedAt: start,
            lastRevealedArchetypeID: "euphoric_festival_kid",
            hasPlayedFirstUnlockReveal: true
        )
        let soon = start.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence - 1)

        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: snapshot,
            candidate: .melancholyDarkWaver,
            now: soon,
            hasCompletedOnboarding: true
        )

        #expect(result == snapshot)
    }

    @Test func differentCandidateAfterCadenceCreatesWeeklyChangeReveal() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "euphoric_festival_kid",
            previousArchetypeID: nil,
            pendingRevealArchetypeID: nil,
            lastEvaluatedAt: start,
            lastRevealedArchetypeID: "euphoric_festival_kid",
            hasPlayedFirstUnlockReveal: true
        )
        let later = start.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence + 1)

        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: snapshot,
            candidate: .melancholyDarkWaver,
            now: later,
            hasCompletedOnboarding: true
        )

        #expect(result.stableArchetypeID == "melancholy_dark_waver")
        #expect(result.previousArchetypeID == "euphoric_festival_kid")
        #expect(result.pendingRevealArchetypeID == "melancholy_dark_waver")
        #expect(result.lastEvaluatedAt == later)
    }

    @Test func deferredFirstUnlockFiresAfterOnboardingCompletes() {
        let preOnboarding = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: .empty,
            candidate: .euphoricFestivalKid,
            now: start,
            hasCompletedOnboarding: false
        )
        // Onboarding completes; re-evaluate within cadence
        let postOnboarding = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: preOnboarding,
            candidate: .euphoricFestivalKid,
            now: start.addingTimeInterval(60),
            hasCompletedOnboarding: true
        )

        #expect(postOnboarding.stableArchetypeID == "euphoric_festival_kid")
        #expect(postOnboarding.pendingRevealArchetypeID == "euphoric_festival_kid")
        #expect(postOnboarding.hasPlayedFirstUnlockReveal == false)
    }

    @Test func pendingRevealIsNotOverwritten() {
        let snapshot = ArchetypeSnapshot(
            stableArchetypeID: "melancholy_dark_waver",
            previousArchetypeID: "euphoric_festival_kid",
            pendingRevealArchetypeID: "melancholy_dark_waver",
            lastEvaluatedAt: start,
            lastRevealedArchetypeID: "euphoric_festival_kid",
            hasPlayedFirstUnlockReveal: true
        )
        let later = start.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence + 1)

        let result = ArchetypeSnapshotEvaluator.evaluate(
            snapshot: snapshot,
            candidate: .darkGothSoul,
            now: later,
            hasCompletedOnboarding: true
        )

        #expect(result == snapshot)
    }
}
