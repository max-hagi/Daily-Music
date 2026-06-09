# Archetype Engine v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 3-entry TasteProfile catalogue with 46 named music-aesthetic archetypes, fix the dominant category to rank by net score, select the single most over-indexed cross-dimension modifier, produce dynamic "why it's you" hero copy, and let users tap any insight category to see the songs behind it.

**Architecture:** `TasteMirror.build()` is the single computation entry-point — it gains a `WinningModifier` struct (best over-index margin across decade/theme/genre/language) and stores the input `[RatedSong]` for later drill-down queries. `TasteProfile.resolve(mood:modifier:)` receives mood + one winning category name and switches to one of 46 static profiles. `StandoutDetailView` gains a `CategoryDrill` state item that drives a bottom sheet (`CategorySongsSheet`) listing the rated songs behind any tapped row.

**Tech Stack:** Swift 6 / SwiftUI, Xcode 16 file-system-synchronized groups (new `.swift` files in `Daily Music/` compile automatically), Swift Testing (`@Test`, `#expect`), xcodebuild with `DEVELOPER_DIR` override.

---

## File Map

| Action | File |
|--------|------|
| Modify | `Daily Music/Models/TasteMirror.swift` — Tasks 1, 3 |
| Modify | `Daily Music/Models/TasteProfile.swift` — Task 2 |
| Modify | `Daily Music/Views/Components/TasteMirrorBoard.swift` — Task 4 |
| Modify | `Daily Music/Views/StandoutDetailView.swift` — Task 5 |
| **Create** | `Daily Music/Views/Components/CategorySongsSheet.swift` — Task 5 |
| Modify | `Daily MusicTests/TasteMirrorTests.swift` — Tasks 1, 3 |

---

## Task 1 — Net-score dominant ranking + store ratedSongs

**Why:** `dominant` currently picks the category with the most *raw likes*, which favours often-heard-but-mixed categories over ones the user clearly loves. Sorting by `likes − dislikes` (net score) fixes this. Storing `ratedSongs` on the mirror is also needed for the drill-down queries added in Task 3.

**Files:**
- Modify: `Daily Music/Models/TasteMirror.swift`
- Modify: `Daily MusicTests/TasteMirrorTests.swift`

- [ ] **Step 1 — Update the sort key in `dimension()` (TasteMirror.swift line 113)**

Replace:
```swift
.sorted { ($0.likes, $0.total, $1.name) > ($1.likes, $1.total, $0.name) }
```
With:
```swift
.sorted { ($0.likes - $0.dislikes, $0.likes, $1.name) > ($1.likes - $1.dislikes, $1.likes, $0.name) }
```
Primary key: net score (desc). Tie-break: raw likes (desc). Final tie: name alphabetical (asc).

- [ ] **Step 2 — Add `ratedSongs` field to `TasteMirror` struct (after `isArchetypeUnlocked`)**

```swift
struct TasteMirror: Equatable {
    let totalRated: Int
    let overallLikeRate: Double
    let mood: DimensionInsight
    let decade: DimensionInsight
    let theme: DimensionInsight
    let genre: DimensionInsight
    let language: DimensionInsight
    let energy: EnergyInsight
    let archetype: TasteProfile?
    let isArchetypeUnlocked: Bool
    let ratedSongs: [RatedSong]           // ← add this
    // ...Thresholds enum stays unchanged
```

- [ ] **Step 3 — Pass `ratedSongs: rated` in the `TasteMirror(...)` return at the bottom of `build()`**

Replace the existing `return TasteMirror(...)` call with:
```swift
return TasteMirror(
    totalRated: total, overallLikeRate: overall,
    mood: mood, decade: decade, theme: theme, genre: genre, language: language,
    energy: energy, archetype: archetype, isArchetypeUnlocked: isArchetypeUnlocked,
    ratedSongs: rated
)
```

- [ ] **Step 4 — Rename and tighten the existing dominant test (TasteMirrorTests.swift)**

Replace `moodDominantIsMostLiked` with a renamed version that documents *net-score* intent, and add a new test that proves net score beats raw likes:

```swift
// rename the existing test
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
```

- [ ] **Step 5 — Run the tests**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug test 2>&1 | grep -E "Test (passed|failed|Suite|Case)|error:"
```
Expected: all tests pass (including the two renamed/new ones).

- [ ] **Step 6 — Commit**

```bash
git add "Daily Music/Models/TasteMirror.swift" \
        "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat(insights): rank dominant by net score; store ratedSongs on TasteMirror"
```

---

## Task 2 — TasteProfile: full 46-entry catalogue + new resolve signature

**Why:** Replace the 3-specialisation stub with 46 named music-aesthetic archetypes covering all 9 moods with decade / theme / genre modifiers. The new `resolve(mood:modifier:)` signature takes a single winning category string (could be a decade like "1980s", a theme like "Heartbreak", or a genre like "Rock"). The old 3-arg signature is removed; TasteMirror is updated to call the new one with `modifier: nil` for now (Task 3 supplies the real modifier).

**Files:**
- Modify: `Daily Music/Models/TasteProfile.swift`
- Modify: `Daily Music/Models/TasteMirror.swift` (build() call site only)
- Modify: `Daily MusicTests/TasteMirrorTests.swift` (fix archetype ID assertions)

- [ ] **Step 1 — Replace TasteProfile.swift entirely**

```swift
//
//  TasteProfile.swift
//  Daily Music
//
//  The synthesised archetype. NOT scored — a lookup on the user's top mood
//  plus a single winning cross-dimension modifier (decade > theme > genre by
//  over-index margin). 46 named music-aesthetic badges covering all 9 moods.
//

import SwiftUI

struct TasteProfile: Equatable {
    let id: String          // stable snake_case identifier
    let title: String       // badge shown in the hero
    let symbol: String      // SF Symbol name
    let colors: [Color]     // gradient [lead, tail]

    private init(_ id: String, _ title: String, _ symbol: String, _ colors: [Color]) {
        self.id = id; self.title = title; self.symbol = symbol; self.colors = colors
    }

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    // ── EUPHORIC ──────────────────────────────────────────────────────────
    static let euphoricDiscoKid    = TasteProfile("euphoric_disco_kid",    "Disco Kid",      "music.quarternote.3", [c(0.98,0.72,0.12), c(0.82,0.42,0.08)])
    static let euphoricSynthPopKid = TasteProfile("euphoric_synth_pop_kid","Synth-Pop Kid",  "waveform",            [c(0.10,0.78,0.96), c(0.04,0.40,0.80)])
    static let euphoricFestivalKid = TasteProfile("euphoric_festival_kid", "Festival Kid",   "sparkles",            [c(0.96,0.28,0.62), c(0.55,0.20,0.90)])
    static let euphoricAnthemist   = TasteProfile("euphoric_anthemist",    "Anthemist",      "fist.raised.fill",    [c(0.80,0.22,0.90), c(0.45,0.10,0.68)])
    static let euphoricDefault     = TasteProfile("euphoric_default",      "Euphoric",       "sun.max.fill",        [c(1.0,0.55,0.16),  c(0.92,0.27,0.35)])

    // ── JOYFUL ────────────────────────────────────────────────────────────
    static let joyfulFlowerChild   = TasteProfile("joyful_flower_child",   "Flower Child",   "leaf.fill",           [c(0.55,0.82,0.35), c(0.22,0.58,0.18)])
    static let joyfulBubblegumPop  = TasteProfile("joyful_bubblegum_pop",  "Bubblegum Pop",  "face.smiling.fill",   [c(0.99,0.50,0.75), c(0.88,0.22,0.52)])
    static let joyfulIndieKid      = TasteProfile("joyful_indie_kid",      "Indie Kid",      "headphones",          [c(0.70,0.88,0.22), c(0.38,0.62,0.08)])
    static let joyfulYoungAtHeart  = TasteProfile("joyful_young_at_heart", "Young at Heart", "figure.walk",         [c(0.22,0.70,0.96), c(0.08,0.42,0.70)])
    static let joyfulDefault       = TasteProfile("joyful_default",        "Joy Seeker",     "face.smiling.fill",   [c(1.0,0.74,0.16),  c(0.96,0.45,0.18)])

    // ── TENDER ────────────────────────────────────────────────────────────
    static let tenderCanyonSoul        = TasteProfile("tender_canyon_soul",       "Canyon Soul",      "guitars.fill",       [c(0.88,0.55,0.28), c(0.60,0.28,0.12)])
    static let tenderRomantic          = TasteProfile("tender_romantic",          "Romantic",         "heart.fill",         [c(0.96,0.22,0.48), c(0.72,0.08,0.32)])
    static let tenderHopelessRomantic  = TasteProfile("tender_hopeless_romantic", "Hopeless Romantic","heart.circle.fill",  [c(0.80,0.38,0.80), c(0.48,0.18,0.58)])
    static let tenderDefault           = TasteProfile("tender_default",           "Tender Soul",      "heart.fill",         [c(0.96,0.34,0.50), c(0.79,0.16,0.50)])

    // ── SERENE ────────────────────────────────────────────────────────────
    static let sereneFreeSpirit      = TasteProfile("serene_free_spirit",     "Free Spirit",      "bird.fill",       [c(0.42,0.78,0.62), c(0.18,0.52,0.42)])
    static let sereneMellowSoul      = TasteProfile("serene_mellow_soul",     "Mellow Soul",      "sun.haze.fill",   [c(0.62,0.72,0.40), c(0.32,0.46,0.16)])
    static let sereneAmbientWanderer = TasteProfile("serene_ambient_wanderer","Ambient Wanderer",  "wave.3.right",    [c(0.08,0.55,0.72), c(0.04,0.30,0.48)])
    static let sereneDefault         = TasteProfile("serene_default",         "Still Waters",     "leaf.fill",       [c(0.18,0.72,0.58), c(0.05,0.45,0.50)])

    // ── DREAMY ────────────────────────────────────────────────────────────
    static let dreamyNeonRider    = TasteProfile("dreamy_neon_rider",    "Neon Rider",     "bolt.fill",        [c(0.52,0.18,0.92), c(0.08,0.52,0.90)])
    static let dreamyShoegazeKid  = TasteProfile("dreamy_shoegaze_kid",  "Shoegaze Kid",   "headphones",       [c(0.58,0.42,0.72), c(0.28,0.18,0.48)])
    static let dreamyIndieMystic  = TasteProfile("dreamy_indie_mystic",  "Indie Mystic",   "moon.stars.fill",  [c(0.22,0.32,0.80), c(0.08,0.52,0.62)])
    static let dreamyDreamChaser  = TasteProfile("dreamy_dream_chaser",  "Dream Chaser",   "sparkle",          [c(0.70,0.50,0.90), c(0.42,0.22,0.72)])
    static let dreamyDefault      = TasteProfile("dreamy_default",       "Cloud Drifter",  "moon.haze.fill",   [c(0.55,0.50,0.90), c(0.30,0.26,0.62)])

    // ── NOSTALGIC ─────────────────────────────────────────────────────────
    static let nostalgicRockPilgrim     = TasteProfile("nostalgic_rock_pilgrim",      "Rock Pilgrim",      "guitars.fill",              [c(0.70,0.46,0.18), c(0.42,0.24,0.08)])
    static let nostalgic80sTimeTraveler = TasteProfile("nostalgic_80s_time_traveler", "80s Time Traveler", "clock.arrow.circlepath",    [c(0.90,0.62,0.18), c(0.62,0.36,0.08)])
    static let nostalgic90sKid          = TasteProfile("nostalgic_90s_kid",           "90s Kid",           "cassette.fill",             [c(0.42,0.45,0.72), c(0.20,0.22,0.45)])
    static let nostalgicMemoryKeeper    = TasteProfile("nostalgic_memory_keeper",     "Memory Keeper",     "photo.on.rectangle.angled", [c(0.78,0.60,0.35), c(0.52,0.35,0.15)])
    static let nostalgicDefault         = TasteProfile("nostalgic_default",           "Sentimentalist",    "clock.arrow.circlepath",    [c(0.92,0.62,0.20), c(0.66,0.36,0.14)])

    // ── MELANCHOLY ────────────────────────────────────────────────────────
    static let melancholyDarkWaver         = TasteProfile("melancholy_dark_waver",         "Dark Waver",         "moon.stars.fill",  [c(0.42,0.31,0.93), c(0.18,0.13,0.45)])
    static let melancholyGrungeKid         = TasteProfile("melancholy_grunge_kid",         "Grunge Kid",         "guitars.fill",     [c(0.42,0.46,0.36), c(0.20,0.22,0.15)])
    static let melancholyIndieConfessor    = TasteProfile("melancholy_indie_confessor",    "Indie Confessor",    "mic.fill",         [c(0.18,0.26,0.50), c(0.08,0.12,0.28)])
    static let melancholyIndieHeartbreaker = TasteProfile("melancholy_indie_heartbreaker", "Indie Heartbreaker","heart.slash.fill",  [c(0.62,0.15,0.58), c(0.32,0.06,0.32)])
    static let melancholyDefault           = TasteProfile("melancholy_default",            "Brooder",            "cloud.moon.fill",  [c(0.34,0.40,0.62), c(0.16,0.20,0.38)])

    // ── DEFIANT ───────────────────────────────────────────────────────────
    static let defiantPunkPurist   = TasteProfile("defiant_punk_purist",   "Punk Purist",    "megaphone.fill",  [c(0.80,0.08,0.08), c(0.40,0.04,0.04)])
    static let defiantRockRebel    = TasteProfile("defiant_rock_rebel",    "Rock Rebel",     "guitars.fill",    [c(0.92,0.36,0.08), c(0.58,0.16,0.04)])
    static let defiantGrungeRebel  = TasteProfile("defiant_grunge_rebel",  "Grunge Rebel",   "flame.fill",      [c(0.62,0.22,0.12), c(0.32,0.09,0.04)])
    static let defiantProtestRebel = TasteProfile("defiant_protest_rebel", "Protest Rebel",  "megaphone.fill",  [c(0.86,0.20,0.18), c(0.50,0.10,0.10)])
    static let defiantChampion     = TasteProfile("defiant_champion",      "Champion",       "figure.stand",    [c(0.88,0.70,0.08), c(0.70,0.28,0.08)])
    static let defiantDefault      = TasteProfile("defiant_default",       "Defiant Spirit", "flame.fill",      [c(0.90,0.32,0.16), c(0.55,0.12,0.10)])

    // ── DARK ──────────────────────────────────────────────────────────────
    static let darkPostPunkPoet    = TasteProfile("dark_post_punk_poet",   "Post-Punk Poet",  "mic.fill",               [c(0.26,0.20,0.45), c(0.09,0.07,0.20)])
    static let darkIndustrialHeart = TasteProfile("dark_industrial_heart", "Industrial Heart","gearshape.fill",          [c(0.26,0.26,0.30), c(0.09,0.09,0.12)])
    static let darkGothSoul        = TasteProfile("dark_goth_soul",        "Goth Soul",       "moon.zzz.fill",           [c(0.38,0.15,0.55), c(0.14,0.05,0.26)])
    static let darkNoirSoul        = TasteProfile("dark_noir_soul",        "Noir Soul",       "smoke.fill",              [c(0.42,0.12,0.25), c(0.16,0.04,0.10)])
    static let darkDarkRebel       = TasteProfile("dark_dark_rebel",       "Dark Rebel",      "bolt.fill",               [c(0.52,0.10,0.10), c(0.18,0.04,0.04)])
    static let darkDefault         = TasteProfile("dark_default",          "Midnight Drifter","circle.lefthalf.filled",  [c(0.30,0.28,0.40), c(0.12,0.11,0.18)])

    // ── BALANCED ──────────────────────────────────────────────────────────
    static let balancedDefault = TasteProfile("balanced_default", "Eclectic", "circle.grid.2x2.fill", [c(0.21,0.49,0.93), c(0.11,0.31,0.70)])

    // MARK: - resolve

    /// Resolve from the user's dominant mood + single winning modifier category
    /// (could be a decade like "1980s", a theme like "Heartbreak", or a genre).
    static func resolve(mood: String?, modifier: String?) -> TasteProfile {
        switch (mood, modifier) {

        // ── EUPHORIC ──────────────────────────────────────────────────────
        case ("Euphoric", let d?) where isDecade(d, atLeast: 1970) && !isDecade(d, atLeast: 1980):
            return euphoricDiscoKid
        case ("Euphoric", let d?) where isDecade(d, atLeast: 1980) && !isDecade(d, atLeast: 1990):
            return euphoricSynthPopKid
        case ("Euphoric", let d?) where isDecade(d, atLeast: 2010):
            return euphoricFestivalKid
        case ("Euphoric", "Empowerment & Self-Worth"), ("Euphoric", "Hope & Perseverance"):
            return euphoricAnthemist
        case ("Euphoric", _):
            return euphoricDefault

        // ── JOYFUL ────────────────────────────────────────────────────────
        case ("Joyful", let d?) where isDecade(d, atLeast: 1960) && !isDecade(d, atLeast: 1980):
            return joyfulFlowerChild
        case ("Joyful", let d?) where isDecade(d, atLeast: 2000) && !isDecade(d, atLeast: 2020):
            return joyfulBubblegumPop
        case ("Joyful", "Indie"):
            return joyfulIndieKid
        case ("Joyful", "Coming of Age"):
            return joyfulYoungAtHeart
        case ("Joyful", _):
            return joyfulDefault

        // ── TENDER ────────────────────────────────────────────────────────
        case ("Tender", let d?) where isDecade(d, atLeast: 1960) && !isDecade(d, atLeast: 1980):
            return tenderCanyonSoul
        case ("Tender", "Love & Romance"), ("Tender", "Longing & Desire"):
            return tenderRomantic
        case ("Tender", "Heartbreak"):
            return tenderHopelessRomantic
        case ("Tender", _):
            return tenderDefault

        // ── SERENE ────────────────────────────────────────────────────────
        case ("Serene", "Freedom & Escape"), ("Serene", "Coming of Age"):
            return sereneFreeSpirit
        case ("Serene", let d?) where isDecade(d, atLeast: 1960) && !isDecade(d, atLeast: 1990):
            return sereneMellowSoul
        case ("Serene", let d?) where isDecade(d, atLeast: 2000):
            return sereneAmbientWanderer
        case ("Serene", _):
            return sereneDefault

        // ── DREAMY ────────────────────────────────────────────────────────
        case ("Dreamy", let d?) where isDecade(d, atLeast: 1980) && !isDecade(d, atLeast: 1990):
            return dreamyNeonRider
        case ("Dreamy", let d?) where isDecade(d, atLeast: 1990) && !isDecade(d, atLeast: 2000):
            return dreamyShoegazeKid
        case ("Dreamy", "Longing & Desire"), ("Dreamy", "Memory & Nostalgia"):
            return dreamyDreamChaser
        case ("Dreamy", "Indie"):
            return dreamyIndieMystic
        case ("Dreamy", _):
            return dreamyDefault

        // ── NOSTALGIC ─────────────────────────────────────────────────────
        case ("Nostalgic", let d?) where isDecade(d, atLeast: 1980) && !isDecade(d, atLeast: 1990):
            return nostalgic80sTimeTraveler
        case ("Nostalgic", let d?) where isDecade(d, atLeast: 1990) && !isDecade(d, atLeast: 2000):
            return nostalgic90sKid
        case ("Nostalgic", "Rock"):
            return nostalgicRockPilgrim
        case ("Nostalgic", "Memory & Nostalgia"):
            return nostalgicMemoryKeeper
        case ("Nostalgic", _):
            return nostalgicDefault

        // ── MELANCHOLY ────────────────────────────────────────────────────
        case ("Melancholy", let d?) where isDecade(d, atLeast: 1980) && !isDecade(d, atLeast: 1990):
            return melancholyDarkWaver
        case ("Melancholy", let d?) where isDecade(d, atLeast: 1990) && !isDecade(d, atLeast: 2000):
            return melancholyGrungeKid
        case ("Melancholy", "Heartbreak"):
            return melancholyIndieHeartbreaker
        case ("Melancholy", "Loneliness"):
            return melancholyIndieConfessor
        case ("Melancholy", _):
            return melancholyDefault

        // ── DEFIANT ───────────────────────────────────────────────────────
        case ("Defiant", "Rebellion & Protest"):
            return defiantProtestRebel
        case ("Defiant", let d?) where isDecade(d, atLeast: 1990) && !isDecade(d, atLeast: 2000):
            return defiantGrungeRebel
        case ("Defiant", let d?) where isDecade(d, atLeast: 1970) && !isDecade(d, atLeast: 1990):
            return defiantRockRebel
        case ("Defiant", "Empowerment & Self-Worth"), ("Defiant", "Hope & Perseverance"):
            return defiantChampion
        case ("Defiant", "Punk"):
            return defiantPunkPurist
        case ("Defiant", _):
            return defiantDefault

        // ── DARK ──────────────────────────────────────────────────────────
        case ("Dark", let d?) where isDecade(d, atLeast: 1980) && !isDecade(d, atLeast: 1990):
            return darkPostPunkPoet
        case ("Dark", "Industrial"):
            return darkIndustrialHeart
        case ("Dark", "Gothic"), ("Dark", "Goth"):
            return darkGothSoul
        case ("Dark", "Loneliness"), ("Dark", "Longing & Desire"):
            return darkNoirSoul
        case ("Dark", "Rebellion & Protest"):
            return darkDarkRebel
        case ("Dark", _):
            return darkDefault

        // ── BALANCED (no dominant mood) ───────────────────────────────────
        default:
            return balancedDefault
        }
    }

    // MARK: - helper

    /// True when `decade` string (e.g. "1980s") starts with a year >= `year`.
    private static func isDecade(_ decade: String, atLeast year: Int) -> Bool {
        guard decade.count >= 4, let y = Int(decade.prefix(4)) else { return false }
        return y >= year
    }
}
```

- [ ] **Step 2 — Update TasteMirror.build() resolve call to new signature (TasteMirror.swift)**

The old call (lines 83–85):
```swift
TasteProfile.resolve(mood: mood.topStandout?.name,
                     decade: decade.topStandout?.name,
                     theme: theme.topStandout?.name)
```

Replace with (modifier: nil — the real modifier is wired in Task 3):
```swift
TasteProfile.resolve(mood: mood.topStandout?.name,
                     modifier: nil)
```

- [ ] **Step 3 — Fix archetype ID assertions in TasteMirrorTests.swift**

`archetypeUnlocksWithEnoughRatings` now expects `melancholy_default` (modifier is nil until Task 3 wires the selector):
```swift
@Test func archetypeUnlocksWithEnoughRatings() {
    let m = TasteMirror.build(from: Self.workedExample())   // 30 ratings ≥ 10 → unlocked
    #expect(m.isArchetypeUnlocked == true)
    #expect(m.archetype?.id == "melancholy_default")        // modifier nil until Task 3
}
```

`archetypeFallsBackToMoodOnly` changes ID only:
```swift
@Test func archetypeFallsBackToMoodOnly() {
    let m = TasteMirror.build(from: Self.mood("Melancholy", likes: 18, dislikes: 6))
    #expect(m.archetype?.id == "melancholy_default")
}
```

- [ ] **Step 4 — Run the tests**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug test 2>&1 | grep -E "Test (passed|failed|Suite|Case)|error:"
```
Expected: all tests pass.

- [ ] **Step 5 — Commit**

```bash
git add "Daily Music/Models/TasteProfile.swift" \
        "Daily Music/Models/TasteMirror.swift" \
        "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat(insights): expand archetype catalogue to 46 entries with new resolve(mood:modifier:)"
```

---

## Task 3 — WinningModifier + modifier selector + songs() helpers

**Why:** This wires the intelligence that picks *which* cross-dimension over-index becomes the archetype modifier. The loop checks decade → theme → genre → language and keeps the dimension with the highest margin above overall. `songs(inDimension:category:)` and `songs(forDimensionID:category:)` expose the stored rated songs filtered by any dimension/category pair for the drill-down sheet.

**Files:**
- Modify: `Daily Music/Models/TasteMirror.swift`
- Modify: `Daily MusicTests/TasteMirrorTests.swift`

- [ ] **Step 1 — Add `WinningModifier` struct to TasteMirror.swift (after `EnergyInsight`)**

```swift
/// The single cross-dimension modifier that most over-indexes vs the user's average.
/// Captures enough context to produce dynamic hero copy.
struct WinningModifier: Equatable {
    let dimensionID: String    // "decade" | "theme" | "genre" | "language"
    let categoryName: String   // e.g. "1980s", "Heartbreak", "Rock"
    let likeRate: Double       // like-rate within this category
    let total: Int             // total ratings in this category
    let margin: Double         // likeRate − overallLikeRate
}
```

- [ ] **Step 2 — Add `winningModifier` field to `TasteMirror` struct (after `ratedSongs`)**

```swift
struct TasteMirror: Equatable {
    let totalRated: Int
    let overallLikeRate: Double
    let mood: DimensionInsight
    let decade: DimensionInsight
    let theme: DimensionInsight
    let genre: DimensionInsight
    let language: DimensionInsight
    let energy: EnergyInsight
    let archetype: TasteProfile?
    let isArchetypeUnlocked: Bool
    let ratedSongs: [RatedSong]
    let winningModifier: WinningModifier?   // ← add this
```

- [ ] **Step 3 — Add modifier selector loop in `build()`, update `resolve()` call, update `TasteMirror(...)` return**

Replace the archetype block in `build()` (currently lines 81–93) with:

```swift
// --- modifier selector ---
// Loop [decade, theme, genre, language] in priority order; keep the dimension
// whose over-index margin above overall is highest. First-seen-maximum ensures
// decade wins on a tie (array order).
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

// --- archetype ---
let isArchetypeUnlocked = total >= Thresholds.minRatedArchetype
let archetype: TasteProfile? = isArchetypeUnlocked
    ? TasteProfile.resolve(mood: mood.topStandout?.name,
                           modifier: winningModifier?.categoryName)
    : nil

return TasteMirror(
    totalRated: total, overallLikeRate: overall,
    mood: mood, decade: decade, theme: theme, genre: genre, language: language,
    energy: energy, archetype: archetype, isArchetypeUnlocked: isArchetypeUnlocked,
    ratedSongs: rated, winningModifier: winningModifier
)
```

- [ ] **Step 4 — Add `songs` helpers at the bottom of TasteMirror.swift (in the extension block)**

Append inside the existing `extension TasteMirror { ... }`:

```swift
// MARK: drill-down queries

/// All rated songs that belong to `category` in the given dimension, liked first
/// then reverse-chronological.
func songs(inDimension dimension: DimensionInsight, category: String) -> [RatedSong] {
    songs(forDimensionID: dimension.id, category: category)
}

/// Same as `songs(inDimension:category:)` but identified by raw dimension string ID
/// (needed for energy, whose insight type is `EnergyInsight`, not `DimensionInsight`).
func songs(forDimensionID dimensionID: String, category: String) -> [RatedSong] {
    func tag(_ entry: DailyEntry) -> String? {
        switch dimensionID {
        case "mood":     return entry.mood
        case "decade":   return entry.decade
        case "theme":    return entry.theme
        case "genre":    return entry.genre
        case "language": return entry.language
        case "energy":   return entry.energy.map { EnergyBand.band(for: $0).rawValue }
        default:         return nil
        }
    }
    return ratedSongs
        .filter { tag($0.entry) == category }
        .sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.entry.date > $1.entry.date
        }
}
```

- [ ] **Step 5 — Update tests: fix archetype ID + add 5 new tests (TasteMirrorTests.swift)**

**5a.** Fix `archetypeUnlocksWithEnoughRatings` — the worked example now has decade "1980s" as modifier (margin 0.218), so it routes to `melancholy_dark_waver`:

```swift
@Test func archetypeUnlocksWithEnoughRatings() {
    // Worked example: Melancholy dominant, decade "1980s" over-indexes at 81.8% vs 60% overall.
    // Modifier selector picks "1980s" → melancholy_dark_waver.
    let m = TasteMirror.build(from: Self.workedExample())
    #expect(m.isArchetypeUnlocked == true)
    #expect(m.archetype?.id == "melancholy_dark_waver")
}
```

**5b.** Add `ratedSongsStoredOnMirror`:

```swift
@Test func ratedSongsStoredOnMirror() {
    let data = Self.workedExample()
    let m = TasteMirror.build(from: data)
    #expect(m.ratedSongs.count == data.count)
}
```

**5c.** Add `modifierSelectorPicksHighestMargin`:

```swift
@Test func modifierSelectorPicksHighestMargin() {
    // Decade "1980s": 9/11 = 81.8% (margin +21.8pp above 60% overall)
    // No theme/genre over-index in worked example → decade wins.
    let m = TasteMirror.build(from: Self.workedExample())
    #expect(m.winningModifier?.dimensionID == "decade")
    #expect(m.winningModifier?.categoryName == "1980s")
}
```

**5d.** Add `modifierSelectorPrefersThemeOverDecadeWhenMarginHigher`:

```swift
@Test func modifierSelectorPrefersThemeOverDecadeWhenMarginHigher() {
    // 30 songs: 11 Melancholy/1980s/Heartbreak + rest spread.
    // Give Heartbreak theme a higher over-index margin than decade.
    // Heartbreak: 9 liked, 0 disliked → 100% (margin +40pp)
    // Decade 1980s: 9 liked, 2 disliked → 81.8% (margin +21.8pp)
    // Overall = 18/30 = 60%
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
```

**5e.** Add `modifierNilWhenNoOverIndex`:

```swift
@Test func modifierNilWhenNoOverIndex() {
    // All songs same mood, no year/theme/genre → no dimension over-indexes.
    let data = Self.mood("Melancholy", likes: 18, dislikes: 6)
    let m = TasteMirror.build(from: data)
    #expect(m.winningModifier == nil)
}
```

**5f.** Add `songsFilteredByDimensionCategory`:

```swift
@Test func songsFilteredByDimensionCategory() {
    // 9 Melancholy/1980s + 2 Melancholy/1980s disliked + other moods.
    let data = Self.workedExample()
    let m = TasteMirror.build(from: data)
    let melancholySongs = m.songs(inDimension: m.mood, category: "Melancholy")
    // 9 liked + 2 disliked = 11 Melancholy songs; liked come first.
    #expect(melancholySongs.count == 11)
    #expect(melancholySongs.first?.value == 1)   // liked first
}
```

- [ ] **Step 6 — Run the tests**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug test 2>&1 | grep -E "Test (passed|failed|Suite|Case)|error:"
```
Expected: all tests pass.

- [ ] **Step 7 — Commit**

```bash
git add "Daily Music/Models/TasteMirror.swift" \
        "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat(insights): add WinningModifier, cross-dimension modifier selector, and songs() drill-down helpers"
```

---

## Task 4 — Dynamic heroWhy() + songs in StandoutRow/StandoutDetail

**Why:** The hero card copy should cite real numbers from the user's taste (e.g. "Because you keep 82% of 1980s songs — 22pts above your 60% average."). `StandoutRow` and `StandoutDetail` need a `songs: [RatedSong]` field so the rows can hand their songs to the drill-down sheet added in Task 5.

**Files:**
- Modify: `Daily Music/Views/StandoutDetailView.swift`
- Modify: `Daily Music/Views/Components/TasteMirrorBoard.swift`

- [ ] **Step 1 — Add `songs` fields to `StandoutRow` and `StandoutDetail` (StandoutDetailView.swift)**

Replace the two structs (lines 13–34):

```swift
/// One category row inside a dimension detail (e.g. a single mood).
struct StandoutRow: Identifiable, Equatable {
    let id: String
    let name: String
    let symbol: String?
    let likes: Int
    let total: Int
    let songs: [RatedSong]                              // ← new
    var likeRate: Double { total > 0 ? Double(likes) / Double(total) : 0 }
}

/// Everything the detail sheet needs for one tapped standout. Identifiable so it
/// can drive `.sheet(item:)`.
struct StandoutDetail: Identifiable, Equatable {
    let id: String
    let title: String
    let accent: Color
    let featuredName: String
    let featuredSymbol: String
    let featuredLine: String
    let featuredSongs: [RatedSong]                      // ← new
    let rows: [StandoutRow]
    let standoutID: String?
    let skipID: String?
}
```

- [ ] **Step 2 — Update `makeDetail()` in TasteMirrorBoard.swift to populate songs**

Replace the existing `makeDetail()` function (lines 218–233):

```swift
private func makeDetail(dim: DimensionInsight, accent: Color) -> StandoutDetail? {
    guard let featured = dim.topStandout else { return nil }
    let rows = dim.categories
        .filter { $0.id != featured.id }
        .map { cat in
            StandoutRow(id: cat.id, name: cat.name,
                        symbol: categorySymbol(dim.id, cat.name),
                        likes: cat.likes, total: cat.total,
                        songs: mirror.songs(inDimension: dim, category: cat.name))
        }
    return StandoutDetail(
        id: dim.title, title: dim.title, accent: accent,
        featuredName: featured.name,
        featuredSymbol: categorySymbol(dim.id, featured.name) ?? dimIcon(dim.id),
        featuredLine: "Keeps \(featured.likes) of \(featured.total) — \(Int(featured.likeRate * 100))% yes.",
        featuredSongs: mirror.songs(inDimension: dim, category: featured.name),
        rows: rows,
        standoutID: dim.overIndex?.id,
        skipID: dim.skip?.id
    )
}
```

- [ ] **Step 3 — Update `makeEnergyDetail()` in TasteMirrorBoard.swift to populate songs**

Replace the existing `makeEnergyDetail()` function (lines 235–249):

```swift
private func makeEnergyDetail(_ energy: EnergyInsight, accent: Color) -> StandoutDetail? {
    guard let lean = energy.leanLabel, let mean = energy.likedMean else { return nil }
    let order = ["Low": 0, "Medium": 1, "High": 2]
    let rows = energy.bands
        .sorted { (order[$0.name] ?? 9) < (order[$1.name] ?? 9) }
        .map { band in
            StandoutRow(id: band.id, name: "\(band.name) energy", symbol: nil,
                        likes: band.likes, total: band.total,
                        songs: mirror.songs(forDimensionID: "energy", category: band.id))
        }
    // Map leanLabel → EnergyBand raw value for the featured songs lookup.
    let featuredBandID: String = {
        switch lean {
        case "Intimate":  return "Low"
        case "Explosive": return "High"
        default:          return "Medium"
        }
    }()
    return StandoutDetail(
        id: "Energy", title: "Energy", accent: accent,
        featuredName: lean,
        featuredSymbol: "bolt.fill",
        featuredLine: "Liked songs average \(String(format: "%.1f", mean)) out of 5.",
        featuredSongs: mirror.songs(forDimensionID: "energy", category: featuredBandID),
        rows: rows, standoutID: nil, skipID: nil
    )
}
```

- [ ] **Step 4 — Replace `heroWhy()` in TasteMirrorBoard.swift with the dynamic version**

Replace the existing `heroWhy()` function (lines 87–95):

```swift
/// Dynamic "why it's you" — cites the winning modifier's real stats.
private func heroWhy(_ mirror: TasteMirror) -> String {
    let moodStat  = mirror.mood.topStandout
    let moodName  = moodStat?.name.lowercased() ?? "certain"
    let overall   = Int(mirror.overallLikeRate * 100)
    let keep      = isCurrentUser ? "you keep" : "they keep"
    let your      = isCurrentUser ? "your" : "their"

    guard let wm = mirror.winningModifier else {
        let pct = Int((moodStat?.likeRate ?? 0) * 100)
        return "Because \(keep) \(moodName) songs more than anything else (\(pct)% yes vs \(overall)% overall)."
    }

    let pct    = Int(wm.likeRate * 100)
    let margin = Int(wm.margin * 100)
    switch wm.dimensionID {
    case "decade":
        return "Because \(keep) \(pct)% of \(wm.categoryName) songs — \(margin)pts above \(your) \(overall)% average."
    case "theme":
        return "Because \(keep) \(pct)% of songs about \(wm.categoryName.lowercased()) — \(margin)pts above average."
    case "genre":
        return "Because \(keep) \(pct)% of \(wm.categoryName) tracks — \(margin)pts above \(your) \(overall)% overall."
    default:
        let pct2 = Int((moodStat?.likeRate ?? 0) * 100)
        return "Because \(keep) \(moodName) songs more than anything else (\(pct2)% yes vs \(overall)% overall)."
    }
}
```

- [ ] **Step 5 — Build to verify no compile errors**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | grep -E "error:|warning:|BUILD"
```
Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 6 — Commit**

```bash
git add "Daily Music/Views/StandoutDetailView.swift" \
        "Daily Music/Views/Components/TasteMirrorBoard.swift"
git commit -m "feat(insights): dynamic hero copy from winning modifier; pass songs into StandoutRow/Detail"
```

---

## Task 5 — CategorySongsSheet + StandoutDetailView drill-down

**Why:** Users should be able to tap any category row (or the featured standout) and see the exact songs that drove that insight — liked ones first, then disliked.

**Files:**
- Create: `Daily Music/Views/Components/CategorySongsSheet.swift`
- Modify: `Daily Music/Views/StandoutDetailView.swift`

- [ ] **Step 1 — Create CategorySongsSheet.swift**

Create the file at `Daily Music/Views/Components/CategorySongsSheet.swift`:

```swift
//
//  CategorySongsSheet.swift
//  Daily Music
//
//  Bottom sheet listing the rated songs that belong to one insight category.
//  Liked songs appear first, then disliked, both reverse-chronological within
//  their group. Presented from StandoutDetailView when any row is tapped.
//

import SwiftUI

struct CategorySongsSheet: View {
    let title: String
    let songs: [RatedSong]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty {
                    ContentUnavailableView(
                        "No songs yet",
                        systemImage: "music.note.list",
                        description: Text("Rate more songs in this category to see them here.")
                    )
                } else {
                    List(songs, id: \.entry.id) { rated in
                        songRow(rated)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.regularMaterial)
        .presentationCornerRadius(34)
        .presentationDragIndicator(.visible)
    }

    private func songRow(_ rated: RatedSong) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            AsyncImage(url: rated.entry.albumArtURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(rated.entry.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(rated.entry.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(rated.value > 0 ? "👍" : "👎")
                .font(.title3)
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 2 — Add `CategoryDrill` struct and `drill` state to StandoutDetailView.swift**

Add the `CategoryDrill` struct just above `StandoutDetailView` (after the closing brace of `StandoutDetail`):

```swift
/// Drives the per-category song list sheet from StandoutDetailView.
struct CategoryDrill: Identifiable {
    let id: String          // category name (unique within one sheet)
    let name: String
    let songs: [RatedSong]
}
```

Add the state property inside `StandoutDetailView`:

```swift
struct StandoutDetailView: View {
    let detail: StandoutDetail
    @Environment(\.dismiss) private var dismiss
    @State private var drill: CategoryDrill?    // ← add this
```

- [ ] **Step 3 — Make the featured card tappable (StandoutDetailView.swift)**

Wrap the `featured` property call with a `Button` inside `body`. Replace:

```swift
featured
```

With:

```swift
Button {
    drill = CategoryDrill(id: detail.featuredName,
                          name: detail.featuredName,
                          songs: detail.featuredSongs)
} label: {
    featured
}
.buttonStyle(.plain)
```

- [ ] **Step 4 — Make each row tappable in `body` (StandoutDetailView.swift)**

In the `ForEach(detail.rows)` loop, replace `rowView($0)` with a tappable `Button`:

```swift
ForEach(detail.rows) { row in
    Button {
        drill = CategoryDrill(id: row.id,
                              name: row.name,
                              songs: row.songs)
    } label: {
        rowView(row)
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 5 — Attach the drill sheet to the ScrollView (StandoutDetailView.swift)**

Add `.sheet(item: $drill)` directly after the `.presentationDragIndicator(.visible)` modifier on the `ScrollView`:

```swift
.sheet(item: $drill) { d in
    CategorySongsSheet(title: d.name, songs: d.songs)
}
```

- [ ] **Step 6 — Build to verify no compile errors**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | grep -E "error:|warning:|BUILD"
```
Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 7 — Commit**

```bash
git add "Daily Music/Views/Components/CategorySongsSheet.swift" \
        "Daily Music/Views/StandoutDetailView.swift"
git commit -m "feat(insights): tap any category row to see contributing songs in CategorySongsSheet"
```

---

## Self-Review

**Spec coverage check:**

| Requirement | Task |
|---|---|
| Fix `dominant` to rank by net score | Task 1 ✓ |
| Store `ratedSongs` on TasteMirror | Task 1 ✓ |
| 46-entry catalogue, 9 moods × variants | Task 2 ✓ |
| New `resolve(mood:modifier:)` signature | Task 2 ✓ |
| `isDecade(_:atLeast:)` helper | Task 2 ✓ |
| `WinningModifier` struct | Task 3 ✓ |
| Cross-dimension modifier selector loop | Task 3 ✓ |
| `songs(inDimension:)` / `songs(forDimensionID:)` | Task 3 ✓ |
| Dynamic `heroWhy()` citing real stats | Task 4 ✓ |
| `featuredSongs` in `StandoutDetail` | Task 4 ✓ |
| `songs` in `StandoutRow` | Task 4 ✓ |
| `CategorySongsSheet` | Task 5 ✓ |
| Drill-down from featured card | Task 5 ✓ |
| Drill-down from all rows | Task 5 ✓ |

**Type consistency check:**
- `WinningModifier` defined in Task 3 Step 1, referenced in Task 3 Steps 2–3. ✓
- `songs(inDimension:category:)` defined in Task 3 Step 4, called in Task 4 Steps 2–3. ✓
- `songs(forDimensionID:category:)` defined in Task 3 Step 4, called in Task 4 Step 3 (`makeEnergyDetail`). ✓
- `StandoutRow(songs:)` field added in Task 4 Step 1, all call sites updated in Task 4 Steps 2–3. ✓
- `StandoutDetail(featuredSongs:)` field added in Task 4 Step 1, all call sites updated in Task 4 Steps 2–3. ✓
- `CategoryDrill` defined in Task 5 Step 2, used in Task 5 Steps 3–5. ✓
- `CategorySongsSheet(title:songs:)` created in Task 5 Step 1, called in Task 5 Step 5. ✓

**Placeholder scan:** No TBDs, no "similar to Task N" references, no steps without code. ✓
