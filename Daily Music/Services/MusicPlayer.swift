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

enum PlaybackState: Equatable {
    case idle
    case buffering
    case playing
    case paused
}

/// The actual playback mechanism. The MusicKit version implements this with
/// `ApplicationMusicPlayer`; the mock just simulates a 30-second preview.
protocol MusicEngine {
    func play(appleMusicID: String) async throws
    func pause() async
    func stop() async
    /// Find-or-create the "Daily Music" library playlist and add the track.
    func addToDailyPlaylist(appleMusicID: String) async throws
}

@MainActor
@Observable
final class MusicPlayer {
    private(set) var state: PlaybackState = .idle
    private(set) var nowPlayingEntryID: UUID?

    private let engine: MusicEngine

    init(engine: MusicEngine) {
        self.engine = engine
    }

    func isPlaying(_ entry: DailyEntry) -> Bool {
        nowPlayingEntryID == entry.id && state == .playing
    }

    /// Tap behaviour: toggles the tapped entry; switching entries restarts.
    func toggle(_ entry: DailyEntry) async {
        if nowPlayingEntryID == entry.id {
            switch state {
            case .playing:
                await engine.pause()
                state = .paused
            case .paused:
                await resume(entry)
            case .idle, .buffering:
                break
            }
        } else {
            await resume(entry)
        }
    }

    private func resume(_ entry: DailyEntry) async {
        nowPlayingEntryID = entry.id
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
    }

    func addToDailyPlaylist(_ entry: DailyEntry) async throws {
        try await engine.addToDailyPlaylist(appleMusicID: entry.appleMusicID)
    }
}

/// Simulates playback so the UI is fully explorable without MusicKit/Apple Music.
final class MockMusicEngine: MusicEngine {
    func play(appleMusicID: String) async throws {
        try? await Task.sleep(for: .milliseconds(500)) // mimic buffering
    }
    func pause() async {}
    func stop() async {}
    func addToDailyPlaylist(appleMusicID: String) async throws {
        try? await Task.sleep(for: .milliseconds(400))
    }
}
