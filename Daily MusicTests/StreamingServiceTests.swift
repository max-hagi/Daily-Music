import Testing
import Foundation
@testable import Daily_Music

struct StreamingServiceTests {
    static func entry(appleMusicID: String = "1", spotifyURI: String = "spotify:track:x",
                      artist: String = "Artist", title: String = "Title") -> DailyEntry {
        DailyEntry(id: UUID(), date: Date(), title: title, artist: artist,
                   albumArtURL: nil, journalMarkdown: "",
                   appleMusicID: appleMusicID, spotifyURI: spotifyURI)
    }

    @Test func appleMusicIsExactLink() {
        let url = StreamingService.appleMusic.url(for: Self.entry(appleMusicID: "1440947554"))
        #expect(url?.absoluteString == "https://music.apple.com/song/1440947554")
    }

    @Test func spotifyIsExactLink() {
        let url = StreamingService.spotify.url(for: Self.entry(spotifyURI: "spotify:track:4gphxUgq0JSFv2BCLhNDiE"))
        #expect(url?.absoluteString == "https://open.spotify.com/track/4gphxUgq0JSFv2BCLhNDiE")
    }

    @Test func tidalIsSearchFallback() {
        let url = StreamingService.tidal.url(for: Self.entry(artist: "R.E.M.", title: "Nightswimming"))?.absoluteString ?? ""
        #expect(url.hasPrefix("https://tidal.com/search?q="))
        #expect(url.contains("Nightswimming"))
    }

    @Test func ytMusicIsSearchFallback() {
        let url = StreamingService.ytMusic.url(for: Self.entry(artist: "R.E.M.", title: "Nightswimming"))?.absoluteString ?? ""
        #expect(url.hasPrefix("https://music.youtube.com/search?q="))
        #expect(url.contains("Nightswimming"))
    }

    @Test func allCasesCoverFour() {
        #expect(StreamingService.allCases.count == 4)
    }

    @Test func openInRowShowsSaveOnlyWhenServiceCanSave() {
        #expect(OpenInRowState(canSaveToLibrary: true, isSaved: false).showsSaveButton)
        #expect(!OpenInRowState(canSaveToLibrary: false, isSaved: false).showsSaveButton)
    }

    @Test func openInRowSavedStateUsesAddedIconAndDisablesSave() {
        let state = OpenInRowState(canSaveToLibrary: true, isSaved: true)

        #expect(state.showsSaveButton)
        #expect(state.saveIconName == "checkmark.circle.fill")
        #expect(state.isSaveDisabled)
    }

    @Test func openInRowUnsavedStateUsesAddIconAndAllowsSave() {
        let state = OpenInRowState(canSaveToLibrary: true, isSaved: false)

        #expect(state.saveIconName == "plus.circle")
        #expect(!state.isSaveDisabled)
    }
}
