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

    @Test func singleCategoryHistoryIsShapeshifter() {
        // Engine v2: every rated song is Melancholy → no contrast between
        // categories → no signature. The Shapeshifter is the honest answer.
        let m = TasteMirror.build(from: Self.mood("Melancholy", likes: 18, dislikes: 6))
        #expect(m.archetype?.id == "the_shapeshifter")
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

    // MARK: engine v2 — mirror API

    @Test func mirrorExposesEvidenceForTheWinner() {
        let m = TasteMirror.build(from: Self.workedExample())
        #expect(m.archetype?.id == "the_melancholic")
        #expect(m.evidence?.facts.first?.category == "Melancholy")
    }

    @Test func heartOnlySongsDoNotInflateTileMath() {
        var data = Self.workedExample()
        data.append(RatedSong(entry: Self.entry(id: 999, mood: "Serene"), value: 0, isFavorite: true))
        let m = TasteMirror.build(from: data)
        #expect(m.totalRated == 30)                       // value-0 excluded
        #expect(!m.ratedSongs.contains { $0.value == 0 }) // drill-downs unchanged
    }

    @Test func mirrorPassesIncumbentThrough() {
        let data = ArchetypeScorerTests.songs(6, value: 1, mood: "Joyful", idBase: 0)
            + ArchetypeScorerTests.songs(2, value: -1, mood: "Joyful", idBase: 50)
            + ArchetypeScorerTests.songs(6, value: 1, mood: "Euphoric", hearts: 1, idBase: 100)
            + ArchetypeScorerTests.songs(2, value: -1, mood: "Euphoric", idBase: 150)
            + ArchetypeScorerTests.songs(6, value: -1, mood: "Dark", idBase: 200)
        #expect(TasteMirror.build(from: data).archetype?.id == "party_animal")
        #expect(TasteMirror.build(from: data, incumbentID: "flower_child").archetype?.id == "flower_child")
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

struct ArchetypeScorerTests {

    /// Entry with controllable tags; date pinned to a fixed base + day offset so
    /// recency tests are deterministic (scorer decays relative to the newest date).
    static func entry(
        _ i: Int, day: Int = 0,
        mood: String? = nil, theme: String? = nil,
        energy: Int? = nil, genre: String? = nil
    ) -> DailyEntry {
        DailyEntry(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", i))!,
            date: Date(timeIntervalSince1970: 1_000_000 + TimeInterval(day) * 86_400),
            title: "T\(i)", artist: "A\(i)",
            albumArtURL: nil, journalMarkdown: "",
            appleMusicID: "\(i)", spotifyURI: "spotify:track:\(i)",
            genre: genre, year: nil, mood: mood, energy: energy,
            theme: theme, language: nil
        )
    }

    static func songs(
        _ count: Int, value: Int, mood: String? = nil, theme: String? = nil,
        energy: Int? = nil, genre: String? = nil, day: Int = 0,
        hearts: Int = 0, idBase: Int = 0
    ) -> [RatedSong] {
        (0..<count).map { i in
            RatedSong(entry: entry(idBase + i, day: day, mood: mood, theme: theme,
                                   energy: energy, genre: genre),
                      value: value, isFavorite: i < hearts)
        }
    }

    @Test func exposureBiasRegression() {
        // Curator-heavy Joyful catalog; user keeps only the Melancholy drops.
        // Raw counts said Flower Child; like-rates must say The Poet.
        let data = Self.songs(4, value: 1, mood: "Joyful", idBase: 0)
            + Self.songs(10, value: -1, mood: "Joyful", idBase: 100)
            + Self.songs(6, value: 1, mood: "Melancholy", idBase: 200)
            + Self.songs(1, value: -1, mood: "Melancholy", idBase: 300)
        let result = ArchetypeScorer.score(data)
        #expect(result?.profile.id == "the_melancholic")
    }

    @Test func flatRaterIsShapeshifter() {
        // Equal like-rate in every mood → no signature → earned Shapeshifter.
        var data: [RatedSong] = []
        for (i, mood) in ["Joyful", "Melancholy", "Defiant", "Dreamy"].enumerated() {
            data += Self.songs(3, value: 1, mood: mood, idBase: i * 100)
            data += Self.songs(3, value: -1, mood: mood, idBase: i * 100 + 50)
        }
        #expect(ArchetypeScorer.score(data)?.profile.id == "the_shapeshifter")
    }

    @Test func favoritesTipANearTie() {
        // Equal Joyful/Euphoric keeps → symmetric scores → list-order tie-break
        // (Party Animal first). Hearts on the Joyful keeps must flip it to Flower Child.
        func base(joyfulHearts: Int) -> [RatedSong] {
            Self.songs(6, value: 1, mood: "Joyful", hearts: joyfulHearts, idBase: 0)
            + Self.songs(2, value: -1, mood: "Joyful", idBase: 50)
            + Self.songs(6, value: 1, mood: "Euphoric", idBase: 100)
            + Self.songs(2, value: -1, mood: "Euphoric", idBase: 150)
            + Self.songs(6, value: -1, mood: "Dark", idBase: 200)
        }
        #expect(ArchetypeScorer.score(base(joyfulHearts: 0))?.profile.id == "party_animal")
        #expect(ArchetypeScorer.score(base(joyfulHearts: 3))?.profile.id == "flower_child")
    }

    @Test func heartOnlySongsCountAsLikes() {
        // A favorited-but-unrated song (value 0, isFavorite) is still signal.
        let data = Self.songs(5, value: 1, mood: "Tender", theme: "Love & Romance", idBase: 0)
            + Self.songs(4, value: -1, mood: "Defiant", idBase: 100)
            + Self.songs(3, value: 0, mood: "Tender", theme: "Love & Romance",
                         hearts: 3, idBase: 200)
        #expect(ArchetypeScorer.score(data)?.profile.id == "hopeless_romantic")
    }

    @Test func recentRatingsOutweighOldSeed() {
        // Day 0: a Joyful-heavy seed (with contrast). Day ~200: months of
        // contrary judgments must win via recency decay.
        let seed = Self.songs(8, value: 1, mood: "Joyful", day: 0, idBase: 0)
            + Self.songs(4, value: -1, mood: "Dark", day: 0, idBase: 50)
        let recent = Self.songs(10, value: 1, mood: "Melancholy", day: 200, idBase: 100)
            + Self.songs(6, value: -1, mood: "Joyful", day: 205, idBase: 200)
        #expect(ArchetypeScorer.score(seed + recent)?.profile.id == "the_melancholic")
        #expect(ArchetypeScorer.score(seed)?.profile.id == "flower_child")
    }

    @Test func popheadRequiresGenreOverIndexNotJustJoy() {
        // Same moods, different genres: joyful folk → Flower Child;
        // joyful Pop → The Pophead (genre weight tips it).
        let folk = Self.songs(8, value: 1, mood: "Joyful", genre: "Folk", idBase: 0)
            + Self.songs(4, value: -1, mood: "Dark", genre: "Rock", idBase: 100)
        let pop = Self.songs(8, value: 1, mood: "Joyful", genre: "Pop", idBase: 0)
            + Self.songs(4, value: -1, mood: "Dark", genre: "Rock", idBase: 100)
        #expect(ArchetypeScorer.score(folk)?.profile.id == "flower_child")
        #expect(ArchetypeScorer.score(pop)?.profile.id == "the_pophead")
    }

    @Test func evidenceCarriesRawCountsForTheWinner() {
        let data = Self.songs(6, value: 1, mood: "Melancholy", hearts: 2, idBase: 0)
            + Self.songs(1, value: -1, mood: "Melancholy", idBase: 50)
            + Self.songs(4, value: 1, mood: "Joyful", idBase: 100)
            + Self.songs(10, value: -1, mood: "Joyful", idBase: 200)
        let result = ArchetypeScorer.score(data)
        let top = result?.evidence.facts.first
        #expect(top?.dimensionID == "mood")
        #expect(top?.category == "Melancholy")
        #expect(top?.likes == 6)
        #expect(top?.total == 7)
        #expect(top?.hearts == 2)
    }

    @Test func everyNonShapeshifterArchetypeHasAnAffinityVector() {
        let covered = Set(ArchetypeAffinity.all.map { $0.profile.id })
        let expected = Set(TasteProfile.allCases.map(\.id)).subtracting(["the_shapeshifter"])
        #expect(covered == expected)
    }

    @Test func emptyInputScoresNil() {
        #expect(ArchetypeScorer.score([]) == nil)
    }

    @Test func incumbentKeepsTitleInsideStickyMargin() {
        // One heart on a Euphoric keep gives Party Animal a sliver of an edge
        // over Flower Child — big enough to win cold, too small to dethrone.
        let data = Self.songs(6, value: 1, mood: "Joyful", idBase: 0)
            + Self.songs(2, value: -1, mood: "Joyful", idBase: 50)
            + Self.songs(6, value: 1, mood: "Euphoric", hearts: 1, idBase: 100)
            + Self.songs(2, value: -1, mood: "Euphoric", idBase: 150)
            + Self.songs(6, value: -1, mood: "Dark", idBase: 200)
        let cold = ArchetypeScorer.score(data)
        let sticky = ArchetypeScorer.score(data, incumbentID: "flower_child")
        #expect(cold?.profile.id == "party_animal")
        #expect(sticky?.profile.id == "flower_child")
        // A decisive lead must still dethrone: hearts on three Euphoric keeps.
        let decisive = Self.songs(6, value: 1, mood: "Joyful", idBase: 0)
            + Self.songs(2, value: -1, mood: "Joyful", idBase: 50)
            + Self.songs(6, value: 1, mood: "Euphoric", hearts: 3, idBase: 100)
            + Self.songs(2, value: -1, mood: "Euphoric", idBase: 150)
            + Self.songs(6, value: -1, mood: "Dark", idBase: 200)
        #expect(ArchetypeScorer.score(decisive, incumbentID: "flower_child")?.profile.id == "party_animal")
    }
}

// MARK: - DriverHighlights

struct DriverHighlightsTests {

    private func fact(_ dim: String, _ cat: String, contribution: Double) -> ArchetypeEvidence.Fact {
        .init(dimensionID: dim, category: cat, likes: 5, total: 6, hearts: 1, contribution: contribution)
    }

    @Test func mapsFactsToDimensionsWithContributionRanks() {
        let evidence = ArchetypeEvidence(facts: [
            fact("mood", "Dark", contribution: 0.30),
            fact("theme", "Loneliness", contribution: 0.20),
            fact("genre", "Rock", contribution: 0.10),
        ])
        let h = DriverHighlights.compute(
            evidence: evidence, displayedArchetypeID: "outsider", liveArchetypeID: "outsider")
        #expect(h.count == 3)
        #expect(h["mood"]?.rank == 1)
        #expect(h["mood"]?.fact.category == "Dark")
        #expect(h["theme"]?.rank == 2)
        #expect(h["genre"]?.rank == 3)
        #expect(h["energy"] == nil)
    }

    @Test func firstFactPerDimensionWins() {
        // Two moods in evidence: the higher-contribution one (sorted first) keeps the slot.
        let evidence = ArchetypeEvidence(facts: [
            fact("mood", "Dark", contribution: 0.30),
            fact("mood", "Melancholy", contribution: 0.20),
        ])
        let h = DriverHighlights.compute(
            evidence: evidence, displayedArchetypeID: "outsider", liveArchetypeID: "outsider")
        #expect(h.count == 1)
        #expect(h["mood"]?.fact.category == "Dark")
        #expect(h["mood"]?.rank == 1)
    }

    @Test func emptyOrNilEvidenceYieldsNoHighlights() {
        #expect(DriverHighlights.compute(
            evidence: nil, displayedArchetypeID: "outsider", liveArchetypeID: "outsider").isEmpty)
        #expect(DriverHighlights.compute(
            evidence: ArchetypeEvidence(facts: []),
            displayedArchetypeID: "outsider", liveArchetypeID: "outsider").isEmpty)
    }

    @Test func suppressedWhenDisplayedArchetypeDiffersFromLiveWinner() {
        // The weekly-stable archetype lags the live winner → badges would explain
        // an archetype the user isn't seeing. Suppress.
        let evidence = ArchetypeEvidence(facts: [fact("mood", "Dark", contribution: 0.30)])
        let h = DriverHighlights.compute(
            evidence: evidence, displayedArchetypeID: "pophead", liveArchetypeID: "outsider")
        #expect(h.isEmpty)
    }

    @Test func suppressedWhenNoDisplayedArchetype() {
        let evidence = ArchetypeEvidence(facts: [fact("mood", "Dark", contribution: 0.30)])
        #expect(DriverHighlights.compute(
            evidence: evidence, displayedArchetypeID: nil, liveArchetypeID: "outsider").isEmpty)
    }
}

// MARK: - BoardEntranceFlavor

struct BoardEntranceFlavorTests {

    @Test func moodyLightStylesBloomSlowAndDim() {
        let f = BoardEntranceFlavor.flavor(for: .halfMoon)   // The Outsider
        #expect(f.bloomDuration > BoardEntranceFlavor.standard.bloomDuration)
        #expect(f.bloomOpacity < BoardEntranceFlavor.standard.bloomOpacity)
    }

    @Test func popLightStylesBloomFastAndBright() {
        let f = BoardEntranceFlavor.flavor(for: .glossyPop)  // The Pophead
        #expect(f.bloomDuration < BoardEntranceFlavor.standard.bloomDuration)
        #expect(f.bloomRadius > BoardEntranceFlavor.standard.bloomRadius)
    }

    @Test func warmLightStylesGetWarmBloom() {
        let f = BoardEntranceFlavor.flavor(for: .softBloom)  // Hopeless Romantic
        #expect(f.bloomDuration >= BoardEntranceFlavor.standard.bloomDuration)
        #expect(f.bloomRadius >= BoardEntranceFlavor.standard.bloomRadius)
    }

    @Test func unmappedStylesGetStandard() {
        #expect(BoardEntranceFlavor.flavor(for: .colorRibbons) == .standard)
        #expect(BoardEntranceFlavor.flavor(for: .none) == .standard)
    }
}
