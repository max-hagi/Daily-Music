import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct ProfileStoreTests {
    @Test func saveThenCurrentReflectsName() async throws {
        let store = ProfileStore(service: MockProfileService())
        await store.load()
        try await store.save(displayName: "Maxime", avatarURL: nil)
        #expect(store.current?.displayName == "Maxime")
    }

    @Test func uploadReturnsURLString() async throws {
        let store = ProfileStore(service: MockProfileService())
        let url = try await store.uploadAvatar(Data([0x1, 0x2]))
        #expect(url.hasPrefix("mock://avatar/"))
    }
}
