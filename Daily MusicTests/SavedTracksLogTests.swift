import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct SavedTracksLogTests {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SavedTracksLogTests-\(UUID().uuidString)")!
    }

    private func sampleEntry() -> DailyEntry {
        DailyEntry(
            id: UUID(), date: Date(), title: "Nobody", artist: "Mitski",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "123",
            spotifyURI: "spotify:track:123"
        )
    }

    @Test func entriesStartUnsaved() {
        let log = SavedTracksLog(defaults: freshDefaults())
        #expect(!log.isSaved(sampleEntry()))
    }

    @Test func markSavedSticksAndPersistsAcrossInstances() {
        let defaults = freshDefaults()
        let entry = sampleEntry()
        let log = SavedTracksLog(defaults: defaults)
        log.markSaved(entry)
        #expect(log.isSaved(entry))

        let reloaded = SavedTracksLog(defaults: defaults)
        #expect(reloaded.isSaved(entry))
    }

    @Test func markSavedIsIdempotent() {
        let defaults = freshDefaults()
        let entry = sampleEntry()
        let log = SavedTracksLog(defaults: defaults)
        log.markSaved(entry)
        log.markSaved(entry)
        let stored = defaults.stringArray(forKey: "appleMusic.savedEntryIDs") ?? []
        #expect(stored.count == 1)
    }
}
