//
//  MusicPlayer.swift
//  Daily Music
//
//  Playback is split in two:
//   • MusicEngine — the swappable mechanism (mock today, MusicKit later).
//   • MusicPlayer — an @Observable the SwiftUI views watch for state. It owns
//     "what's playing right now" so any screen can reflect it.
//
//  Splitting them keeps SwiftUI observation working (views observe the concrete
//  MusicPlayer) while the real playback stays behind a protocol we can replace.
//

import Foundation

// The four states a player can be in. Equatable so views can compare and animate.
enum PlaybackState: Equatable {
    case idle        // nothing loaded
    case buffering   // loading / about to start
    case playing
    case paused
    case finished    // the preview played to its end
}

/// The actual playback mechanism. The MusicKit version implements this with
/// `ApplicationMusicPlayer`; the mock just simulates a 30-second preview.
// This is the swappable LOW-LEVEL seam. Note it is NOT @Observable — it's pure
// mechanism. The observable state lives in MusicPlayer below, which wraps it.
protocol MusicEngine: AnyObject {
    func play(appleMusicID: String) async throws
    func pause() async
    func stop() async
    /// Find-or-create the "Daily Music" library playlist and add the track.
    func addToDailyPlaylist(appleMusicID: String) async throws

    /// Reported ~5×/sec while a preview plays: (elapsedSeconds, totalSeconds).
    var onProgress: ((TimeInterval, TimeInterval) -> Void)? { get set }
    /// Reported once when the current preview plays to its end.
    var onFinish: (() -> Void)? { get set }

    /// Seek the current preview to `seconds` from the start.
    func seek(to seconds: TimeInterval) async
}

// The view-facing layer. Views observe THIS (its `state` / `nowPlayingEntryID`)
// and call its methods on tap. It delegates the real work to whatever engine it
// was constructed with — so the UI never knows or cares if it's mock or MusicKit.
@MainActor
@Observable
final class MusicPlayer {
    private(set) var state: PlaybackState = .idle
    private(set) var nowPlayingEntryID: UUID?   // which entry is loaded (nil = none)
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    /// 0…1 fraction for progress rings / bars.
    var progress: Double {
        duration > 0 ? min(1, max(0, elapsed / duration)) : 0
    }

    private let engine: MusicEngine

    init(engine: MusicEngine) {
        self.engine = engine
        engine.onProgress = { [weak self] elapsed, duration in
            self?.elapsed = elapsed
            self?.duration = duration
        }
        engine.onFinish = { [weak self] in
            guard let self else { return }
            self.elapsed = self.duration
            self.state = .finished
        }
    }

    // Convenience for views: "is THIS specific row the one currently playing?"
    func isPlaying(_ entry: DailyEntry) -> Bool {
        nowPlayingEntryID == entry.id && state == .playing
    }

    /// Tap behaviour: toggles the tapped entry; switching entries restarts.
    func toggle(_ entry: DailyEntry) async {
        if nowPlayingEntryID == entry.id {
            // Same track is loaded → flip between play/pause based on current state.
            switch state {
            case .playing:
                await engine.pause()
                state = .paused
            case .paused:
                await resume(entry)
            case .finished:
                await resume(entry)   // replay from the start
            case .idle, .buffering:
                break   // ignore taps mid-transition
            }
        } else {
            // A different track was tapped → start it fresh.
            await resume(entry)
        }
    }

    // Note we update `state` BEFORE/AFTER awaiting the engine so the UI reflects
    // buffering → playing live. On error we roll back to idle so nothing looks stuck.
    private func resume(_ entry: DailyEntry) async {
        nowPlayingEntryID = entry.id
        elapsed = 0
        state = .buffering
        do {
            try await engine.play(appleMusicID: entry.appleMusicID)
            state = .playing
        } catch {
            state = .idle
            nowPlayingEntryID = nil
        }
    }

    func stop() async {
        await engine.stop()
        state = .idle
        nowPlayingEntryID = nil
        elapsed = 0
        duration = 0
    }

    /// Scrub the current preview. Updates `elapsed` optimistically so the bar tracks
    /// the finger; the engine's time observer reconciles a moment later.
    func seek(to seconds: TimeInterval) async {
        guard duration > 0 else { return }
        let clamped = min(max(0, seconds), duration)
        elapsed = clamped
        await engine.seek(to: clamped)
    }

    // `throws` is re-thrown to the caller (the view) so it can surface a failure
    // to add to the playlist (e.g. not authorized).
    func addToDailyPlaylist(_ entry: DailyEntry) async throws {
        try await engine.addToDailyPlaylist(appleMusicID: entry.appleMusicID)
    }
}

/// Simulates playback so the UI is fully explorable without MusicKit/Apple Music.
// Every method just sleeps briefly (or does nothing) — there's no actual audio,
// but the state transitions in MusicPlayer still run, so the buttons behave.
final class MockMusicEngine: MusicEngine {
    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onFinish: (() -> Void)?

    // A brisk simulated clip so dev/sim testing of the ceremony is quick.
    private let simulatedDuration: TimeInterval = 6
    private var ticker: Task<Void, Never>?
    private var elapsed: TimeInterval = 0   // held so seek() can reposition it

    func play(appleMusicID: String) async throws {
        try? await Task.sleep(for: .milliseconds(500)) // mimic buffering
        elapsed = 0
        ticker?.cancel()
        ticker = Task { [weak self] in
            guard let self else { return }
            let step = 0.2
            while self.elapsed < self.simulatedDuration {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .seconds(step))
                self.elapsed += step
                await MainActor.run { self.onProgress?(self.elapsed, self.simulatedDuration) }
            }
            await MainActor.run { self.onFinish?() }
        }
    }
    func pause() async { ticker?.cancel() }
    func stop() async { ticker?.cancel(); elapsed = 0 }
    func seek(to seconds: TimeInterval) async {
        elapsed = min(max(0, seconds), simulatedDuration)
        onProgress?(elapsed, simulatedDuration)
    }
    func addToDailyPlaylist(appleMusicID: String) async throws {
        try? await Task.sleep(for: .milliseconds(400))
    }
}
