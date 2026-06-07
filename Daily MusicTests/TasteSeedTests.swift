import Testing
import Foundation
@testable import Daily_Music

struct TasteSeedTests {
    @Test func starterPackHasTenUniqueSongs() {
        #expect(StarterPack.songs.count == 10)
        #expect(Set(StarterPack.songs.map(\.id)).count == 10)
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
        SeedRatings.clear()
        let picks = [
            RatedSong(entry: entry(mood: "Dreamy", genre: "Alternative", year: 2015), value: 1),
            RatedSong(entry: entry(mood: "Defiant", genre: "Rock", year: 1991), value: -1),
        ]
        SeedRatings.save(picks)
        let loaded = SeedRatings.load()
        #expect(loaded.count == 2)
        #expect(loaded.first?.value == 1)
        SeedRatings.clear()
        #expect(SeedRatings.load().isEmpty)
    }
}
