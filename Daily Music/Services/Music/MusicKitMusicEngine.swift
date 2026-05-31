//
//  MusicKitMusicEngine.swift
//  Daily Music
//
//  The REAL Apple Music engine, implementing the same MusicEngine protocol as
//  the mock. It plays 30-second previews (works without an Apple Music
//  subscription — only a developer token is needed) and adds tracks to a
//  "Daily Music" library playlist.
//
//  ──────────────────────────────────────────────────────────────────────────
//  NOT ACTIVE YET. To turn it on once you have a paid Apple Developer account:
//
//   1. Xcode → target "Daily Music" → Signing & Capabilities → + Capability →
//      "MusicKit". (This requires the paid membership; it provisions the
//      developer token Xcode injects at build time.)
//   2. Add a privacy string so iOS can show the permission prompt. Target →
//      Info → add key  "Privacy - Media Library Usage Description"
//      (NSAppleMusicUsageDescription), value e.g.
//      "Daily Music plays song previews and saves tracks to your playlist."
//   3. In AppEnvironment.live(), change  MockMusicEngine()  →  MusicKitMusicEngine().
//   4. Run on a REAL iPhone signed into your Apple ID (the Simulator can't play
//      Apple Music). A subscription is only needed for full-track playback;
//      previews work without one.
//  ──────────────────────────────────────────────────────────────────────────
//

import Foundation
import MusicKit
import AVFoundation

final class MusicKitMusicEngine: MusicEngine {
    private static let playlistName = "Daily Music"
    private var previewPlayer: AVPlayer?

    // MARK: MusicEngine

    func play(appleMusicID: String) async throws {
        try await ensureAuthorized()
        let song = try await fetchSong(id: appleMusicID)
        guard let previewURL = song.previewAssets?.first?.url else {
            throw MusicEngineError.noPreviewAvailable
        }
        let player = AVPlayer(url: previewURL)
        previewPlayer = player
        player.play()
    }

    func pause() async {
        previewPlayer?.pause()
    }

    func stop() async {
        previewPlayer?.pause()
        previewPlayer = nil
    }

    func addToDailyPlaylist(appleMusicID: String) async throws {
        try await ensureAuthorized()
        let song = try await fetchSong(id: appleMusicID)

        let existing = try await MusicLibraryRequest<Playlist>().response().items
        if let playlist = existing.first(where: { $0.name == Self.playlistName }) {
            try await MusicLibrary.shared.add(song, to: playlist)
        } else {
            _ = try await MusicLibrary.shared.createPlaylist(name: Self.playlistName, items: [song])
        }
    }

    // MARK: Helpers

    private func ensureAuthorized() async throws {
        if MusicAuthorization.currentStatus == .authorized { return }
        let status = await MusicAuthorization.request()
        guard status == .authorized else { throw MusicEngineError.notAuthorized }
    }

    private func fetchSong(id: String) async throws -> Song {
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(id))
        let response = try await request.response()
        guard let song = response.items.first else { throw MusicEngineError.songNotFound }
        return song
    }
}

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
