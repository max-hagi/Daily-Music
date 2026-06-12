//
//  FullTrackMusicEngine.swift
//  Daily Music
//
//  The real Apple Music engine: full-track playback via ApplicationMusicPlayer
//  (which gives lock-screen + Control Center transport for free) and saving
//  tracks to a "Daily Music" library playlist. Both require the user to hold
//  an active Apple Music subscription — AppleMusicSession gates that via
//  capabilities, and MusicPlayer falls back to previews on any throw here.
//
//  ──────────────────────────────────────────────────────────────────────────
//  ACTIVATION CHECKLIST (needs the paid Apple Developer account):
//   1. Xcode → target "Daily Music" → Signing & Capabilities → + MusicKit.
//   2. FeatureFlags.appleMusicConnect = true.
//   3. Verify NSAppleMusicUsageDescription is in Daily Music/Info.plist.
//   4. Test on a REAL iPhone signed into an Apple ID with a subscription
//      (Simulator can't play Apple Music): connect flow, full playback,
//      pause/resume/seek, playlist add, lock-screen controls.
//  ──────────────────────────────────────────────────────────────────────────
//

import Foundation
import MusicKit

final class FullTrackMusicEngine: MusicEngine {
    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onFinish: (() -> Void)?

    private var progressTask: Task<Void, Never>?
    private var trackDuration: TimeInterval = 0
    private var reportedFinish = false

    private var player: ApplicationMusicPlayer { .shared }

    // MARK: MusicEngine

    func play(appleMusicID: String) async throws {
        try await ensureAuthorized()
        let song = try await fetchSong(id: appleMusicID)
        trackDuration = song.duration ?? 0
        player.queue = ApplicationMusicPlayer.Queue(for: [song])
        try await player.play()
        startProgressTask()
    }

    func pause() async {
        player.pause()
        progressTask?.cancel()
    }

    func resume() async {
        try? await player.play()   // resumes the queued item from its position
        startProgressTask()
    }

    func stop() async {
        progressTask?.cancel()
        progressTask = nil
        player.stop()
        trackDuration = 0
    }

    func seek(to seconds: TimeInterval) async {
        player.playbackTime = seconds
    }

    // MARK: Helpers

    /// ApplicationMusicPlayer exposes no progress callback — poll playbackTime
    /// ~5×/sec (same cadence the preview engine reports at) and synthesize the
    /// finish event when we reach the end of the track.
    private func startProgressTask() {
        progressTask?.cancel()
        reportedFinish = false
        progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = self.player.playbackTime
                let duration = self.trackDuration
                if duration > 0 {
                    self.onProgress?(elapsed, duration)
                    if elapsed >= duration - 0.25, !self.reportedFinish {
                        self.reportedFinish = true
                        self.onFinish?()
                        return
                    }
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    // Gate every operation on permission. If already authorized, return early;
    // otherwise show the system prompt and throw if the user declines.
    private func ensureAuthorized() async throws {
        if MusicAuthorization.currentStatus == .authorized { return }
        let status = await MusicAuthorization.request()
        guard status == .authorized else { throw MusicEngineError.notAuthorized }
    }

    // Look the song up in the Apple Music catalog by its ID.
    private func fetchSong(id: String) async throws -> Song {
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(id))
        let response = try await request.response()
        guard let song = response.items.first else { throw MusicEngineError.songNotFound }
        return song
    }
}

// Conforming to LocalizedError means `errorDescription` is what users see if this
// error is shown. Each case maps to friendly copy.
enum MusicEngineError: LocalizedError {
    case notAuthorized
    case songNotFound
    case noPreviewAvailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:    "Apple Music access wasn't granted."
        case .songNotFound:     "Couldn't find this song in the Apple Music catalog."
        case .noPreviewAvailable: "No preview is available for this song."
        }
    }
}
