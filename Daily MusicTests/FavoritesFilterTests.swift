import Testing
import Foundation
@testable import Daily_Music

struct FavoritesFilterTests {
    static func entry(_ i: Int, title: String = "", artist: String = "",
                      genre: String? = nil, year: Int? = nil, mood: String? = nil) -> DailyEntry {
        DailyEntry(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i))!,
            date: Date(timeIntervalSince1970: TimeInterval(i) * 86_400),
            title: title.isEmpty ? "T\(i)" : title,
            artist: artist.isEmpty ? "A\(i)" : artist,
            albumArtURL: nil, journalMarkdown: "",
            appleMusicID: "\(i)", spotifyURI: "spotify:track:\(i)",
            genre: genre, year: year, mood: mood
        )
    }

    @Test func emptyFilterMatchesEverythingAndIsInactive() {
        let f = FavoritesFilter()
        #expect(f.isActive == false)
        #expect(f.hasFacetFilters == false)
        #expect(f.matches(Self.entry(1)) == true)
    }

    @Test func queryMatchesTitleOrArtistCaseInsensitively() {
        var f = FavoritesFilter(); f.query = "BLON"
        #expect(f.matches(Self.entry(1, title: "Blonde", artist: "X")) == true)
        var g = FavoritesFilter(); g.query = "drake"
        #expect(g.matches(Self.entry(2, title: "Y", artist: "Drake")) == true)
        #expect(g.matches(Self.entry(3, title: "Y", artist: "Z")) == false)
    }

    @Test func singleDimensionConstrainsAndNilIsExcluded() {
        var f = FavoritesFilter(); f.genres = ["Pop"]
        #expect(f.matches(Self.entry(1, genre: "Pop")) == true)
        #expect(f.matches(Self.entry(2, genre: "Rock")) == false)
        #expect(f.matches(Self.entry(3, genre: nil)) == false)
    }

    @Test func dimensionsAndTogetherValuesOrWithin() {
        var f = FavoritesFilter()
        f.genres = ["Pop", "Rock"]
        f.decades = ["1980s"]
        #expect(f.matches(Self.entry(1, genre: "Pop", year: 1985)) == true)
        #expect(f.matches(Self.entry(2, genre: "Rock", year: 1985)) == true)
        #expect(f.matches(Self.entry(3, genre: "Pop", year: 1995)) == false) // decade fails
        #expect(f.matches(Self.entry(4, genre: "Jazz", year: 1985)) == false) // genre fails
    }

    @Test func facetsAreDistinctNonEmptySorted() {
        let favs = [
            Self.entry(1, genre: "Pop", year: 1985, mood: "Dreamy"),
            Self.entry(2, genre: "Pop", year: 1995, mood: nil),
            Self.entry(3, genre: "Rock", year: nil, mood: "Dreamy"),
        ]
        let facets = favoritesFacets(in: favs)
        #expect(facets.genres == ["Pop", "Rock"])
        #expect(facets.decades == ["1980s", "1990s"])
        #expect(facets.moods == ["Dreamy"])
    }
}
