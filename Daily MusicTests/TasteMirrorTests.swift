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

    @Test func moodDominantIsMostNetPositive() {
        // Worked example: Melancholy net=7, Tender net=3 — Melancholy wins either way.
        // The net-score-beats-raw-likes case is covered by moodNetScoreBeatRawLikes below.
        let m = TasteMirror.build(from: Self.workedExample())
        #expect(m.mood.dominant?.name == "Melancholy")
        #expect(m.mood.dominant?.likes == 9)
    }

    @Test func moodNetScoreBeatRawLikes() {
        // A: 5 likes, 0 dislikes → net 5
        // B: 7 likes, 5 dislikes → net 2  (raw-likes winner but net loser)
        // C: 5 likes, 3 dislikes → net 2  (padding, makes dimension eligible)
        let data: [RatedSong] =
            (0..<5).map { RatedSong(entry: Self.entry(id: $0,       mood: "A"), value:  1) }
          + (0..<7).map { RatedSong(entry: Self.entry(id: 100+$0,   mood: "B"), value:  1) }
          + (0..<5).map { RatedSong(entry: Self.entry(id: 200+$0,   mood: "B"), value: -1) }
          + (0..<5).map { RatedSong(entry: Self.entry(id: 300+$0,   mood: "C"), value:  1) }
          + (0..<3).map { RatedSong(entry: Self.entry(id: 400+$0,   mood: "C"), value: -1) }
        let m = TasteMirror.build(from: data)
        #expect(m.mood.dominant?.name == "A")   // net 5, not raw-likes winner B (7)
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

    @Test func dimensionLocksBelowMinimumRatings() {
        let data = Self.mood("Melancholy", likes: 4, dislikes: 2) // 6 < 10
        let m = TasteMirror.build(from: data)
        #expect(m.mood.isUnlocked == false)
    }

    @Test func energyLeanFromLikedSongs() {
        // Liked energies 1,2,3 → mean 2.0 → "Intimate"; disliked energy ignored.
        let liked = [1, 2, 3].map { RatedSong(entry: Self.entry(id: 900 + $0, energy: $0), value: 1) }
        let disliked = [RatedSong(entry: Self.entry(id: 950, energy: 5), value: -1)]
        let pad = (0..<8).map { RatedSong(entry: Self.entry(id: 960 + $0, energy: 2), value: $0.isMultiple(of: 2) ? 1 : -1) }
        let m = TasteMirror.build(from: liked + disliked + pad)
        #expect(m.energy.leanLabel == "Intimate")
        #expect(m.energy.likedMean != nil)
    }

    @Test func topStandoutPrefersOverIndexThenDominant() {
        let m = TasteMirror.build(from: Self.workedExample())
        #expect(m.mood.topStandout?.name == "Melancholy")   // over-index present
        #expect(m.decade.topStandout?.name == "1980s")       // dominant fallback
    }

    @Test func archetypeUnlocksWithEnoughRatings() {
        let m = TasteMirror.build(from: Self.workedExample())   // 30 ratings ≥ 10 → unlocked
        #expect(m.isArchetypeUnlocked == true)
        #expect(m.archetype?.id == "MELANCHOLY_1980S")
    }

    @Test func archetypeNilBelowThreshold() {
        let m = TasteMirror.build(from: Self.mood("Melancholy", likes: 6, dislikes: 2, year: 1985))  // 8 < 10
        #expect(m.isArchetypeUnlocked == false)
        #expect(m.archetype == nil)
    }

    @Test func archetypeFallsBackToMoodOnly() {
        // 24 melancholy songs, no year → no decade standout → mood-only default.
        let m = TasteMirror.build(from: Self.mood("Melancholy", likes: 18, dislikes: 6))
        #expect(m.archetype?.id == "MELANCHOLY_DEFAULT")
    }
}

struct TasteComparisonTests {
    func e(_ i: Int) -> DailyEntry { TasteMirrorTests.entry(id: i) }
    func id(_ i: Int) -> UUID { e(i).id }

    @Test func matchPercentCountsAgreementOnCoRated() {
        // Shared = {0,1,2,3}; agree on 0,1,2; clash on 3 → 3/4 = 75%.
        let mine:   [UUID: Int] = [id(0): 1, id(1): -1, id(2): 1, id(3): 1, id(4): 1]
        let theirs: [UUID: Int] = [id(0): 1, id(1): -1, id(2): 1, id(3): -1, id(9): 1]
        let history = (0...9).map { e($0) }
        let c = TasteComparison.build(mine: mine, theirs: theirs, history: history)
        #expect(c.coRatedCount == 4)
        #expect(c.agreedCount == 3)
        #expect(c.matchPercent == 75)
    }

    @Test func bothLovedAndClashedPartition() {
        let mine:   [UUID: Int] = [id(0): 1, id(1): 1, id(2): -1, id(3): 1]
        let theirs: [UUID: Int] = [id(0): 1, id(1): -1, id(2): -1, id(3): 1]
        let history = (0...3).map { e($0) }
        let c = TasteComparison.build(mine: mine, theirs: theirs, history: history)
        #expect(c.bothLoved.map({ $0.id }) == [id(0), id(3)])   // both 👍
        #expect(c.clashed.map({ $0.id }) == [id(1)])            // 👍 vs 👎 (id2 = both 👎 → neither list)
    }

    @Test func matchPercentNilBelowMinShared() {
        let mine:   [UUID: Int] = [id(0): 1, id(1): 1]
        let theirs: [UUID: Int] = [id(0): 1, id(1): 1]     // only 2 shared (< minShared)
        let c = TasteComparison.build(mine: mine, theirs: theirs, history: [e(0), e(1)])
        #expect(c.coRatedCount == 2)
        #expect(c.matchPercent == nil)
    }

    @Test func emptyInputsYieldZeros() {
        let c = TasteComparison.build(mine: [:], theirs: [:], history: [])
        #expect(c.coRatedCount == 0)
        #expect(c.agreedCount == 0)
        #expect(c.matchPercent == nil)
        #expect(c.bothLoved.isEmpty)
        #expect(c.clashed.isEmpty)
    }
}
