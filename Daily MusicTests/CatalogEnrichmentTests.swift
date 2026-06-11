import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct CatalogEnrichmentTests {
    struct StubBase: CatalogInfoService {
        func info(appleMusicID: String) async throws -> CatalogInfo {
            CatalogInfo(album: "Puberty 2", releaseYear: "2016", durationSeconds: 193,
                        genre: "Alternative", albumURL: nil, previewURL: nil)
        }
    }

    private func session(connected: Bool) async -> AppleMusicSession {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(subscribed: false),  // .richMetadata only
            defaults: UserDefaults(suiteName: "CatalogEnrichmentTests-\(UUID().uuidString)")!
        )
        if connected { await session.connect() }
        return session
    }

    @Test func notConnectedReturnsBaseInfoAndSkipsExtras() async throws {
        var extrasCalls = 0
        let service = EnrichedCatalogInfoService(
            base: StubBase(), session: await session(connected: false),
            fetchExtras: { _ in extrasCalls += 1; return nil }
        )
        let info = try await service.info(appleMusicID: "123")
        #expect(extrasCalls == 0)
        #expect(info.editorialNotes == nil)
        #expect(info.album == "Puberty 2")   // base facts untouched
    }

    @Test func connectedMergesExtrasOntoBaseInfo() async throws {
        let service = EnrichedCatalogInfoService(
            base: StubBase(), session: await session(connected: true),
            fetchExtras: { _ in
                CatalogExtras(editorialNotes: "A fuzzed-out meditation on joy.",
                              hiResArtworkURL: URL(string: "https://example.com/art.jpg"))
            }
        )
        let info = try await service.info(appleMusicID: "123")
        #expect(info.editorialNotes == "A fuzzed-out meditation on joy.")
        #expect(info.hiResArtworkURL == URL(string: "https://example.com/art.jpg"))
        #expect(info.album == "Puberty 2")
    }

    @Test func extrasFailureStillReturnsBaseInfo() async throws {
        let service = EnrichedCatalogInfoService(
            base: StubBase(), session: await session(connected: true),
            fetchExtras: { _ in nil }   // MusicKit fetch failed
        )
        let info = try await service.info(appleMusicID: "123")
        #expect(info.editorialNotes == nil)
        #expect(info.album == "Puberty 2")
    }
}
