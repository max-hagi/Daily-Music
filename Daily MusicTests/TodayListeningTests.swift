import Foundation
import Testing
@testable import Daily_Music

struct ListenTrackerTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    @Test func accumulatesOnlyWhilePlaying() {
        var tracker = ListenTracker()
        tracker.sample(isPlaying: true, now: at(0))
        tracker.sample(isPlaying: true, now: at(10))   // +10 playing
        tracker.sample(isPlaying: false, now: at(20))  // paused gap, no credit
        tracker.sample(isPlaying: true, now: at(30))   // restart clock
        tracker.sample(isPlaying: true, now: at(35))   // +5 playing
        #expect(tracker.accumulated == 15)
    }

    @Test func reachesThresholdAtTwentyFiveSeconds() {
        var tracker = ListenTracker()
        tracker.sample(isPlaying: true, now: at(0))
        tracker.sample(isPlaying: true, now: at(24))
        #expect(tracker.hasReachedThreshold(finished: false) == false)
        tracker.sample(isPlaying: true, now: at(25))
        #expect(tracker.hasReachedThreshold(finished: false) == true)
    }

    @Test func finishingShortClipCollectsImmediately() {
        var tracker = ListenTracker()
        tracker.sample(isPlaying: true, now: at(0))
        tracker.sample(isPlaying: true, now: at(8))    // only 8s, under threshold
        #expect(tracker.hasReachedThreshold(finished: true) == true)
    }

    @Test func scrubbingWithoutPlayingNeverCredits() {
        var tracker = ListenTracker()
        tracker.sample(isPlaying: false, now: at(0))
        tracker.sample(isPlaying: false, now: at(60))
        #expect(tracker.accumulated == 0)
        #expect(tracker.hasReachedThreshold(finished: false) == false)
    }

    @Test func backwardsClockNeverReducesCredit() {
        var tracker = ListenTracker()
        tracker.sample(isPlaying: true, now: at(0))
        tracker.sample(isPlaying: true, now: at(10))   // +10 playing
        tracker.sample(isPlaying: true, now: at(5))    // clock jumps back — ignored
        #expect(tracker.accumulated == 10)
    }
}

struct PersonNameTests {
    @Test func takesFirstWordOfAFullName() {
        #expect(PersonName.firstName(from: "Max Smith") == "Max")
    }

    @Test func stripsEmailDomainThenFirstWord() {
        #expect(PersonName.firstName(from: "max@example.com") == "max")
    }

    @Test func emptyOrWhitespaceYieldsNil() {
        #expect(PersonName.firstName(from: "") == nil)
        #expect(PersonName.firstName(from: "   ") == nil)
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(PersonName.firstName(from: "  Max  Smith ") == "Max")
    }
}

struct NewDropPromptRuleTests {
    @Test func showsWhenUncollectedAndNotDismissed() {
        #expect(NewDropPromptRule.shouldShow(isCollected: false, dismissedThisSession: false) == true)
    }

    @Test func hiddenOnceCollected() {
        #expect(NewDropPromptRule.shouldShow(isCollected: true, dismissedThisSession: false) == false)
    }

    @Test func hiddenAfterDismissThisSession() {
        #expect(NewDropPromptRule.shouldShow(isCollected: false, dismissedThisSession: true) == false)
    }
}

struct TransitionResolverTests {
    @Test func commitsWhenRingFullAndSlow() {
        #expect(TransitionResolver.resolve(armProgress: 1, velocity: 0) == .commit)
    }

    @Test func cancelsWhenNotFullAndSlow() {
        #expect(TransitionResolver.resolve(armProgress: 0.9, velocity: 0) == .cancel)
        #expect(TransitionResolver.resolve(armProgress: 0.0, velocity: 0) == .cancel)
    }

    @Test func fastFlickCommitsBeforeFull() {
        #expect(TransitionResolver.resolve(armProgress: 0.3, velocity: 1200) == .commit)
    }

    @Test func slowReleaseBelowFullCancels() {
        #expect(TransitionResolver.resolve(armProgress: 0.99, velocity: 100) == .cancel)
    }
}

struct TransitionMathTests {
    @Test func pullClampsAtZero() {
        #expect(TransitionMath.armProgress(forPull: -50) == 0)
        #expect(TransitionMath.armProgress(forPull: 0) == 0)
    }

    @Test func pullReachesOneAtSpan() {
        #expect(TransitionMath.armProgress(forPull: TransitionMath.pullSpan) == 1)
        #expect(TransitionMath.armProgress(forPull: 999) == 1)
    }

    @Test func pullIsLinearMidway() {
        #expect(TransitionMath.armProgress(forPull: TransitionMath.pullSpan / 2) == 0.5)
    }

    @Test func dragReturnsZeroForNonPositiveHeight() {
        #expect(TransitionMath.armProgress(forDrag: 100, height: 0) == 0)
        #expect(TransitionMath.armProgress(forDrag: 100, height: -10) == 0)
    }

    @Test func dragClampsAndScalesWithHeight() {
        let h: CGFloat = 800
        let span = Double(h) * TransitionMath.dismissHeightFraction
        #expect(TransitionMath.armProgress(forDrag: span, height: h) == 1)
        #expect(TransitionMath.armProgress(forDrag: span / 2, height: h) == 0.5)
        #expect(TransitionMath.armProgress(forDrag: -10, height: h) == 0)
        #expect(TransitionMath.armProgress(forDrag: span * 2, height: h) == 1)
    }
}

struct ListeningHostMachineTests {
    @Test func presentationMovesThroughPrepareAnimateAndReady() {
        var machine = ListeningHostMachine()

        #expect(machine.handle(.presentRequested) == .prepareHost)
        #expect(machine.phase == .preparing)
        #expect(machine.isMounted)
        #expect(machine.isReady == false)

        #expect(machine.handle(.hostPrepared) == .animateIn)
        #expect(machine.phase == .presenting)
        #expect(machine.isReady == false)

        #expect(machine.handle(.presentationCompleted) == .none)
        #expect(machine.phase == .presented)
        #expect(machine.isReady)
    }

    @Test func duplicatePresentationRequestsAreIgnored() {
        var machine = ListeningHostMachine()

        #expect(machine.handle(.presentRequested) == .prepareHost)
        #expect(machine.handle(.presentRequested) == .none)
        #expect(machine.phase == .preparing)
    }

    @Test func dismissalKeepsHostMountedUntilCompletion() {
        var machine = ListeningHostMachine(phase: .presented)

        #expect(machine.handle(.dismissRequested) == .animateOut)
        #expect(machine.phase == .dismissing)
        #expect(machine.isMounted)
        #expect(machine.isReady == false)

        #expect(machine.handle(.dismissalCompleted) == .detachHost)
        #expect(machine.phase == .idle)
        #expect(machine.isMounted == false)
    }

    @Test func duplicateDismissalsDetachOnlyOnce() {
        var machine = ListeningHostMachine(phase: .presented)

        #expect(machine.handle(.dismissRequested) == .animateOut)
        #expect(machine.handle(.dismissRequested) == .none)
        #expect(machine.handle(.dismissalCompleted) == .detachHost)
        #expect(machine.handle(.dismissalCompleted) == .none)
    }

    @Test func cancellationDetachesAnyMountedPhase() {
        for phase in [
            ListeningHostPhase.preparing,
            .presenting,
            .presented,
            .dismissing
        ] {
            var machine = ListeningHostMachine(phase: phase)
            #expect(machine.handle(.cancelled) == .detachHost)
            #expect(machine.phase == .idle)
        }
    }
}
