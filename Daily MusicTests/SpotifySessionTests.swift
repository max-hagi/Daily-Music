import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct SpotifySessionTests {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SpotifySessionTests-\(UUID().uuidString)")!
    }

    private func sampleEntry() -> DailyEntry {
        DailyEntry(
            id: UUID(), date: Date(), title: "Nobody", artist: "Mitski",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "123",
            spotifyURI: "spotify:track:abc"
        )
    }

    /// Records save calls so tests can assert what reached the API layer.
    /// Only touched from the session's MainActor save closure.
    final class SaveRecorder: @unchecked Sendable {
        var trackIDs: [String] = []
        var error: Error?
    }

    private func makeSession(
        auth: MockSpotifyAuthenticator,
        recorder: SaveRecorder = SaveRecorder()
    ) -> SpotifySession {
        SpotifySession(authenticator: auth, defaults: freshDefaults()) { trackID, _ in
            if let error = recorder.error { throw error }
            recorder.trackIDs.append(trackID)
        }
    }

    @Test func startsNotConnected() {
        let session = makeSession(auth: MockSpotifyAuthenticator())
        #expect(session.status == .notConnected)
    }

    @Test func connectGrantsLibrarySave() async {
        let session = makeSession(auth: MockSpotifyAuthenticator())
        await session.connect()
        #expect(session.status == .connected([.librarySave]))
    }

    @Test func cancelledLoginStaysNotConnectedQuietly() async {
        let auth = MockSpotifyAuthenticator()
        auth.authorizeError = .cancelled
        let session = makeSession(auth: auth)
        await session.connect()
        #expect(session.status == .notConnected)
    }

    @Test func restoreConnectsWhenTokensStored() async {
        let session = makeSession(auth: MockSpotifyAuthenticator(hasStoredTokens: true))
        await session.restore()
        #expect(session.status == .connected([.librarySave]))
    }

    @Test func restoreStaysDisconnectedWithoutTokens() async {
        let session = makeSession(auth: MockSpotifyAuthenticator(hasStoredTokens: false))
        await session.restore()
        #expect(session.status == .notConnected)
    }

    @Test func disconnectClearsTokens() async {
        let auth = MockSpotifyAuthenticator()
        let session = makeSession(auth: auth)
        await session.connect()
        session.disconnect()
        #expect(session.status == .notConnected)
        #expect(auth.clearCount == 1)
        #expect(!auth.hasStoredTokens)
    }

    @Test func saveSendsParsedTrackID() async throws {
        let recorder = SaveRecorder()
        let session = makeSession(auth: MockSpotifyAuthenticator(hasStoredTokens: true), recorder: recorder)
        await session.restore()
        try await session.saveToLibrary(sampleEntry())
        #expect(recorder.trackIDs == ["abc"])
    }

    @Test func revokedRefreshDowngradesAndRethrows() async {
        let auth = MockSpotifyAuthenticator(hasStoredTokens: true)
        auth.tokenError = .needsReconnect
        let session = makeSession(auth: auth)
        await session.restore()
        #expect(session.status == .connected([.librarySave]))

        await #expect(throws: SpotifyAuthError.needsReconnect) {
            try await session.saveToLibrary(sampleEntry())
        }
        #expect(session.status == .notConnected)
        #expect(auth.clearCount == 1)   // dead tokens wiped
    }
}
