import Testing
import Foundation
@testable import Daily_Music

struct KeychainStoreTests {
    private func freshStore() -> KeychainStore {
        KeychainStore(service: "tests.spotify-\(UUID().uuidString)")
    }

    @Test func roundTripsData() throws {
        let store = freshStore()
        let payload = Data("hello".utf8)
        try store.set(payload, for: "tokens")
        #expect(store.data(for: "tokens") == payload)
    }

    @Test func overwritesExistingValue() throws {
        let store = freshStore()
        try store.set(Data("one".utf8), for: "tokens")
        try store.set(Data("two".utf8), for: "tokens")
        #expect(store.data(for: "tokens") == Data("two".utf8))
    }

    @Test func deleteRemovesValueAndMissingReadsAreNil() throws {
        let store = freshStore()
        #expect(store.data(for: "tokens") == nil)
        try store.set(Data("x".utf8), for: "tokens")
        store.delete("tokens")
        #expect(store.data(for: "tokens") == nil)
    }
}
