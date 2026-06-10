# Archetype Engine v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-mood archetype lookup with a deterministic affinity-profile scorer (ratings + favorites, recency-weighted, evidence-backed), retitle two archetypes, and add The Pophead.

**Architecture:** A new pure `ArchetypeScorer` (in `Models/ArchetypeAffinity.swift`) scores all archetypes against smoothed, recency-weighted like-rates and returns a winner + evidence. `TasteMirror.build` calls it; every consumer (Insights, Wrapped, friend mirrors, taste-seed reveal) flows through `TasteMirror.build`, so they inherit it automatically. Receipts copy surfaces the evidence in the reveal and the Insights hero.

**Tech Stack:** Swift / SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`) in `Daily MusicTests`, plus one legacy XCTest file (`ArchetypeCopyTests.swift`).

**Spec:** `docs/superpowers/specs/2026-06-10-archetype-engine-design.md`

---

## Critical build/test facts (read first)

1. **Building from CLI needs a `DEVELOPER_DIR` override** (xcode-select points at CommandLineTools):

   ```bash
   cd "/Users/maximesavehilaghi/Developer/Daily Music"
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
     xcodebuild test -scheme "Daily Music" \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -only-testing:"Daily MusicTests/TasteMirrorTests" 2>&1 | tail -20
   ```

   Run the full suite by dropping `-only-testing:`. Expect a few minutes per run; prefer `-only-testing:` while iterating.

2. **Never create new files under `Daily MusicTests/`** — the test target is NOT a file-system-synchronized group; new test files require manual Xcode project edits. All new tests go into the EXISTING files `Daily MusicTests/TasteMirrorTests.swift` and `Daily MusicTests/ArchetypeCopyTests.swift`. New files under `Daily Music/` (app target) auto-compile — `Models/ArchetypeAffinity.swift` is fine.

3. **Frozen IDs:** archetype `id` strings (`the_hippie`, `the_melancholic`, …) are persisted in UserDefaults (`ArchetypeSnapshotStore`) and key the flares dict, hero backgrounds, and voiced copy. Never change an existing `id`. Only display `title`/`tagline` change.

4. Test helpers in `TasteMirrorTests` create entries with ancient dates derived from ids. The scorer's recency decay is therefore **relative to the newest judgment in the dataset**, not wall-clock `Date()` — this is a design requirement, not a convenience.

---

## File map

| File | Action |
|---|---|
| `Daily Music/Models/ArchetypeAffinity.swift` | **Create** — affinity vectors, `ArchetypeScorer`, `ArchetypeEvidence`, `ScoredArchetype` |
| `Daily Music/Models/TasteProfile.swift` | Retitle ×2, add `thePophead`, delete `resolve` |
| `Daily Music/Models/TasteMirror.swift` | `RatedSong` new fields + back-compat decode; `build(from:incumbentID:)` calls scorer; `evidence` field |
| `Daily Music/Models/SeedRatings.swift` | Stamp `ratedAt` on save |
| `Daily Music/Models/StarterPack.swift` | Swap Levitating → Banana Pancakes (Serene) |
| `Daily Music/Models/ArchetypeRevealFlare.swift` | Flare for `the_pophead` |
| `Daily Music/Views/Components/ArchetypeCopy.swift` | Golden Hour voice, Pophead case, new `archetypeReceiptsCopy` |
| `Daily Music/Views/Components/ArchetypeHeroBackground.swift` | `PopheadBg` |
| `Daily Music/Views/Components/TasteMirrorBoard.swift` | Receipts subline in hero |
| `Daily Music/ViewModels/InsightsViewModel.swift` | `load(favoriteIDs:)`, incumbent, evidence-based reveal reason |
| `Daily Music/Views/InsightsView.swift` | Pass `env.favoritesStore.ids` to `load` (4 call sites) |
| `Daily Music/ViewModels/WrappedViewModel.swift` | Mark `isFavorite` on rated songs |
| `Daily Music/Views/Onboarding/TasteSeedView.swift` | Reveal via mirror archetype, not `resolve` |
| `Daily MusicTests/TasteMirrorTests.swift` | New `ArchetypeScorerTests` struct + updated legacy tests |
| `Daily MusicTests/ArchetypeCopyTests.swift` | Receipts copy + cast exhaustiveness tests |
| `docs/ARCHITECTURE.md` | Update §3.5, model graph, "where do I look" |

---

### Task 1: `RatedSong` gains `isFavorite` + `ratedAt` with back-compat decoding

`SeedRatings` persists `[RatedSong]` as JSON in UserDefaults. Existing users have payloads WITHOUT the new keys, so synthesized `Decodable` (which requires all keys) would throw and silently wipe their seed (`SeedRatings.load()` returns `[]` on decode failure). A custom `init(from:)` is mandatory.

**Files:**
- Modify: `Daily Music/Models/TasteMirror.swift:13-17` (the `RatedSong` struct)
- Test: `Daily MusicTests/TasteMirrorTests.swift`

- [ ] **Step 1: Write the failing tests** — append inside the `TasteMirrorTests` struct (before its closing brace):

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/TasteMirrorTests" 2>&1 | tail -20`
Expected: BUILD FAILURE — `RatedSong` has no member `isFavorite` / extra arguments in call.

- [ ] **Step 3: Implement** — replace the `RatedSong` struct in `Daily Music/Models/TasteMirror.swift`:

```swift
/// One judged song: a tagged entry plus the user's judgment.
/// value: +1 👍 / -1 👎 / 0 = no thumb (heart-only — feeds the scorer, not the tiles).
struct RatedSong: Equatable, Codable {
    let entry: DailyEntry
    let value: Int
    var isFavorite: Bool = false
    var ratedAt: Date? = nil

    /// When the judgment happened. Catalog songs are rated on their drop day,
    /// so `entry.date` is the natural fallback; seeds carry an explicit stamp.
    var effectiveRatedAt: Date { ratedAt ?? entry.date }

    init(entry: DailyEntry, value: Int, isFavorite: Bool = false, ratedAt: Date? = nil) {
        self.entry = entry
        self.value = value
        self.isFavorite = isFavorite
        self.ratedAt = ratedAt
    }

    // Pre-v2 persisted seed JSON lacks the new keys — decode them as optional
    // so an upgrade never wipes the onboarding seed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entry = try c.decode(DailyEntry.self, forKey: .entry)
        value = try c.decode(Int.self, forKey: .value)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        ratedAt = try c.decodeIfPresent(Date.self, forKey: .ratedAt)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass** (same command). Expected: PASS, all existing `TasteMirrorTests` still green.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/TasteMirror.swift" "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat(insights): RatedSong carries favorites + rating timestamp"
```

---

### Task 2: Cast changes — Golden Hour, The Poet, The Pophead

Display-only retitles (ids frozen) plus the new 11th profile. `resolve` stays for now — it dies in Task 5.

**Files:**
- Modify: `Daily Music/Models/TasteProfile.swift`
- Test: `Daily MusicTests/ArchetypeCopyTests.swift` (XCTest file)

- [ ] **Step 1: Write the failing tests** — append inside `final class ArchetypeCopyTests`:

```swift
    // MARK: - Engine v2 cast

    func test_cast_retitlesKeepFrozenIDs() {
        XCTAssertEqual(TasteProfile.theHippie.id, "the_hippie")
        XCTAssertEqual(TasteProfile.theHippie.title, "Golden Hour")
        XCTAssertEqual(TasteProfile.theHippie.tagline, "Life at 0.75× speed. On purpose.")
        XCTAssertEqual(TasteProfile.theMelancholic.id, "the_melancholic")
        XCTAssertEqual(TasteProfile.theMelancholic.title, "The Poet")
    }

    func test_pophead_existsAndIsRegistered() {
        XCTAssertEqual(TasteProfile.thePophead.id, "the_pophead")
        XCTAssertEqual(TasteProfile.thePophead.title, "The Pophead")
        XCTAssertTrue(TasteProfile.allCases.contains(TasteProfile.thePophead))
        XCTAssertEqual(TasteProfile.profile(id: "the_pophead")?.title, "The Pophead")
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/ArchetypeCopyTests" 2>&1 | tail -20`
Expected: BUILD FAILURE — no member `thePophead`.

- [ ] **Step 3: Implement** in `Daily Music/Models/TasteProfile.swift`:

(a) Retitle Serene (keep id, symbol, colors — the serene teal still works for golden hour):

```swift
    // ── SERENE ────────────────────────────────────────────────────────────
    static let theHippie = TasteProfile(
        "the_hippie", "Golden Hour",
        "Life at 0.75× speed. On purpose.",
        "bird.fill",
        [c(0.13, 0.70, 0.67), c(0.0, 0.50, 0.50)]
    )
```

(b) Retitle Melancholy (tagline unchanged):

```swift
    // ── MELANCHOLY ────────────────────────────────────────────────────────
    static let theMelancholic = TasteProfile(
        "the_melancholic", "The Poet",
        "Won't listen to anything that doesn't mean something. Everything means something.",
        "cloud.moon.fill",
        [c(0.29, 0.44, 0.65), c(0.10, 0.14, 0.49)]
    )
```

(c) Add the genre-anchored 11th, right above the BALANCED section:

```swift
    // ── POP (genre-anchored — the first archetype that needs the scorer) ──
    static let thePophead = TasteProfile(
        "the_pophead", "The Pophead",
        "Knows every word. Including the ad-libs.",
        "music.mic",
        [c(1.0, 0.36, 0.62), c(0.62, 0.12, 0.78)]
    )
```

(d) Register it in `allCases` (before the shapeshifter — list order is the deterministic tie-break):

```swift
    static let allCases: [TasteProfile] = [
        partyAnimal, flowerChild, hopelessRomantic, theHippie, theStargazer,
        bornInTheWrongGeneration, theMelancholic, loudAndProud, theOutsider,
        thePophead, theShapeshifter
    ]
```

(e) Update the file header comment: `10 mood-anchored identities` → `9 mood-anchored + 1 genre-anchored identities + 1 balanced fallback`.

- [ ] **Step 4: Run to verify pass** (same command). Also run `-only-testing:"Daily MusicTests/ArchetypeRevealTests" -only-testing:"Daily MusicTests/ArchetypeSnapshotTests"` — they are id-based and must stay green.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/TasteProfile.swift" "Daily MusicTests/ArchetypeCopyTests.swift"
git commit -m "feat(insights): retitle Golden Hour + The Poet, add The Pophead"
```

---

### Task 3: `ArchetypeScorer` core (affinity vectors, smoothed signals, Shapeshifter floor)

The heart of v2. Pure math, no I/O. Recency is **relative to the newest judgment** in the dataset (deterministic; ancient test dates and lapsed users both work).

**Files:**
- Create: `Daily Music/Models/ArchetypeAffinity.swift`
- Test: `Daily MusicTests/TasteMirrorTests.swift` (new top-level `ArchetypeScorerTests` struct in the same file — do NOT create a new test file)

- [ ] **Step 1: Write the failing tests** — append at the END of `Daily MusicTests/TasteMirrorTests.swift` (after `TasteComparisonTests`):

```swift
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
        // (Party Animal first). Hearts on the Joyful keeps must flip it.
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
        // Day 0: a Joyful-heavy seed (with contrast — a seed of ONLY likes in
        // one mood would be the no-signature case). Day ~200: months of
        // contrary judgments must win via recency decay.
        let seed = Self.songs(8, value: 1, mood: "Joyful", day: 0, idBase: 0)
            + Self.songs(4, value: -1, mood: "Dark", day: 0, idBase: 50)
        let recent = Self.songs(10, value: 1, mood: "Melancholy", day: 200, idBase: 100)
            + Self.songs(6, value: -1, mood: "Joyful", day: 205, idBase: 200)
        #expect(ArchetypeScorer.score(seed + recent)?.profile.id == "the_melancholic")
        // The seed alone still gives a sensible first read.
        #expect(ArchetypeScorer.score(seed)?.profile.id == "flower_child")
    }

    @Test func popheadRequiresGenreOverIndexNotJustJoy() {
        // Same moods, different genres: joyful folk → Flower Child;
        // joyful POP → The Pophead (genre weight collects on top of mood).
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
}
```

- [ ] **Step 2: Run to verify failure** (TasteMirrorTests command from Task 1). Expected: BUILD FAILURE — `ArchetypeScorer` undefined.

- [ ] **Step 3: Implement** — create `Daily Music/Models/ArchetypeAffinity.swift`:

```swift
//
//  ArchetypeAffinity.swift
//  Daily Music
//
//  Archetype Engine v2. Each archetype declares an affinity vector over
//  moods / energy bands / themes / genres; the scorer ranks all of them
//  against the user's smoothed, recency-weighted like-rates. Pure math,
//  no I/O — fully unit-tested (ArchetypeScorerTests). This replaces the
//  raw-count single-mood lookup that mirrored the curator's editorial mix
//  instead of the user's taste.
//  Spec: docs/superpowers/specs/2026-06-10-archetype-engine-design.md
//

import Foundation

/// One archetype's taste signature. Weights are hand-tuned constants —
/// the test suite doubles as the tuning harness (tweak values, not structure).
struct ArchetypeAffinity {
    let profile: TasteProfile
    let moods: [String: Double]
    let energyBands: [String: Double]
    let themes: [String: Double]
    let genres: [String: Double]

    private init(
        _ profile: TasteProfile,
        moods: [String: Double] = [:],
        energy: [String: Double] = [:],
        themes: [String: Double] = [:],
        genres: [String: Double] = [:]
    ) {
        self.profile = profile
        self.moods = moods
        self.energyBands = energy
        self.themes = themes
        self.genres = genres
    }

    /// Order matters: it is the deterministic tie-break (first-seen maximum).
    /// The Shapeshifter has no vector — it wins by absence (see scorer).
    static let all: [ArchetypeAffinity] = [
        ArchetypeAffinity(.partyAnimal,
            moods: [Mood.euphoric.rawValue: 1.0, Mood.joyful.rawValue: 0.3],
            energy: [EnergyBand.high.rawValue: 0.6],
            themes: [SongTheme.freedom.rawValue: 0.3]),
        ArchetypeAffinity(.flowerChild,
            moods: [Mood.joyful.rawValue: 1.0, Mood.euphoric.rawValue: 0.3,
                    Mood.serene.rawValue: 0.2],
            themes: [SongTheme.hope.rawValue: 0.4]),
        ArchetypeAffinity(.hopelessRomantic,
            moods: [Mood.tender.rawValue: 1.0],
            energy: [EnergyBand.low.rawValue: 0.2],
            themes: [SongTheme.love.rawValue: 0.6, SongTheme.longing.rawValue: 0.4,
                     SongTheme.heartbreak.rawValue: 0.3]),
        ArchetypeAffinity(.theHippie,
            moods: [Mood.serene.rawValue: 1.0, Mood.dreamy.rawValue: 0.2,
                    Mood.joyful.rawValue: 0.2],
            energy: [EnergyBand.low.rawValue: 0.4],
            themes: [SongTheme.freedom.rawValue: 0.3, SongTheme.hope.rawValue: 0.2]),
        ArchetypeAffinity(.theStargazer,
            moods: [Mood.dreamy.rawValue: 1.0, Mood.serene.rawValue: 0.2],
            energy: [EnergyBand.low.rawValue: 0.3],
            themes: [SongTheme.longing.rawValue: 0.4]),
        ArchetypeAffinity(.bornInTheWrongGeneration,
            moods: [Mood.nostalgic.rawValue: 1.0],
            themes: [SongTheme.memory.rawValue: 0.6, SongTheme.comingOfAge.rawValue: 0.2]),
        ArchetypeAffinity(.theMelancholic,
            moods: [Mood.melancholy.rawValue: 1.0, Mood.tender.rawValue: 0.2],
            energy: [EnergyBand.low.rawValue: 0.3],
            themes: [SongTheme.heartbreak.rawValue: 0.4, SongTheme.loneliness.rawValue: 0.4]),
        ArchetypeAffinity(.loudAndProud,
            moods: [Mood.defiant.rawValue: 1.0, Mood.dark.rawValue: 0.2],
            energy: [EnergyBand.high.rawValue: 0.5],
            themes: [SongTheme.rebellion.rawValue: 0.5, SongTheme.empowerment.rawValue: 0.3]),
        ArchetypeAffinity(.theOutsider,
            moods: [Mood.dark.rawValue: 1.0, Mood.melancholy.rawValue: 0.2],
            themes: [SongTheme.loneliness.rawValue: 0.4]),
        ArchetypeAffinity(.thePophead,
            moods: [Mood.joyful.rawValue: 0.4, Mood.euphoric.rawValue: 0.4],
            energy: [EnergyBand.high.rawValue: 0.3],
            genres: ["Pop": 0.9]),
    ]
}

/// Receipts: the top contributing categories behind the winning archetype,
/// with raw counts so the copy can cite real numbers.
struct ArchetypeEvidence: Equatable {
    struct Fact: Equatable {
        let dimensionID: String   // "mood" | "energy" | "theme" | "genre"
        let category: String      // e.g. "Melancholy", "Pop", "High"
        let likes: Int            // raw 👍 in this category
        let total: Int            // raw 👍+👎 in this category
        let hearts: Int           // favorites in this category
        let contribution: Double  // weighted contribution to the winning score
    }
    let facts: [Fact]             // descending by contribution, max 3
}

struct ScoredArchetype: Equatable {
    let profile: TasteProfile
    let score: Double
    let evidence: ArchetypeEvidence
}

enum ArchetypeScorer {
    static let halfLifeDays = 45.0     // recency: a judgment loses half its weight in ~6 weeks
    static let favoriteBoost = 0.75    // a heart is a louder like
    static let scoreFloor = 0.02       // below this nothing has a signature → Shapeshifter
    static let stickyMargin = 0.015    // hysteresis: challenger must beat incumbent by this
    static let confidencePivot = 3.0   // conf = n/(n+pivot): ~0.5 at 3 ratings, ~0.8 at 12

    private struct Tally {
        var wLike = 0.0, wDislike = 0.0      // decay-weighted
        var likes = 0, total = 0, hearts = 0 // raw, for receipts
    }

    private struct Key: Hashable {
        let dim: String
        let cat: String
    }

    /// Rank every archetype against the user's judgments. Returns nil only for
    /// empty input; otherwise the winner (or The Shapeshifter when no score
    /// clears the floor) with its evidence. `incumbentID` adds hysteresis: the
    /// currently displayed archetype keeps the title unless a challenger beats
    /// it by more than `stickyMargin` — siblings stop flapping week to week.
    static func score(_ rated: [RatedSong], incumbentID: String? = nil) -> ScoredArchetype? {
        guard !rated.isEmpty else { return nil }

        // Recency decays relative to the NEWEST judgment, not the wall clock:
        // deterministic in tests, and a lapsed user's history keeps its shape.
        let reference = rated.map(\.effectiveRatedAt).max() ?? Date()

        var tallies: [Key: Tally] = [:]
        var allLike = 0.0, allDislike = 0.0
        for r in rated {
            let age = max(0, reference.timeIntervalSince(r.effectiveRatedAt)) / 86_400
            let decay = pow(0.5, age / halfLifeDays)
            let like: Double, dislike: Double
            switch r.value {
            case 1...:
                like = decay * (r.isFavorite ? 1 + favoriteBoost : 1); dislike = 0
            case ..<0:
                like = 0; dislike = decay
            default:
                // Heart-only (favorited, never thumbed) is still a like signal.
                like = r.isFavorite ? decay * favoriteBoost : 0; dislike = 0
            }
            guard like > 0 || dislike > 0 else { continue }
            allLike += like; allDislike += dislike

            var keys: [Key] = []
            if let mood = r.entry.mood { keys.append(Key(dim: "mood", cat: mood)) }
            if let energy = r.entry.energy {
                keys.append(Key(dim: "energy", cat: EnergyBand.band(for: energy).rawValue))
            }
            if let theme = r.entry.theme { keys.append(Key(dim: "theme", cat: theme)) }
            if let genre = r.entry.genre { keys.append(Key(dim: "genre", cat: genre)) }
            for key in keys {
                var t = tallies[key, default: Tally()]
                t.wLike += like
                t.wDislike += dislike
                if r.value > 0 { t.likes += 1 }
                if r.value != 0 { t.total += 1 }
                if r.isFavorite { t.hearts += 1 }
                tallies[key] = t
            }
        }

        // Smoothed overall like-rate — the baseline every category is measured
        // against, which removes positivity AND curator-exposure bias at once.
        let overall = (allLike + 1) / (allLike + allDislike + 2)

        var top: ScoredArchetype? = nil
        var incumbent: ScoredArchetype? = nil
        for affinity in ArchetypeAffinity.all {
            var score = 0.0
            var facts: [ArchetypeEvidence.Fact] = []
            let tables = [("mood", affinity.moods), ("energy", affinity.energyBands),
                          ("theme", affinity.themes), ("genre", affinity.genres)]
            for (dim, table) in tables {
                for (cat, weight) in table {
                    guard let t = tallies[Key(dim: dim, cat: cat)] else { continue }
                    let n = t.wLike + t.wDislike
                    guard n > 0 else { continue }
                    let rate = (t.wLike + 1) / (n + 2)          // Laplace-smoothed
                    let confidence = n / (n + confidencePivot)   // saturating
                    let c = weight * (rate - overall) * confidence
                    score += c
                    if c > 0 {
                        facts.append(.init(dimensionID: dim, category: cat,
                                           likes: t.likes, total: t.total,
                                           hearts: t.hearts, contribution: c))
                    }
                }
            }
            let scored = ScoredArchetype(
                profile: affinity.profile, score: score,
                evidence: ArchetypeEvidence(facts: Array(
                    facts.sorted { $0.contribution > $1.contribution }.prefix(3)))
            )
            if affinity.profile.id == incumbentID { incumbent = scored }
            // Strictly-greater keeps the first-seen maximum → list order breaks ties.
            if top == nil || scored.score > top!.score { top = scored }
        }

        guard let winner = top, winner.score >= scoreFloor else {
            return ScoredArchetype(profile: .theShapeshifter, score: top?.score ?? 0,
                                   evidence: ArchetypeEvidence(facts: []))
        }
        if let incumbent, incumbent.profile.id != winner.profile.id,
           incumbent.score >= scoreFloor,
           winner.score - incumbent.score < stickyMargin {
            return incumbent
        }
        return winner
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/TasteMirrorTests" 2>&1 | tail -20`
Expected: PASS. If a scorer test fails on a margin, print the scores in the test temporarily (`#expect` with the actual `result?.score`) and adjust the test DATA (not the weights) unless the failure shows a genuine ranking bug.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/ArchetypeAffinity.swift" "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat(insights): ArchetypeScorer — affinity vectors over smoothed like-rates"
```

---

### Task 4: Hysteresis test (incumbent keeps the title inside the sticky margin)

The implementation already landed in Task 3; this task pins the behavior with a dedicated test before anything wires into the snapshot store.

**Files:**
- Test: `Daily MusicTests/TasteMirrorTests.swift` (inside `ArchetypeScorerTests`)

- [ ] **Step 1: Write the test** — append inside `ArchetypeScorerTests`:

```swift
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
```

- [ ] **Step 2: Run** (TasteMirrorTests command). Expected: PASS (implementation exists). If the margin numbers don't land as expected, print both scores and tune the heart counts in the TEST until the cold/sticky split demonstrates the behavior — the margins are data-dependent, the behavior is what's pinned.

- [ ] **Step 3: Commit**

```bash
git add "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "test(insights): pin scorer hysteresis behavior"
```

---

### Task 5: Wire the scorer into `TasteMirror.build`, delete `resolve`

`build` gains `incumbentID` and an `evidence` field; heart-only songs (value 0) feed the scorer but are filtered out of the tile math so `totalRated`, dimensions, and drill-downs keep their existing meaning. `TasteProfile.resolve` dies; `TasteSeedView` switches to the mirror.

**Files:**
- Modify: `Daily Music/Models/TasteMirror.swift`
- Modify: `Daily Music/Models/TasteProfile.swift` (delete `resolve`)
- Modify: `Daily Music/Views/Onboarding/TasteSeedView.swift:146`
- Test: `Daily MusicTests/TasteMirrorTests.swift`

- [ ] **Step 1: Update the two legacy tests whose expectations change** in `TasteMirrorTests`:

Replace `archetypeFallsBackToMoodOnly` (the old single-mood fallback is gone — a contrast-free history has no signature):

```swift
    @Test func singleCategoryHistoryIsShapeshifter() {
        // Engine v2: every rated song is Melancholy → no contrast between
        // categories → no signature. The Shapeshifter is the honest answer.
        let m = TasteMirror.build(from: Self.mood("Melancholy", likes: 18, dislikes: 6))
        #expect(m.archetype?.id == "the_shapeshifter")
    }
```

And add the new-surface tests inside `TasteMirrorTests`:

```swift
    @Test func mirrorExposesEvidenceForTheWinner() {
        let m = TasteMirror.build(from: Self.workedExample())
        #expect(m.archetype?.id == "the_melancholic")   // worked example survives v2
        #expect(m.evidence?.facts.first?.category == "Melancholy")
    }

    @Test func heartOnlySongsDoNotInflateTileMath() {
        var heartOnly = Self.workedExample()
        heartOnly.append(RatedSong(entry: Self.entry(id: 999, mood: "Serene"),
                                   value: 0, isFavorite: true))
        let m = TasteMirror.build(from: heartOnly)
        #expect(m.totalRated == 30)                       // value-0 excluded
        #expect(!m.ratedSongs.contains { $0.value == 0 }) // drill-downs unchanged
    }

    @Test func mirrorPassesIncumbentThrough() {
        // Near-tie data from the hysteresis test, via the mirror API.
        let data = ArchetypeScorerTests.songs(6, value: 1, mood: "Joyful", idBase: 0)
            + ArchetypeScorerTests.songs(2, value: -1, mood: "Joyful", idBase: 50)
            + ArchetypeScorerTests.songs(6, value: 1, mood: "Euphoric", hearts: 1, idBase: 100)
            + ArchetypeScorerTests.songs(2, value: -1, mood: "Euphoric", idBase: 150)
            + ArchetypeScorerTests.songs(6, value: -1, mood: "Dark", idBase: 200)
        #expect(TasteMirror.build(from: data).archetype?.id == "party_animal")
        #expect(TasteMirror.build(from: data, incumbentID: "flower_child").archetype?.id == "flower_child")
    }
```

- [ ] **Step 2: Run to verify failure** (TasteMirrorTests command). Expected: BUILD FAILURE — `build` has no `incumbentID`, no `evidence` member.

- [ ] **Step 3: Implement in `Daily Music/Models/TasteMirror.swift`:**

(a) Add the field to the struct (after `winningModifier`):

```swift
    let winningModifier: WinningModifier?
    /// Receipts behind the winning archetype (nil while locked).
    let evidence: ArchetypeEvidence?
```

(b) Replace `build(from:)`:

```swift
    static func build(from rated: [RatedSong], incumbentID: String? = nil) -> TasteMirror {
        // Heart-only songs (value 0) feed the archetype scorer but not the
        // tiles — totalRated, dimensions, and drill-downs keep their meaning.
        let thumbed = rated.filter { $0.value != 0 }
        let total = thumbed.count
        let likes = thumbed.filter { $0.value > 0 }.count
        let overall = total > 0 ? Double(likes) / Double(total) : 0

        // --- dimensions ---
        let mood = dimension(id: "mood", title: "Mood", from: thumbed, overall: overall, totalRated: total) { $0.mood }
        let decade = dimension(id: "decade", title: "Decade", from: thumbed, overall: overall, totalRated: total) { $0.decade }
        let theme = dimension(id: "theme", title: "Theme", from: thumbed, overall: overall, totalRated: total) { $0.theme }
        let genre = dimension(id: "genre", title: "Genre", from: thumbed, overall: overall, totalRated: total) { $0.genre }
        let language = dimension(id: "language", title: "Language", from: thumbed, overall: overall, totalRated: total) { $0.language }
        // --- energy ---
        let energy = energyInsight(from: thumbed, overall: overall, totalRated: total)
        // --- modifier selector (unchanged: flavor text for hero copy) ---
        var best: WinningModifier? = nil
        for (dimID, dim) in [("decade", decade), ("theme", theme), ("genre", genre), ("language", language)] {
            guard let oi = dim.overIndex else { continue }
            let margin = oi.likeRate - overall
            if best == nil || margin > best!.margin {
                best = WinningModifier(dimensionID: dimID, categoryName: oi.name,
                                       likeRate: oi.likeRate, total: oi.total, margin: margin)
            }
        }
        let winningModifier = best

        // --- archetype: the v2 affinity scorer (hearts included via `rated`) ---
        let isArchetypeUnlocked = total >= Thresholds.minRatedArchetype
        let scored = isArchetypeUnlocked
            ? ArchetypeScorer.score(rated, incumbentID: incumbentID)
            : nil

        return TasteMirror(
            totalRated: total, overallLikeRate: overall,
            mood: mood, decade: decade, theme: theme, genre: genre, language: language,
            energy: energy, archetype: scored?.profile, isArchetypeUnlocked: isArchetypeUnlocked,
            ratedSongs: thumbed, winningModifier: winningModifier,
            evidence: scored?.evidence
        )
    }
```

(c) In `dimension(...)`, harden the like/dislike split (value 0 must never count as a dislike):

```swift
            if r.value > 0 { likes[name, default: 0] += 1 }
            else if r.value < 0 { dislikes[name, default: 0] += 1 }
```

(d) In `TasteProfile.swift`, delete the entire `// MARK: - resolve` section (the `resolve(mood:modifier:)` function and its doc comment).

(e) In `TasteSeedView.swift:146`, replace:

```swift
        let profile = TasteProfile.resolve(mood: read.mood, modifier: nil)
```

with:

```swift
        // All 10 starter songs are judged by the time the reveal shows, which
        // clears the unlock threshold — the seed read uses the real engine.
        let profile = TasteMirror.build(from: picks).archetype ?? .theShapeshifter
```

- [ ] **Step 4: Run the affected suites**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/TasteMirrorTests" -only-testing:"Daily MusicTests/TasteSeedTests" 2>&1 | tail -20`
Expected: PASS. `archetypeUnlocksWithEnoughRatings` (worked example → `the_melancholic`) must still pass under the scorer — it does because Melancholy's like-rate (0.769) over-indexes the 0.594 overall with high confidence. If `TasteSeedTests` asserts on `StartingRead` only, it is unaffected.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/TasteMirror.swift" "Daily Music/Models/TasteProfile.swift" \
        "Daily Music/Views/Onboarding/TasteSeedView.swift" "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat(insights): TasteMirror runs the affinity scorer; resolve() removed"
```

---

### Task 6: Receipts copy + voiced-copy updates (Golden Hour, The Pophead)

**Files:**
- Modify: `Daily Music/Views/Components/ArchetypeCopy.swift`
- Modify: `Daily Music/Views/Components/TasteMirrorBoard.swift` (hero, ~line 140)
- Test: `Daily MusicTests/ArchetypeCopyTests.swift`

- [ ] **Step 1: Write the failing tests** — append inside `ArchetypeCopyTests`:

```swift
    // MARK: - Receipts

    private func fact(_ dim: String, _ cat: String, likes: Int, total: Int, hearts: Int) -> ArchetypeEvidence.Fact {
        ArchetypeEvidence.Fact(dimensionID: dim, category: cat,
                               likes: likes, total: total, hearts: hearts, contribution: 1)
    }

    func test_receipts_moodFact_withHearts() {
        let e = ArchetypeEvidence(facts: [fact("mood", "Melancholy", likes: 6, total: 7, hearts: 3)])
        XCTAssertEqual(archetypeReceiptsCopy(evidence: e, isCurrentUser: true),
                       "You liked 6 of your 7 Melancholy drops — and hearted 3 of them.")
    }

    func test_receipts_genreFact_thirdPerson_noHearts() {
        let e = ArchetypeEvidence(facts: [fact("genre", "Pop", likes: 9, total: 11, hearts: 0)])
        XCTAssertEqual(archetypeReceiptsCopy(evidence: e, isCurrentUser: false),
                       "They liked 9 of their 11 Pop tracks.")
    }

    func test_receipts_themeFact_lowercasesCategory() {
        let e = ArchetypeEvidence(facts: [fact("theme", "Heartbreak", likes: 5, total: 6, hearts: 0)])
        XCTAssertEqual(archetypeReceiptsCopy(evidence: e, isCurrentUser: true),
                       "You liked 5 of your 6 songs about heartbreak.")
    }

    func test_receipts_emptyEvidence_returnsNil() {
        XCTAssertNil(archetypeReceiptsCopy(evidence: ArchetypeEvidence(facts: []), isCurrentUser: true))
    }

    // MARK: - Voiced copy covers the new cast

    func test_pophead_hasDedicatedVoice() {
        let pop = archetypeHeroCopy(profile: .thePophead, winningModifier: nil, isCurrentUser: true)
        let fallback = archetypeHeroCopy(profile: .theShapeshifter, winningModifier: nil, isCurrentUser: true)
        XCTAssertNotEqual(pop, fallback)
        XCTAssertFalse(pop.isEmpty)
    }

    func test_everyArchetypeHasNonEmptyHeroCopy() {
        for profile in TasteProfile.allCases {
            XCTAssertFalse(archetypeHeroCopy(profile: profile, winningModifier: nil,
                                             isCurrentUser: true).isEmpty, profile.id)
        }
    }
```

- [ ] **Step 2: Run to verify failure** (ArchetypeCopyTests command from Task 2). Expected: BUILD FAILURE — `archetypeReceiptsCopy` undefined.

- [ ] **Step 3: Implement in `ArchetypeCopy.swift`:**

(a) Add the receipts function below `archetypeHeroCopy`:

```swift
/// Receipts: the evidence line under the archetype claim — real numbers from
/// the scorer, so the identity reads as earned, not oracular. nil when there
/// is no positive evidence (e.g. The Shapeshifter), letting callers fall back.
func archetypeReceiptsCopy(evidence: ArchetypeEvidence, isCurrentUser: Bool) -> String? {
    guard let fact = evidence.facts.first, fact.total > 0, fact.likes > 0 else { return nil }
    let You  = isCurrentUser ? "You"  : "They"
    let your = isCurrentUser ? "your" : "their"

    let noun: String
    switch fact.dimensionID {
    case "mood":   noun = "\(fact.category) drops"
    case "theme":  noun = "songs about \(fact.category.lowercased())"
    case "genre":  noun = "\(fact.category) tracks"
    case "energy": noun = "\(fact.category.lowercased())-energy picks"
    default:       noun = "\(fact.category) songs"
    }

    var line = "\(You) liked \(fact.likes) of \(your) \(fact.total) \(noun)"
    if fact.hearts > 0 {
        line += " — and hearted \(fact.hearts) of them"
    }
    return line + "."
}
```

(b) Update the Golden Hour voice (replace the `case "the_hippie":` body):

```swift
    case "the_hippie":
        return "\(You) keep serene songs more than almost any other mood. Golden-hour pace, every day of the week."
```

(c) Add the Pophead case (before `default:`):

```swift
    case "the_pophead":
        if let wm = winningModifier, wm.dimensionID == "decade" {
            return "\(wm.categoryName) pop owns \(your) keep rate. The charts and \(you) have an understanding."
        }
        return "Pop songs barely have to ask — \(your) keep rate there clears everything else. The charts and \(you) have an understanding."
```

(d) In `TasteMirrorBoard.swift`, inside `hero(_:)`, add the receipts subline directly AFTER the existing `Text(unlocked ? archetypeHeroCopy(...) : ...)` view. Receipts describe the LIVE winner's evidence, so only show them when the displayed (stable) archetype matches the live one:

```swift
                if unlocked, profile.id == mirror.archetype?.id,
                   let evidence = mirror.evidence,
                   let receipts = archetypeReceiptsCopy(evidence: evidence, isCurrentUser: isCurrentUser) {
                    Text(receipts)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
```

- [ ] **Step 4: Run to verify pass** (ArchetypeCopyTests command). Expected: PASS, including all pre-existing copy tests.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/Components/ArchetypeCopy.swift" \
        "Daily Music/Views/Components/TasteMirrorBoard.swift" \
        "Daily MusicTests/ArchetypeCopyTests.swift"
git commit -m "feat(insights): evidence receipts under the archetype hero + new cast voices"
```

---### Task 7: Plumb favorites, incumbent, and receipts through the view models

**Files:**
- Modify: `Daily Music/ViewModels/InsightsViewModel.swift`
- Modify: `Daily Music/Views/InsightsView.swift` (4 `load()` call sites: lines ~33, ~60, ~108, ~119, ~160)
- Modify: `Daily Music/ViewModels/WrappedViewModel.swift:70-73`
- Modify: `Daily Music/Models/SeedRatings.swift`

No new unit tests in this task: the changed surfaces are async view-model glue over already-tested pure functions; verification is compile + existing suites + the manual smoke pass in Task 10.

- [ ] **Step 1: `InsightsViewModel.load` takes favorites and passes the incumbent.** Replace the body of `load()`:

```swift
    func load(favoriteIDs: Set<UUID> = []) async {
        if case .loaded = state {} else { state = .loading }

        let history = (try? await entries.publishedHistory()) ?? []
        let myRatings = (try? await ratings.myRatings()) ?? [:]
        // Thumbed songs carry their heart; favorited-but-unrated songs join as
        // heart-only signal (value 0) — the scorer hears them, the tiles don't.
        let rated = history.compactMap { entry -> RatedSong? in
            let value = myRatings[entry.id]
            let fav = favoriteIDs.contains(entry.id)
            guard value != nil || fav else { return nil }
            return RatedSong(entry: entry, value: value ?? 0, isFavorite: fav)
        }
        // Merge the onboarding taste-seed so the profile is established at onboarding
        // and evolves as real daily ratings accumulate. The stable (displayed)
        // archetype is the hysteresis incumbent — siblings must beat it clearly.
        let mirror = TasteMirror.build(
            from: rated + SeedRatings.load(),
            incumbentID: snapshotStore.load().stableArchetypeID
        )
        historyEntries = history
            .sorted { $0.date > $1.date }
            .map { HistoryEntry(entry: $0, rating: myRatings[$0.id]) }
        let snapshot = snapshotStore.evaluate(
            candidate: mirror.archetype,
            hasCompletedOnboarding: defaults.bool(forKey: "hasCompletedOnboarding")
        )
        stableArchetype = TasteProfile.profile(id: snapshot.stableArchetypeID)
        nextRevealDate = snapshot.lastEvaluatedAt.map { $0.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence) }
        reveal = makeReveal(from: snapshot, mirror: mirror)
        state = .loaded(mirror)
    }
```

- [ ] **Step 2: Receipts-first reveal reason.** In `InsightsViewModel.revealReason(for:fallback:)`, insert at the top of the function body:

```swift
        if let evidence = mirror.evidence,
           let receipts = archetypeReceiptsCopy(evidence: evidence, isCurrentUser: true) {
            return receipts
        }
```

(The existing modifier/mood fallbacks below it stay — they cover The Shapeshifter and empty evidence.)

- [ ] **Step 3: Pass favorites at every `load()` call site in `InsightsView.swift`.** Replace each `await model.load()` / `await model?.load()` (including the `onRatingChanged` closures and the retry) with:

```swift
await model?.load(favoriteIDs: env.favoritesStore.ids)
```

(at the `onRetry` site keep the non-optional `model.load(favoriteIDs: env.favoritesStore.ids)` form it already uses). The surrounding `.task(id: env.favoritesStore.ids)` already re-runs when hearts change, so the mirror now refreshes on heart-toggles for the right reason.

- [ ] **Step 4: Wrapped marks hearts.** In `WrappedViewModel.load()` (~line 70), the favorites set is already in scope (`favoriteIDs`). Replace:

```swift
            let rated = history.compactMap { entry in
                myRatings[entry.id].map { RatedSong(entry: entry, value: $0) }
            }
```

with:

```swift
            let rated = history.compactMap { entry in
                myRatings[entry.id].map {
                    RatedSong(entry: entry, value: $0,
                              isFavorite: favoriteIDs.contains(entry.id))
                }
            }
```

(No `incumbentID` here — the recap is a point-in-time read.)

- [ ] **Step 5: SeedRatings stamps `ratedAt`.** Replace `save(_:)` in `SeedRatings.swift`:

```swift
    static func save(_ ratings: [RatedSong]) {
        // Starter songs carry `date: .distantPast`, which would make the seed
        // decay to nothing instantly — stamp the judgments with now instead.
        let now = Date()
        let stamped = ratings.map {
            RatedSong(entry: $0.entry, value: $0.value,
                      isFavorite: $0.isFavorite, ratedAt: $0.ratedAt ?? now)
        }
        guard let data = try? JSONEncoder().encode(stamped) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
```

- [ ] **Step 6: Build + run the full test suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30`
Expected: PASS (all suites). `FriendInsightsViewModel` and `StartingRead` compile untouched thanks to the default parameters.

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/ViewModels/InsightsViewModel.swift" "Daily Music/Views/InsightsView.swift" \
        "Daily Music/ViewModels/WrappedViewModel.swift" "Daily Music/Models/SeedRatings.swift"
git commit -m "feat(insights): favorites + incumbent + receipts flow through the mirror"
```

---

### Task 8: The Pophead's visual identity (flare + hero background)

**Files:**
- Modify: `Daily Music/Models/ArchetypeRevealFlare.swift:218-232` (flares list)
- Modify: `Daily Music/Views/Components/ArchetypeHeroBackground.swift`
- Test: `Daily MusicTests/TasteMirrorTests.swift` (flare registration check in `ArchetypeScorerTests`)

- [ ] **Step 1: Write the failing test** — append inside `ArchetypeScorerTests`:

```swift
    @Test func popheadHasItsOwnRevealFlare() {
        let flare = ArchetypeRevealFlare.flare(for: .thePophead)
        #expect(flare.id == "the_pophead")
        // Must not be the generic fallback combo (mosaicTiles is the
        // Shapeshifter/fallback particle).
        #expect(flare.particleStyle != .mosaicTiles)
    }
```

- [ ] **Step 2: Run to verify failure** (TasteMirrorTests command). Expected: FAIL — the fallback flare's particleStyle IS `.mosaicTiles`.

- [ ] **Step 3: Implement.**

(a) In `ArchetypeRevealFlare.swift`, add to the `list` array (before `.theShapeshifter`) — all enum cases below already exist:

```swift
            f(.thePophead,                  .popBubbles,        .glossyPop,     .bubbles,       .bounce,  .sparkle),
```

(b) In `ArchetypeHeroBackground.swift`, add the routing case (before `default:`):

```swift
        case "the_pophead":                  PopheadBg()
```

and the background view at the end of the file, following the existing private-struct pattern:

```swift
// MARK: - The Pophead (glossy pink-to-purple, drifting gloss bubbles)

private struct PopheadBg: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1, green: 0.36, blue: 0.62),
                         Color(red: 0.80, green: 0.20, blue: 0.72),
                         Color(red: 0.62, green: 0.12, blue: 0.78)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            GeometryReader { geo in
                let xs: [CGFloat] = [0.12, 0.85, 0.55, 0.92, 0.30, 0.70, 0.06]
                let ys: [CGFloat] = [0.20, 0.15, 0.75, 0.60, 0.90, 0.35, 0.55]
                ForEach(0..<7, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(0.10 + Double(i % 3) * 0.05))
                        .frame(width: CGFloat(24 + i * 12))
                        .position(x: geo.size.width * xs[i], y: geo.size.height * ys[i])
                        .blur(radius: 1.5)
                }
            }
            .blendMode(.overlay)
        }
    }
}
```

- [ ] **Step 4: Run to verify pass** (TasteMirrorTests command). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/ArchetypeRevealFlare.swift" \
        "Daily Music/Views/Components/ArchetypeHeroBackground.swift" \
        "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat(insights): Pophead reveal flare + hero background"
```

---

### Task 9: StarterPack — cover Serene

The 10 starter songs cover 8 of 9 moods (Euphoric appears twice); every archetype must be reachable from onboarding.

**Files:**
- Modify: `Daily Music/Models/StarterPack.swift:40-42` (the Levitating block)

- [ ] **Step 1: Look up the real catalog data**

Run: `curl -s "https://itunes.apple.com/search?term=banana+pancakes+jack+johnson&entity=song&limit=3" | python3 -m json.tool | grep -E '"trackId"|"artworkUrl100"|"trackName"|"collectionName"' | head -12`
Expected: a `trackId` (use the album-version result, not a live/compilation cut) and an `artworkUrl100` URL. Take the artwork URL and replace the trailing `100x100bb.jpg` with `600x600bb.jpg` (matching every other StarterPack entry).

- [ ] **Step 2: Swap the entry.** Replace the Levitating `song(...)` block with (substituting the real `trackId` and artwork URL from Step 1):

```swift
        song("Banana Pancakes", "Jack Johnson", "<trackId-from-step-1>",
             "<artworkUrl-from-step-1, 600x600bb.jpg>",
             genre: "Singer-Songwriter", year: 2005, mood: "Serene", energy: 2, theme: "Love & Romance"),
```

Also update the doc comment above the array: `spanning 8 of 9 moods` → `spanning all 9 moods`.

- [ ] **Step 3: Verify**

Run the build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED. Then sanity-check the artwork URL renders: `curl -s -o /dev/null -w "%{http_code}" "<artwork-url>"` → `200`.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Models/StarterPack.swift"
git commit -m "feat(onboarding): starter pack covers Serene (Banana Pancakes)"
```

---

### Task 10: Docs + full verification

**Files:**
- Modify: `docs/ARCHITECTURE.md` (§3.5, §5 model graph, §6 index)

- [ ] **Step 1: Update `docs/ARCHITECTURE.md`:**

(a) In §3.5 (Insights & Wrapped) prose, after the paragraph about archetype stability, add:

```markdown
The archetype itself comes from the **v2 affinity scorer**
([ArchetypeAffinity](Daily%20Music/Models/ArchetypeAffinity.swift)): every
archetype declares a weight vector over moods/energy/themes/genres, scored
against smoothed, recency-weighted (45-day half-life) like-rates with
favorites as a louder like. The Shapeshifter wins only when no score clears
the floor; the displayed (stable) archetype gets hysteresis so siblings don't
flap. The winner ships with `ArchetypeEvidence` — receipts rendered under the
hero copy and in the reveal (`archetypeReceiptsCopy`).
```

(b) In the §5 model graph, add:

```
    ArchetypeAffinity["ArchetypeAffinity + ArchetypeScorer<br/>(affinity vectors → ScoredArchetype)"] --> TasteProfile
    ArchetypeEvidence["ArchetypeEvidence (receipts)"] --> ArchetypeAffinity
```

(c) In the §6 "where do I look" table, update the row `Wrong archetype shown on Insights screen` to mention `ArchetypeScorer` weights in `ArchetypeAffinity.swift`, and add a row:

```markdown
| Archetype feels inaccurate / wrong winner | [ArchetypeAffinity](Daily%20Music/Models/ArchetypeAffinity.swift) — affinity weights + `ArchetypeScorer` constants (`scoreFloor`, `stickyMargin`, `halfLifeDays`); tests in `ArchetypeScorerTests` are the tuning harness |
```

- [ ] **Step 2: Full test suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30`
Expected: ALL suites pass.

- [ ] **Step 3: Manual smoke pass (simulator, mock or live):** Insights tab shows an archetype with a receipts subline (when stable == live); tap "replay reveal" → reveal shows evidence copy; Wrapped opens with a profile; a friend's mirror renders third-person receipts only when their stable matches live (or none — fine); onboarding taste-seed plays, reveal names a profile from the engine.

- [ ] **Step 4: Commit**

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs: architecture map — archetype engine v2"
```

---

## Out of scope (explicitly)

- Rating-in-the-player, rate-to-reveal community stats, onboarding auto-play — separate threads from the brainstorm, not this plan.
- Re-tagging any `daily_entries` rows; no Supabase changes of any kind.
- Golden Hour color/background rework (serene teal stays; revisit only if it reads wrong in the app).
