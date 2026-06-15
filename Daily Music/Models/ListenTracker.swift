//
//  ListenTracker.swift
//  Daily Music
//
//  Pure rule for "has the listener actually heard this?". Accumulates wall-clock
//  time only while audio is PLAYING (so scrubbing/pausing can't fake a listen),
//  and treats reaching the clip's natural end as an immediate pass (covers
//  previews shorter than the threshold). Drives Today's "collect as mint" moment.
//

import Foundation

struct ListenTracker {
    /// Seconds of genuine playback required to collect a record. Tunable.
    static let collectThreshold: TimeInterval = 25

    private(set) var accumulated: TimeInterval = 0
    private var lastTick: Date?

    /// Feed the current playback state on a steady cadence. Credit only accrues
    /// across consecutive playing samples; any non-playing sample resets the clock.
    mutating func sample(isPlaying: Bool, now: Date = Date()) {
        guard isPlaying else { lastTick = nil; return }
        if let last = lastTick {
            // Only credit forward time, so a clock discontinuity (or a stale
            // timestamp) can never push the accumulated total backwards.
            let delta = now.timeIntervalSince(last)
            if delta > 0 { accumulated += delta }
        }
        lastTick = now   // anchor for the next sample

    }

    func hasReachedThreshold(finished: Bool) -> Bool {
        finished || accumulated >= Self.collectThreshold
    }
}
