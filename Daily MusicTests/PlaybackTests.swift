import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct PlaybackTests {
    // A controllable engine so we can fire progress/finish on demand.
    final class FakeEngine: MusicEngine {
        var onProgress: ((TimeInterval, TimeInterval) -> Void)?
        var onFinish: (() -> Void)?
        private(set) var playCalls = 0
        private(set) var resumeCalls = 0
        private(set) var seeks: [TimeInterval] = []
        func play(appleMusicID: String) async throws { playCalls += 1 }
        func pause() async {}
        func resume() async { resumeCalls += 1 }
        func stop() async {}
        func seek(to seconds: TimeInterval) async { seeks.append(seconds) }
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

    @Test func pauseThenPlayResumesInsteadOfRestarting() async {
        let engine = FakeEngine()
        let player = MusicPlayer(engine: engine)
        let entry = sampleEntry()
        await player.toggle(entry)               // play
        engine.onProgress?(12, 30)
        await player.toggle(entry)               // pause
        #expect(player.state == .paused)
        await player.toggle(entry)               // play again
        #expect(player.state == .playing)
        #expect(engine.playCalls == 1)           // no fresh play() = no restart
        #expect(engine.resumeCalls == 1)
        #expect(player.elapsed == 12)            // position preserved
    }

    @Test func restartSeeksBackToZeroWhilePlaying() async {
        let engine = FakeEngine()
        let player = MusicPlayer(engine: engine)
        let entry = sampleEntry()
        await player.toggle(entry)
        engine.onProgress?(20, 30)
        await player.restart(entry)
        #expect(engine.seeks == [0])
        #expect(player.state == .playing)
    }

    @Test func autoOpensWhenTodayNotYetHeard() {
        let id = UUID()
        #expect(ListeningCeremony.shouldAutoOpen(todayEntryID: id, heardEntryID: nil))
    }

    @Test func doesNotAutoOpenWhenTodayAlreadyHeard() {
        let id = UUID()
        #expect(!ListeningCeremony.shouldAutoOpen(todayEntryID: id, heardEntryID: id.uuidString))
    }

    @Test func autoOpensWhenHeardWasADifferentDay() {
        #expect(ListeningCeremony.shouldAutoOpen(todayEntryID: UUID(), heardEntryID: UUID().uuidString))
    }

    // The taste-seed loop depends on this: replaying a finished clip via toggle()
    // must start it fresh (not resume), so onboarding can loop previews.
    @Test func toggleAfterFinishedReplaysFromStart() async {
        let engine = FakeEngine()
        let player = MusicPlayer(engine: engine)
        let entry = sampleEntry()
        await player.toggle(entry)            // play #1
        engine.onProgress?(30, 30)
        engine.onFinish?()                    // clip ends
        #expect(player.state == .finished)
        await player.toggle(entry)            // the loop's replay call
        #expect(engine.playCalls == 2)        // fresh play, not resume
        #expect(engine.resumeCalls == 0)
        #expect(player.state == .playing)
        #expect(player.nowPlayingEntryID == entry.id)
    }
}
