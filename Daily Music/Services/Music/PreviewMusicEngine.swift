//
//  PreviewMusicEngine.swift
//  Daily Music
//
//  Plays free 30-second previews with no paid Apple account. It resolves each
//  track's previewUrl through the existing iTunes lookup (CatalogInfoService),
//  then streams it with AVPlayer — reporting elapsed time and an end event, with
//  a 2-second volume fade so the clip ends like a movement, not a cut.
//
//  At launch (paid account), AppEnvironment can swap this for MusicKitMusicEngine
//  behind the same MusicEngine protocol.
//

import Foundation
import AVFoundation

final class PreviewMusicEngine: MusicEngine {
    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onFinish: (() -> Void)?

    private let catalog: CatalogInfoService
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(catalog: CatalogInfoService) {
        self.catalog = catalog
    }

    func play(appleMusicID: String) async throws {
        let info = try await catalog.info(appleMusicID: appleMusicID)
        guard let previewURL = info.previewURL else {
            throw MusicEngineError.noPreviewAvailable
        }
        await start(url: previewURL)
    }

    @MainActor
    private func start(url: URL) {
        teardown()

        // Play through the silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let player = AVPlayer(url: url)
        player.volume = 1
        self.player = player

        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, let item = player.currentItem else { return }
            let raw = item.duration.seconds
            let duration = raw.isFinite && raw > 0 ? raw : 30
            let elapsed = max(0, time.seconds)
            let remaining = duration - elapsed
            if remaining <= 2 {                       // fade, don't cut
                player.volume = Float(max(0, remaining / 2))
            }
            self.onProgress?(elapsed, duration)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.onFinish?()
        }

        player.play()
    }

    func pause() async {
        await MainActor.run { player?.pause() }
    }

    func stop() async {
        await MainActor.run { teardown() }
    }

    func addToDailyPlaylist(appleMusicID: String) async throws {
        // Library writes require MusicKit (paid account). Surface clearly.
        throw MusicEngineError.addToPlaylistUnavailable
    }

    @MainActor
    private func teardown() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player?.pause()
        player = nil
    }
}
