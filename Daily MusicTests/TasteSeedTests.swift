import Testing
import Foundation
@testable import Daily_Music

struct TasteSeedTests {
    // Every starter song appears exactly once across the 7 rounds.
    @Test func roundsCoverAllSongsOnce() {
        let rounds = StarterPack.rounds()
        #expect(rounds.count == 7)
        let used = rounds.flatMap { [$0.0.id, $0.1.id] }
        #expect(used.count == 14)
        #expect(Set(used).count == 14)   // no duplicates
        #expect(Set(used) == Set(StarterPack.songs.map(\.id)))
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
}
