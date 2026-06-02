import Testing
import Foundation
@testable import Daily_Music

struct TasteMirrorTests {

    // MARK: helpers

    /// Build a DailyEntry carrying only the tags a test cares about. (Entry id is
    /// irrelevant to the math — the engine counts each RatedSong in the array.)
    static func entry(
        id: Int,
        mood: String? = nil, year: Int? = nil, theme: String? = nil,
        energy: Int? = nil, genre: String? = nil, language: String? = nil
    ) -> DailyEntry {
        DailyEntry(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            date: Date(timeIntervalSince1970: TimeInterval(id) * 86_400),
            title: "T\(id)", artist: "A\(id)",
            albumArtURL: nil, journalMarkdown: "",
            appleMusicID: "\(id)", spotifyURI: "spotify:track:\(id)",
            genre: genre, year: year, mood: mood, energy: energy,
            theme: theme, language: language
        )
    }

    /// `likes` 👍 and `dislikes` 👎 songs of one mood (and optional year).
    static func mood(_ name: String, likes: Int, dislikes: Int, year: Int? = nil) -> [RatedSong] {
        var out: [RatedSong] = []
        for _ in 0..<likes    { out.append(RatedSong(entry: entry(id: 1, mood: name, year: year), value: 1)) }
        for _ in 0..<dislikes { out.append(RatedSong(entry: entry(id: 1, mood: name, year: year), value: -1)) }
        return out
    }

    /// §5 worked example: 18 👍 / 12 👎 across five moods → overall 0.6.
    static func workedExample() -> [RatedSong] {
        mood("Melancholy", likes: 9, dislikes: 2, year: 1985)
        + mood("Tender",   likes: 4, dislikes: 1)
        + mood("Dreamy",   likes: 2, dislikes: 2)
        + mood("Euphoric", likes: 2, dislikes: 5)
        + mood("Defiant",  likes: 1, dislikes: 2)
    }

    // MARK: tests

    @Test func overallLikeRateMatchesWorkedExample() {
        let m = TasteMirror.build(from: Self.workedExample())
        #expect(m.totalRated == 30)
        #expect(abs(m.overallLikeRate - 0.6) < 0.0001)
    }

    @Test func moodDominantIsMostLiked() {
        let m = TasteMirror.build(from: Self.workedExample())
        #expect(m.mood.dominant?.name == "Melancholy")
        #expect(m.mood.dominant?.likes == 9)
    }

    @Test func moodOverIndexIsHighestRateAboveOverall() {
        // Overall 0.6; eligible >0.70. Melancholy .818, Tender .80 → highest wins.
        let m = TasteMirror.build(from: Self.workedExample())
        #expect(m.mood.overIndex?.name == "Melancholy")
    }

    @Test func moodSkipIsLowestRateBelowOverall() {
        let m = TasteMirror.build(from: Self.workedExample())
        #expect(m.mood.skip?.name == "Euphoric")
    }

    @Test func smallCategoriesAreIneligibleForStandouts() {
        // "Serene" has only 2 ratings (< minPerCategory) at a perfect rate; it must
        // NOT become the over-index, but must still be listed.
        let data = Self.workedExample() + Self.mood("Serene", likes: 2, dislikes: 0)
        let m = TasteMirror.build(from: data)
        #expect(m.mood.overIndex?.name == "Melancholy")
        #expect(m.mood.categories.contains { $0.name == "Serene" })
    }
}
