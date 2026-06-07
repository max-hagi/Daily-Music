import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct PlaybackTests {
    // A controllable engine so we can fire progress/finish on demand.
    final class FakeEngine: MusicEngine {
        var onProgress: ((TimeInterval, TimeInterval) -> Void)?
        var onFinish: (() -> Void)?
        func play(appleMusicID: String) async throws {}
        func pause() async {}
        func stop() async {}
        func addToDailyPlaylist(appleMusicID: String) async throws {}
    }

    private func sampleEntry() -> DailyEntry {
        DailyEntry(
            id: UUID(), date: Date(), title: "Nobody", artist: "Mitski",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "123",
            spotifyURI: "spotify:track:123"
        )
    }

    @Test func progressUpdatesElapsedAndDuration() async {
        let engine = FakeEngine()
        let player = MusicPlayer(engine: engine)
        let entry = sampleEntry()
        await player.toggle(entry)               // starts -> playing
        engine.onProgress?(9, 30)                // engine reports halfway-ish
        #expect(player.elapsed == 9)
        #expect(player.duration == 30)
        #expect(abs(player.progress - 0.3) < 0.001)
    }

    @Test func finishMovesToFinishedState() async {
        let engine = FakeEngine()
        let player = MusicPlayer(engine: engine)
        let entry = sampleEntry()
        await player.toggle(entry)
        engine.onFinish?()
        #expect(player.state == .finished)
    }

    @Test func tappingAFinishedTrackReplaysIt() async {
        let engine = FakeEngine()
        let player = MusicPlayer(engine: engine)
        let entry = sampleEntry()
        await player.toggle(entry)
        engine.onFinish?()
        #expect(player.state == .finished)
        await player.toggle(entry)               // replay
        #expect(player.state == .playing)
        #expect(player.elapsed == 0)
    }
}
