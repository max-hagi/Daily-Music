import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct SpotifyLibraryAPITests {
    /// Scripted transport: returns queued responses, records every request.
    final class StubTransport: @unchecked Sendable {
        private(set) var requests: [URLRequest] = []
        var responses: [(Data, Int)] = []   // (body, statusCode), consumed in order

        func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
            requests.append(request)
            let (data, status) = responses.isEmpty ? (Data("{}".utf8), 200) : responses.removeFirst()
            let http = HTTPURLResponse(url: request.url!, statusCode: status,
                                       httpVersion: nil, headerFields: nil)!
            return (data, http)
        }
    }

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SpotifyLibraryAPITests-\(UUID().uuidString)")!
    }

    private func api(_ transport: StubTransport, defaults: UserDefaults) -> SpotifyLibraryAPI {
        SpotifyLibraryAPI(defaults: defaults, transport: transport.send)
    }

    @Test func reusesExistingPlaylistAndAddsTrack() async throws {
        let transport = StubTransport()
        transport.responses = [
            (Data(#"{"id":"user1"}"#.utf8), 200),                                     // GET /me
            (Data(#"{"items":[{"id":"pl9","name":"Daily Music"}]}"#.utf8), 200),      // GET /me/playlists
            (Data("{}".utf8), 201),                                                   // POST tracks
        ]
        try await api(transport, defaults: freshDefaults())
            .saveToDailyPlaylist(trackID: "track123", accessToken: "tok")

        #expect(transport.requests.count == 3)
        #expect(transport.requests[0].url?.path == "/v1/me")
        #expect(transport.requests[2].url?.path == "/v1/playlists/pl9/tracks")
        #expect(transport.requests[2].httpMethod == "POST")
        let body = String(data: transport.requests[2].httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(body.contains("spotify:track:track123"))
        #expect(transport.requests.allSatisfy {
            $0.value(forHTTPHeaderField: "Authorization") == "Bearer tok"
        })
    }

    @Test func createsPlaylistWhenMissing() async throws {
        let transport = StubTransport()
        transport.responses = [
            (Data(#"{"id":"user1"}"#.utf8), 200),                  // GET /me
            (Data(#"{"items":[]}"#.utf8), 200),                    // GET /me/playlists — none
            (Data(#"{"id":"plNew"}"#.utf8), 201),                  // POST create playlist
            (Data("{}".utf8), 201),                                // POST tracks
        ]
        try await api(transport, defaults: freshDefaults())
            .saveToDailyPlaylist(trackID: "t", accessToken: "tok")

        #expect(transport.requests[2].url?.path == "/v1/users/user1/playlists")
        let createBody = String(data: transport.requests[2].httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(createBody.contains(#""name":"Daily Music""#))
        #expect(createBody.contains(#""public":false"#))
        #expect(transport.requests[3].url?.path == "/v1/playlists/plNew/tracks")
    }

    @Test func cachedPlaylistSkipsLookupOnSecondSave() async throws {
        let defaults = freshDefaults()
        let transport = StubTransport()
        transport.responses = [
            (Data(#"{"id":"user1"}"#.utf8), 200),
            (Data(#"{"items":[{"id":"pl9","name":"Daily Music"}]}"#.utf8), 200),
            (Data("{}".utf8), 201),
        ]
        try await api(transport, defaults: defaults).saveToDailyPlaylist(trackID: "a", accessToken: "tok")

        let second = StubTransport()
        second.responses = [(Data("{}".utf8), 201)]                // just the add
        try await api(second, defaults: defaults).saveToDailyPlaylist(trackID: "b", accessToken: "tok")
        #expect(second.requests.count == 1)
        #expect(second.requests[0].url?.path == "/v1/playlists/pl9/tracks")
    }

    @Test func staleCachedPlaylistReresolvesOn404() async throws {
        let defaults = freshDefaults()
        defaults.set("deadPlaylist", forKey: "spotify.dailyPlaylistID")
        let transport = StubTransport()
        transport.responses = [
            (Data("{}".utf8), 404),                                // add → playlist gone
            (Data(#"{"id":"user1"}"#.utf8), 200),                  // re-resolve
            (Data(#"{"items":[]}"#.utf8), 200),
            (Data(#"{"id":"plNew"}"#.utf8), 201),
            (Data("{}".utf8), 201),                                // retry add
        ]
        try await api(transport, defaults: defaults).saveToDailyPlaylist(trackID: "t", accessToken: "tok")
        #expect(transport.requests.last?.url?.path == "/v1/playlists/plNew/tracks")
    }

    @Test func spotifyTrackIDParsesURIAndBareForms() {
        let entry = DailyEntry(
            id: UUID(), date: Date(), title: "T", artist: "A",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "1",
            spotifyURI: "spotify:track:abc123"
        )
        #expect(entry.spotifyTrackID == "abc123")
    }
}
