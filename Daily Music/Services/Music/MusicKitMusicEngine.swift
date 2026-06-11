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
import MusicKit        // Apple Music catalog + library APIs
import AVFoundation    // AVPlayer, used to play the preview audio file

final class MusicKitMusicEngine: MusicEngine {
    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onFinish: (() -> Void)?

    private static let playlistName = "Daily Music"
    // Held as a property so the player isn't deallocated mid-playback (a local
    // var would be freed the instant play() returns, cutting off the audio).
    private var previewPlayer: AVPlayer?

    // MARK: MusicEngine

    func play(appleMusicID: String) async throws {
        try await ensureAuthorized()
        let song = try await fetchSong(id: appleMusicID)
        // previewAssets are the free 30-sec clips (no subscription needed). Optional
        // chain + guard: if there's no preview URL, surface a clear error.
        guard let previewURL = song.previewAssets?.first?.url else {
            throw MusicEngineError.noPreviewAvailable
        }
        // AVPlayer streams the preview file directly.
        let player = AVPlayer(url: previewURL)
        previewPlayer = player
        player.play()
    }

    // `?.` no-ops safely if nothing is loaded yet.
    func pause() async {
        previewPlayer?.pause()
    }

    func resume() async {
        previewPlayer?.play()
    }

    func stop() async {
        previewPlayer?.pause()
        previewPlayer = nil   // release the player so it can be torn down
    }

    func seek(to seconds: TimeInterval) async {
        await MainActor.run {
            previewPlayer?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        }
    }

    func addToDailyPlaylist(appleMusicID: String) async throws {
        try await ensureAuthorized()
        let song = try await fetchSong(id: appleMusicID)

        // Find-or-create: fetch the user's library playlists, reuse ours if present,
        // otherwise create it seeded with this song. `_ =` discards the returned
        // playlist since we don't need it here.
        let existing = try await MusicLibraryRequest<Playlist>().response().items
        if let playlist = existing.first(where: { $0.name == Self.playlistName }) {
            try await MusicLibrary.shared.add(song, to: playlist)
        } else {
            _ = try await MusicLibrary.shared.createPlaylist(name: Self.playlistName, items: [song])
        }
    }

    // MARK: Helpers

    // Gate every operation on permission. If already authorized, return early;
    // otherwise show the system prompt and throw if the user declines.
    private func ensureAuthorized() async throws {
        if MusicAuthorization.currentStatus == .authorized { return }
        let status = await MusicAuthorization.request()
        guard status == .authorized else { throw MusicEngineError.notAuthorized }
    }

    // Look the song up in the Apple Music catalog by its ID. `matching: \.id` is a
    // KEY PATH — a type-safe reference to the Song.id property the request filters on.
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
    case addToPlaylistUnavailable

    // Note the bodies have no `return` — single-expression switch cases in Swift
    // return implicitly.
    var errorDescription: String? {
        switch self {
        case .notAuthorized:    "Apple Music access wasn't granted."
        case .songNotFound:     "Couldn't find this song in the Apple Music catalog."
        case .noPreviewAvailable: "No preview is available for this song."
        case .addToPlaylistUnavailable: "Saving to your library needs Apple Music. Use \"Open in…\" for now."
        }
    }
}
