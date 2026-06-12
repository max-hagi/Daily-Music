import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct MusicPlayerRoutingTests {
    final class FakeEngine: MusicEngine {
        var onProgress: ((TimeInterval, TimeInterval) -> Void)?
        var onFinish: (() -> Void)?
        var shouldThrowOnPlay = false
        private(set) var playCalls = 0
        private(set) var pauseCalls = 0
        private(set) var resumeCalls = 0
        func play(appleMusicID: String) async throws {
            playCalls += 1
            if shouldThrowOnPlay { throw MusicEngineError.songNotFound }
        }
        func pause() async { pauseCalls += 1 }
        func resume() async { resumeCalls += 1 }
        func stop() async {}
        func seek(to seconds: TimeInterval) async {}
    }

    private func sampleEntry() -> DailyEntry {
        DailyEntry(
            id: UUID(), date: Date(), title: "Nobody", artist: "Mitski",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "123",
            spotifyURI: "spotify:track:123"
        )
    }

    private func session(subscribed: Bool) async -> AppleMusicSession {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(subscribed: subscribed),
            defaults: UserDefaults(suiteName: "MusicPlayerRoutingTests-\(UUID().uuidString)")!
        )
        await session.connect()
        return session
    }

    @Test func standardContextUsesFullEngineWhenSubscribed() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: true))
        await player.toggle(sampleEntry(), context: .standard)
        #expect(full.playCalls == 1)
        #expect(preview.playCalls == 0)
        #expect(player.isPlayingFullTrack)
    }

    @Test func sampleContextAlwaysUsesPreviewEngine() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: true))
        await player.toggle(sampleEntry(), context: .sample)
        #expect(preview.playCalls == 1)
        #expect(full.playCalls == 0)
        #expect(!player.isPlayingFullTrack)
    }

    @Test func previewEngineUsedWithoutConnection() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: nil)
        await player.toggle(sampleEntry(), context: .standard)
        #expect(preview.playCalls == 1)
        #expect(full.playCalls == 0)
    }

    @Test func previewEngineUsedWhenConnectedWithoutSubscription() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: false))
        await player.toggle(sampleEntry(), context: .standard)
        #expect(preview.playCalls == 1)
        #expect(full.playCalls == 0)
    }

    // Region gaps / network / revoked auth: the SAME call lands on previews.
    @Test func fullEngineFailureFallsBackToPreviewInSameCall() async {
        let preview = FakeEngine(); let full = FakeEngine()
        full.shouldThrowOnPlay = true
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: true))
        await player.toggle(sampleEntry(), context: .standard)
        #expect(full.playCalls == 1)
        #expect(preview.playCalls == 1)
        #expect(player.state == .playing)
        #expect(!player.isPlayingFullTrack)
    }

    @Test func pauseAndResumeTargetTheActiveEngine() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: true))
        let entry = sampleEntry()
        await player.toggle(entry, context: .standard)   // full engine plays
        await player.toggle(entry, context: .standard)   // pause
        #expect(full.pauseCalls == 1)
        #expect(preview.pauseCalls == 0)
        await player.toggle(entry, context: .standard)   // resume
        #expect(full.resumeCalls == 1)
        #expect(preview.resumeCalls == 0)
    }

    // Progress/finish callbacks must work whichever engine is active.
    @Test func fullEngineCallbacksDriveState() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: true))
        await player.toggle(sampleEntry(), context: .standard)
        full.onProgress?(60, 240)
        #expect(player.elapsed == 60)
        #expect(player.duration == 240)
        full.onFinish?()
        #expect(player.state == .finished)
    }
}
