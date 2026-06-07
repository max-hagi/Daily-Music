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

    @Test func freshProfileIsNotOnboarded() async throws {
        let store = ProfileStore(service: MockProfileService())
        await store.load()
        #expect(store.isOnboarded == false)
        #expect(store.current?.onboardedAt == nil)
    }

    @Test func markOnboardedFlipsIsOnboarded() async throws {
        let store = ProfileStore(service: MockProfileService())
        await store.load()
        try await store.markOnboarded()
        #expect(store.isOnboarded)
        #expect(store.current?.onboardedAt != nil)
    }

    @Test func markOnboardedIsSetOnce() async throws {
        let store = ProfileStore(service: MockProfileService())
        await store.load()
        try await store.markOnboarded()
        let first = store.current?.onboardedAt
        try await store.markOnboarded()
        // A second call must not move the original timestamp.
        #expect(store.current?.onboardedAt == first)
    }
}
