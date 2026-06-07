import Testing
import Foundation
@testable import Daily_Music

struct CatalogInfoTests {
    @Test func parsesITunesLookupPayload() {
        let json = """
        {"resultCount":1,"results":[{"collectionName":"Automatic for the People","releaseDate":"1992-10-05T07:00:00Z","trackTimeMillis":257000,"primaryGenreName":"Alternative","collectionViewUrl":"https://music.apple.com/us/album/automatic-for-the-people/1440947547"}]}
        """.data(using: .utf8)!
        let info = CatalogInfo.parse(json)
        #expect(info?.album == "Automatic for the People")
        #expect(info?.releaseYear == "1992")
        #expect(info?.durationSeconds == 257)
        #expect(info?.genre == "Alternative")
        #expect(info?.albumURL?.absoluteString == "https://music.apple.com/us/album/automatic-for-the-people/1440947547")
    }

    @Test func parseReturnsNilOnEmptyResults() {
        let json = #"{"resultCount":0,"results":[]}"#.data(using: .utf8)!
        #expect(CatalogInfo.parse(json) == nil)
    }

    @Test func parseExtractsPreviewURL() {
        let json = """
        {"results":[{"collectionName":"Be the Cowboy","releaseDate":"2018-08-17T12:00:00Z","trackTimeMillis":150000,"primaryGenreName":"Indie Rock","collectionViewUrl":"https://music.apple.com/album/x","previewUrl":"https://audio-ssl.itunes.apple.com/clip.m4a"}]}
        """.data(using: .utf8)!
        let info = CatalogInfo.parse(json)
        #expect(info?.previewURL == URL(string: "https://audio-ssl.itunes.apple.com/clip.m4a"))
    }
}
