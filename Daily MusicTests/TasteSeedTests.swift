import Testing
import Foundation
@testable import Daily_Music

// SeedRatings writes to UserDefaults.standard, so tests must run serially to
// avoid cross-test state pollution. @Suite(.serialized) enforces this.
@Suite(.serialized)
struct TasteSeedTests {
    @Test func starterPackSongsAreUniqueAndPlentiful() {
        // Enough songs to clear the taste-mirror unlock threshold (10), all unique.
        #expect(StarterPack.songs.count >= 10)
        #expect(Set(StarterPack.songs.map(\.id)).count == StarterPack.songs.count)
        #expect(Set(StarterPack.songs.map(\.appleMusicID)).count == StarterPack.songs.count)
    }

    private func entry(mood: String, genre: String, year: Int) -> DailyEntry {
        DailyEntry(id: UUID(), date: .distantPast, title: "t", artist: "a",
                   albumArtURL: nil, journalMarkdown: "", appleMusicID: "0", spotifyURI: "",
                   genre: genre, year: year, mood: mood, energy: 3, theme: "Heartbreak")
    }

    @Test func startingReadPicksDominantMoodAndGenre() {
        let liked = [
            RatedSong(entry: entry(mood: "Melancholy", genre: "Alternative", year: 2015), value: 1),
            RatedSong(entry: entry(mood: "Melancholy", genre: "Alternative", year: 2014), value: 1),
            RatedSong(entry: entry(mood: "Melancholy", genre: "Alternative", year: 2016), value: 1),
            RatedSong(entry: entry(mood: "Euphoric", genre: "Pop", year: 2020), value: 1),
        ]
        let disliked = [
            RatedSong(entry: entry(mood: "Defiant", genre: "Rock", year: 1991), value: -1),
            RatedSong(entry: entry(mood: "Defiant", genre: "Rock", year: 2003), value: -1),
            RatedSong(entry: entry(mood: "Dark", genre: "Hip-Hop/Rap", year: 2017), value: -1),
        ]
        let read = StartingRead.from(picks: liked + disliked)
        #expect(read.mood == "Melancholy")
        #expect(read.genre == "Alternative")
        #expect(!read.isEmpty)
    }

    @Test func emptyPicksGiveEmptyRead() {
        let read = StartingRead.from(picks: [])
        #expect(read.isEmpty)
    }

    @Test func seedRatingsRoundTrip() {
        // Ensure clean state before test
        UserDefaults.standard.removeObject(forKey: "tasteSeedRatings")
        UserDefaults.standard.synchronize()
        SeedRatings.clear()
        UserDefaults.standard.synchronize()

        let picks = [
            RatedSong(entry: entry(mood: "Dreamy", genre: "Alternative", year: 2015), value: 1),
            RatedSong(entry: entry(mood: "Defiant", genre: "Rock", year: 1991), value: -1),
        ]
        SeedRatings.save(picks)
        UserDefaults.standard.synchronize()
        let loaded = SeedRatings.load()
        #expect(loaded.count == 2)
        #expect(loaded.first?.value == 1)
        SeedRatings.clear()
        UserDefaults.standard.synchronize()
        #expect(SeedRatings.load().isEmpty)
        // Clean up after test
        UserDefaults.standard.removeObject(forKey: "tasteSeedRatings")
        UserDefaults.standard.synchronize()
    }

    @Test func seedRatingsMutate_replaceExisting() {
        // Ensure clean state before test
        UserDefaults.standard.removeObject(forKey: "tasteSeedRatings")
        UserDefaults.standard.synchronize()
        SeedRatings.clear()
        UserDefaults.standard.synchronize()

        let e = entry(mood: "Dreamy", genre: "Alternative", year: 2015)
        let rated = RatedSong(entry: e, value: 1)
        SeedRatings.save([rated])
        UserDefaults.standard.synchronize()

        // Simulate the view's "flip to dislike" path: load, mutate index 0, save
        var seeds = SeedRatings.load()
        if !seeds.isEmpty {
            let original = seeds[0]
            seeds[0] = RatedSong(entry: original.entry, value: -1)
            SeedRatings.save(seeds)
            UserDefaults.standard.synchronize()
        }

        let result = SeedRatings.load()
        #expect(result.count == 1)
        #expect(result[0].value == -1)
        SeedRatings.clear()
        UserDefaults.standard.synchronize()
        // Clean up after test
        UserDefaults.standard.removeObject(forKey: "tasteSeedRatings")
        UserDefaults.standard.synchronize()
    }

    @Test func seedRatingsMutate_removeOnClear() {
        // Ensure clean state before test
        UserDefaults.standard.removeObject(forKey: "tasteSeedRatings")
        UserDefaults.standard.synchronize()
        SeedRatings.clear()
        UserDefaults.standard.synchronize()

        let e = entry(mood: "Dreamy", genre: "Alternative", year: 2015)
        let rated = RatedSong(entry: e, value: 1)
        SeedRatings.save([rated])
        UserDefaults.standard.synchronize()

        // Simulate the view's "tap active thumb → clear" path: load, removeAll, save
        var seeds = SeedRatings.load()
        seeds.removeAll()
        SeedRatings.save(seeds)
        UserDefaults.standard.synchronize()

        #expect(SeedRatings.load().isEmpty)
        SeedRatings.clear()
        UserDefaults.standard.synchronize()
        // Clean up after test
        UserDefaults.standard.removeObject(forKey: "tasteSeedRatings")
        UserDefaults.standard.synchronize()
    }

    // MARK: TasteSeedDeck

    private func tinyDeck() -> TasteSeedDeck {
        TasteSeedDeck(songs: [
            entry(mood: "Euphoric", genre: "Pop", year: 2020),
            entry(mood: "Melancholy", genre: "Alternative", year: 2015),
            entry(mood: "Defiant", genre: "Rock", year: 1991),
            entry(mood: "Dreamy", genre: "Alternative", year: 2018),
        ])
    }

    @Test func deckStartsAtFirstSong() {
        let deck = tinyDeck()
        #expect(deck.current?.id == deck.songs[0].id)
        #expect(deck.positionText == "1 of 4")
        #expect(!deck.isComplete)
        #expect(deck.picks.isEmpty)
    }

    @Test func judgingAdvancesAndRecordsThePick() {
        var deck = tinyDeck()
        deck.judge(1)
        #expect(deck.current?.id == deck.songs[1].id)
        #expect(deck.positionText == "2 of 4")
        #expect(deck.picks.count == 1)
        #expect(deck.picks[0].value == 1)
        #expect(deck.picks[0].entry.id == deck.songs[0].id)
    }

    @Test func judgingTheLastSongCompletesTheDeck() {
        var deck = tinyDeck()
        deck.judge(1); deck.judge(-1); deck.judge(1); deck.judge(-1)
        #expect(deck.isComplete)
        #expect(deck.current == nil)
        #expect(deck.picks.count == 4)
        #expect(deck.picks.map(\.value) == [1, -1, 1, -1])
    }

    @Test func judgingPastTheEndIsANoOp() {
        var deck = tinyDeck()
        for _ in 0..<6 { deck.judge(1) }   // 2 extra judgments
        #expect(deck.picks.count == 4)
        #expect(deck.isComplete)
    }

    @Test func upcomingShowsFrontPlusPeekingCards() {
        var deck = tinyDeck()
        #expect(deck.upcoming.map(\.id) == Array(deck.songs.prefix(3)).map(\.id))
        deck.judge(1); deck.judge(1)
        #expect(deck.upcoming.map(\.id) == [deck.songs[2].id, deck.songs[3].id])  // only 2 left
        deck.judge(1); deck.judge(1)
        #expect(deck.upcoming.isEmpty)
    }

    @Test func seedRatingsMutate_insertNew() {
        // Ensure clean state before test
        UserDefaults.standard.removeObject(forKey: "tasteSeedRatings")
        UserDefaults.standard.synchronize()
        SeedRatings.clear()
        UserDefaults.standard.synchronize()

        let e = entry(mood: "Dreamy", genre: "Alternative", year: 2015)
        let rated = RatedSong(entry: e, value: 1)

        // Simulate inserting a previously-unrated seed
        var seeds = SeedRatings.load()
        seeds.append(rated)
        SeedRatings.save(seeds)
        UserDefaults.standard.synchronize()

        let result = SeedRatings.load()
        #expect(result.count == 1)
        #expect(result[0].entry.id == e.id)
        SeedRatings.clear()
        UserDefaults.standard.synchronize()
        // Clean up after test
        UserDefaults.standard.removeObject(forKey: "tasteSeedRatings")
        UserDefaults.standard.synchronize()
    }
}
