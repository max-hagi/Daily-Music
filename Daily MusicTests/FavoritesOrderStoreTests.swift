import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct FavoritesOrderStoreTests {
    /// A throwaway UserDefaults suite so tests never touch real storage or each other.
    static func freshDefaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    static func entry(_ i: Int) -> DailyEntry {
        DailyEntry(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i))!,
            date: Date(timeIntervalSince1970: TimeInterval(i) * 86_400),
            title: "T\(i)", artist: "A\(i)",
            albumArtURL: nil, journalMarkdown: "",
            appleMusicID: "\(i)", spotifyURI: "spotify:track:\(i)"
        )
    }

    @Test func noSavedOrderReturnsInputUnchanged() {
        let store = FavoritesOrderStore(defaults: Self.freshDefaults())
        let favs = [Self.entry(3), Self.entry(2), Self.entry(1)]
        #expect(store.arranged(favs).map(\.id) == favs.map(\.id))
    }

    @Test func savedOrderIsRespected() {
        let store = FavoritesOrderStore(defaults: Self.freshDefaults())
        let a = Self.entry(1), b = Self.entry(2), c = Self.entry(3)
        store.commit([c.id, a.id, b.id])
        #expect(store.arranged([a, b, c]).map(\.id) == [c.id, a.id, b.id])
    }

    @Test func newFavoriteAppearsOnTop() {
        let store = FavoritesOrderStore(defaults: Self.freshDefaults())
        let a = Self.entry(1), b = Self.entry(2)
        store.commit([a.id, b.id])
        let c = Self.entry(3) // newly hearted, not in saved order
        #expect(store.arranged([c, a, b]).map(\.id) == [c.id, a.id, b.id])
    }

    @Test func removedFavoriteIsDropped() {
        let store = FavoritesOrderStore(defaults: Self.freshDefaults())
        let a = Self.entry(1), b = Self.entry(2), c = Self.entry(3)
        store.commit([a.id, b.id, c.id])
        #expect(store.arranged([a, c]).map(\.id) == [a.id, c.id]) // b un-hearted
    }

    @Test func commitPersistsAcrossInstances() {
        let defaults = Self.freshDefaults()
        let a = Self.entry(1), b = Self.entry(2)
        FavoritesOrderStore(defaults: defaults).commit([b.id, a.id])
        let reloaded = FavoritesOrderStore(defaults: defaults)
        #expect(reloaded.arranged([a, b]).map(\.id) == [b.id, a.id])
    }
}
