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
    @Test func commitsAtOrAboveFractionWhenSlow() {
        #expect(TransitionResolver.resolve(committedFraction: 0.4, velocity: 0) == .commit)
        #expect(TransitionResolver.resolve(committedFraction: 0.9, velocity: 0) == .commit)
    }

    @Test func cancelsBelowFractionWhenSlow() {
        #expect(TransitionResolver.resolve(committedFraction: 0.2, velocity: 0) == .cancel)
        #expect(TransitionResolver.resolve(committedFraction: 0.0, velocity: 0) == .cancel)
    }

    @Test func fastForwardFlickCommitsBelowFraction() {
        #expect(TransitionResolver.resolve(committedFraction: 0.1, velocity: 1200) == .commit)
    }

    @Test func fastReverseFlickCancelsAboveFraction() {
        #expect(TransitionResolver.resolve(committedFraction: 0.8, velocity: -1200) == .cancel)
    }
}

struct TransitionMathTests {
    @Test func pullClampsAtZero() {
        #expect(TransitionMath.progress(forPull: -50) == 0)
        #expect(TransitionMath.progress(forPull: 0) == 0)
    }

    @Test func pullReachesOneAtSpan() {
        #expect(TransitionMath.progress(forPull: TransitionMath.pullSpan) == 1)
        #expect(TransitionMath.progress(forPull: 999) == 1)
    }

    @Test func pullIsLinearMidway() {
        #expect(TransitionMath.progress(forPull: TransitionMath.pullSpan / 2) == 0.5)
    }

    @Test func dismissReturnsZeroForNonPositiveHeight() {
        #expect(TransitionMath.dismissFraction(forDrag: 100, height: 0) == 0)
        #expect(TransitionMath.dismissFraction(forDrag: 100, height: -10) == 0)
    }

    @Test func dismissClampsAndScalesWithHeight() {
        let h: CGFloat = 800
        let span = Double(h) * TransitionMath.dismissHeightFraction   // 280
        #expect(TransitionMath.dismissFraction(forDrag: span, height: h) == 1)
        #expect(TransitionMath.dismissFraction(forDrag: span / 2, height: h) == 0.5)
        #expect(TransitionMath.dismissFraction(forDrag: -10, height: h) == 0)
        #expect(TransitionMath.dismissFraction(forDrag: span * 2, height: h) == 1)
    }
}
