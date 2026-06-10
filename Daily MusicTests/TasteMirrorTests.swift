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

    @Test func moodDominantWorkedExample() {
        // Melancholy net=7, Tender net=3 — winner is the same under both old and new sorts.
        // See moodNetScoreBeatRawLikes for the discriminating case.
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
        // Worked example: Melancholy dominant → the_melancholic (modifier is flavor text only).
        let m = TasteMirror.build(from: Self.workedExample())
        #expect(m.isArchetypeUnlocked == true)
        #expect(m.archetype?.id == "the_melancholic")
    }

    @Test func archetypeNilBelowThreshold() {
        let m = TasteMirror.build(from: Self.mood("Melancholy", likes: 6, dislikes: 2, year: 1985))  // 8 < 10
        #expect(m.isArchetypeUnlocked == false)
        #expect(m.archetype == nil)
    }

    @Test func archetypeFallsBackToMoodOnly() {
        // 24 melancholy songs, no year → no decade standout → mood-only lookup.
        let m = TasteMirror.build(from: Self.mood("Melancholy", likes: 18, dislikes: 6))
        #expect(m.archetype?.id == "the_melancholic")
    }

    @Test func ratedSongsStoredOnMirror() {
        let data = Self.workedExample()
        let m = TasteMirror.build(from: data)
        #expect(m.ratedSongs.count == data.count)
    }

    @Test func modifierSelectorPicksHighestMargin() {
        // Decade "1980s": 9/11 = 81.8% (margin +21.8pp above 60% overall)
        // No theme/genre over-index in worked example → decade wins.
        let m = TasteMirror.build(from: Self.workedExample())
        #expect(m.winningModifier?.dimensionID == "decade")
        #expect(m.winningModifier?.categoryName == "1980s")
    }

    @Test func modifierSelectorPrefersThemeOverDecadeWhenMarginHigher() {
        // 30 songs: give Heartbreak theme a higher over-index margin than decade.
        // Heartbreak: 9 liked, 0 disliked → 100% (margin +40pp above 60% overall)
        // Decade 1980s: 9 liked, 2 disliked → 81.8% (margin +21.8pp above 60% overall)
        let heartbreak: [RatedSong] = (0..<9).map {
            RatedSong(entry: Self.entry(id: 500+$0, mood: "Melancholy", year: 1985, theme: "Heartbreak"), value: 1)
        }
        let other = Self.mood("Tender", likes: 4, dislikes: 1)
                  + Self.mood("Dreamy", likes: 2, dislikes: 2)
                  + Self.mood("Euphoric", likes: 2, dislikes: 5)
                  + Self.mood("Defiant", likes: 1, dislikes: 2)
                  + (0..<2).map { RatedSong(entry: Self.entry(id: 600+$0, mood: "Melancholy", year: 1985), value: -1) }
        let m = TasteMirror.build(from: heartbreak + other)
        // theme "Heartbreak" margin (40pp) > decade "1980s" margin (21.8pp)
        #expect(m.winningModifier?.dimensionID == "theme")
        #expect(m.winningModifier?.categoryName == "Heartbreak")
    }

    @Test func modifierNilWhenNoOverIndex() {
        // All songs same mood, no year/theme/genre → no dimension over-indexes.
        let data = Self.mood("Melancholy", likes: 18, dislikes: 6)
        let m = TasteMirror.build(from: data)
        #expect(m.winningModifier == nil)
    }

    @Test func songsFilteredByDimensionCategory() {
        // 9 Melancholy/1980s + 2 Melancholy/1980s disliked + other moods.
        let data = Self.workedExample()
        let m = TasteMirror.build(from: data)
        let melancholySongs = m.songs(inDimension: m.mood, category: "Melancholy")
        // 9 liked + 2 disliked = 11 Melancholy songs; liked come first.
        #expect(melancholySongs.count == 11)
        #expect(melancholySongs.first?.value == 1)   // liked first
    }

    @Test func songsSecondaryDateSortIsReverseChronological() {
        // Within the same rating group (all liked), songs should be newest first.
        // entry(id:) derives date from TimeInterval(id) * 86_400 → higher id = later date.
        let data: [RatedSong] = [
            RatedSong(entry: Self.entry(id: 10, mood: "Dreamy"), value: 1),  // oldest liked
            RatedSong(entry: Self.entry(id: 30, mood: "Dreamy"), value: 1),  // newest liked
            RatedSong(entry: Self.entry(id: 20, mood: "Dreamy"), value: 1),  // middle liked
            RatedSong(entry: Self.entry(id: 25, mood: "Dreamy"), value: -1), // disliked
        ]
        // Pad to unlock the dimension (needs ≥10 total rated)
        let pad = (0..<7).map { RatedSong(entry: Self.entry(id: 100+$0, mood: "Serene"), value: 1) }
        let m = TasteMirror.build(from: data + pad)
        let songs = m.songs(inDimension: m.mood, category: "Dreamy")
        // 3 liked (newest first), then 1 disliked
        #expect(songs.count == 4)
        #expect(songs[0].entry.id == Self.entry(id: 30, mood: "Dreamy").id)  // newest liked
        #expect(songs[1].entry.id == Self.entry(id: 20, mood: "Dreamy").id)  // middle liked
        #expect(songs[2].entry.id == Self.entry(id: 10, mood: "Dreamy").id)  // oldest liked
        #expect(songs[3].value == -1)                                          // disliked last
    }

    // MARK: engine v2 — RatedSong fields

    @Test func ratedSongDecodesLegacyJSONWithoutNewFields() throws {
        // Pre-v2 persisted seed payloads have only `entry` + `value`.
        let legacy = RatedSong(entry: Self.entry(id: 1, mood: "Serene"), value: 1)
        var json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(legacy)) as! [String: Any]
        json.removeValue(forKey: "isFavorite")
        json.removeValue(forKey: "ratedAt")
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(RatedSong.self, from: data)
        #expect(decoded.value == 1)
        #expect(decoded.isFavorite == false)
        #expect(decoded.ratedAt == nil)
    }

    @Test func effectiveRatedAtFallsBackToEntryDate() {
        let e = Self.entry(id: 7)
        #expect(RatedSong(entry: e, value: 1).effectiveRatedAt == e.date)
        let stamp = Date(timeIntervalSince1970: 99_999)
        #expect(RatedSong(entry: e, value: 1, ratedAt: stamp).effectiveRatedAt == stamp)
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
