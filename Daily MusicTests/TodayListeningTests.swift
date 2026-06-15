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
