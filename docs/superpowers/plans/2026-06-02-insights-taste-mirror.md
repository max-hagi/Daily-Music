# Insights Taste-Mirror Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Insights tab with a transparent "taste mirror" — 👍/👎 ratings × hand-tagged song attributes (mood/decade/theme/energy/genre/language) counted into per-dimension standouts and a synthesized archetype, with progressive reveal. No AI/scoring.

**Architecture:** A pure, unit-tested `TasteMirror` engine turns `[(DailyEntry, rating)]` into per-dimension insights + a resolved `TasteProfile` archetype. A new `RatingService` (Mock + Supabase) stores 👍/👎 in a `song_ratings` table. `InsightsViewModel` feeds the engine from `EntryService` + `RatingService`; `InsightsView` renders hero/standout-strip/breakdown. A `RatingBar` is added to `EntryDetailView` next to the existing heart/reactions. ❤️ favorites and 🔥❤️😌💫 reactions are unchanged.

**Tech Stack:** SwiftUI, `@Observable` MVVM-lite, protocol-based services behind `AppEnvironment.mock()/.live()`, Supabase (Postgres + RLS), Swift Testing for the engine.

**Spec:** `docs/superpowers/specs/2026-06-02-insights-taste-mirror-design.md`

---

## Conventions (read once)

- **Build (app):** new `.swift` files placed under `Daily Music/` auto-join the target (Xcode 16 synchronized folders). After source changes verify with:
  ```bash
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  xcodebuild build -scheme "Daily Music" \
    -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -25
  ```
  Expected: `** BUILD SUCCEEDED **`.
- **Test:** after Task 1, run the engine suite with:
  ```bash
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  xcodebuild test -scheme "Daily Music" \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:"Daily MusicTests" 2>&1 | tail -30
  ```
- **Module under test:** `@testable import Daily_Music` (spaces → underscore).
- **Ordering rationale:** the engine + rating plumbing (Tasks 2–11) never touch `TasteProfile`/`InsightsView`, so the app keeps compiling throughout. The Insights UI swap (Task 12) replaces `TasteProfile` + `InsightsViewModel` + `InsightsView` together in one commit, because changing the view-model's output type breaks the old view — they cannot be split.
- **Commit** after each task. Work on a feature branch:
  ```bash
  cd "/Users/maximesavehilaghi/Developer/Daily Music"
  git checkout -b feature/insights-taste-mirror
  ```

---

## File Structure

**Create:**
- `Daily MusicTests/TasteMirrorTests.swift` — engine unit tests
- `Daily Music/Models/MusicTaxonomy.swift` — `Mood`, `Theme`, `EnergyBand`
- `Daily Music/Models/TasteMirror.swift` — pure engine + result types
- `Daily Music/Services/RatingService.swift` — protocol + `MockRatingService`
- `Daily Music/Services/Supabase/SupabaseRatingService.swift` — live `song_ratings`
- `Daily Music/Views/RatingBar.swift` — 👍/👎 component + model
- `docs/superpowers/specs/insights-taste-mirror.sql` — Supabase migration

**Modify:**
- `Daily Music/Models/DailyEntry.swift` — add tag fields + computed `decade`
- `Daily Music/Models/TasteProfile.swift` — identifier catalogue + `resolve(mood:decade:theme:)` (Task 12)
- `Daily Music/Services/Supabase/SupabaseEntryService.swift` — decode new columns
- `Daily Music/Services/EntryService.swift` — enrich `MockEntryService`
- `Daily Music/ViewModels/InsightsViewModel.swift` — rebuild (Task 12)
- `Daily Music/Views/InsightsView.swift` — rebuild (Task 12)
- `Daily Music/Views/EntryDetailView.swift` — insert `RatingBar`
- `Daily Music/App/AppEnvironment.swift` — register `ratings`

---

## Task 1: Add the unit-test target

**Files:**
- Modify: `Daily Music.xcodeproj/project.pbxproj` (via script)
- Create: `Daily MusicTests/TasteMirrorTests.swift`, `scripts/add_test_target.rb`

- [ ] **Step 1: Install the xcodeproj gem**

Run:
```bash
gem install xcodeproj || sudo gem install xcodeproj
```
Expected: `Successfully installed xcodeproj-...`.

- [ ] **Step 2: Create a placeholder test file**

Create `Daily MusicTests/TasteMirrorTests.swift`:
```swift
import Testing
@testable import Daily_Music

struct TasteMirrorTests {
    @Test func harnessRuns() {
        #expect(true)
    }
}
```

- [ ] **Step 3: Add the test target + shared scheme via script**

Create `scripts/add_test_target.rb`:
```ruby
require 'xcodeproj'

path = 'Daily Music.xcodeproj'
project = Xcodeproj::Project.open(path)
app = project.targets.find { |t| t.name == 'Daily Music' }
raise 'app target not found' unless app

unless project.targets.any? { |t| t.name == 'Daily MusicTests' }
  test = project.new_target(:unit_test_bundle, 'Daily MusicTests', :ios, '26.5', nil, :swift)
  test.add_dependency(app)

  test.build_configurations.each do |c|
    c.build_settings['TEST_HOST'] =
      '$(BUILT_PRODUCTS_DIR)/Daily Music.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Daily Music'
    c.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'maxhagi.Daily-MusicTests'
    c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    c.build_settings['SWIFT_VERSION'] = '5.0'
    c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.5'
    c.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  end

  group = project.main_group.new_group('Daily MusicTests', 'Daily MusicTests')
  ref = group.new_file('Daily MusicTests/TasteMirrorTests.swift')
  test.add_file_references([ref])

  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(app)
  scheme.set_launch_target(app)
  scheme.add_test_target(test)
  scheme.save_as(path, 'Daily Music', true)
end

project.save
puts 'OK: test target ready'
```

Run:
```bash
ruby scripts/add_test_target.rb
```
Expected: `OK: test target ready`.

- [ ] **Step 4: Run the placeholder test**

Run the **Test** command.
Expected: `Test Suite 'TasteMirrorTests' passed`, `** TEST SUCCEEDED **`.

> One-time fallback if the gem can't edit `objectVersion = 77`: add the target in Xcode GUI (File ▸ New ▸ Target ▸ Unit Testing Bundle, name `Daily MusicTests`, host `Daily Music`), then re-run Step 4. Feature code never needs manual project edits.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music.xcodeproj" "Daily MusicTests" scripts/add_test_target.rb
git commit -m "test: add Daily MusicTests unit-test target (Swift Testing)"
```

---

## Task 2: Extend `DailyEntry` with tag fields

**Files:**
- Modify: `Daily Music/Models/DailyEntry.swift`

- [ ] **Step 1: Add the optional tag fields**

In `DailyEntry`, immediately after `var genre: String? = nil`, add:
```swift
    /// Release year (e.g. 1986). Decade is derived from it. nil until tagged.
    var year: Int? = nil
    /// Emotional tone — one of `Mood`'s raw values. nil until tagged.
    var mood: String? = nil
    /// Arousal/intensity, 1 (intimate) … 5 (explosive). nil until tagged.
    var energy: Int? = nil
    /// What the song is about — one of `Theme`'s raw values. nil until tagged.
    var theme: String? = nil
    /// Language/origin (e.g. "English"). nil/blank treated as untagged.
    var language: String? = nil
```

- [ ] **Step 2: Add the computed decade label**

After the `spotifyURL` computed property, add:
```swift
    /// Decade label derived from `year`, e.g. 1986 → "1980s". nil if untagged.
    var decade: String? {
        guard let year else { return nil }
        return "\((year / 10) * 10)s"
    }
```

- [ ] **Step 3: Verify build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Models/DailyEntry.swift"
git commit -m "feat: add mood/year/energy/theme/language tags to DailyEntry"
```

---

## Task 3: Music taxonomy (Mood + Theme source of truth)

**Files:**
- Create: `Daily Music/Models/MusicTaxonomy.swift`

- [ ] **Step 1: Create the taxonomy file**

Create `Daily Music/Models/MusicTaxonomy.swift`:
```swift
//
//  MusicTaxonomy.swift
//  Daily Music
//
//  Single source of truth for the fixed Mood/Theme vocabularies. The raw String
//  value is EXACTLY what gets stored on `daily_entries.mood` / `.theme`, so
//  tagging, validation, and chart labels never drift apart.
//

import SwiftUI

/// Emotional tone (valence/flavor). Energy carries intensity separately.
enum Mood: String, CaseIterable {
    case euphoric   = "Euphoric"
    case joyful     = "Joyful"
    case tender     = "Tender"
    case serene     = "Serene"
    case dreamy     = "Dreamy"
    case nostalgic  = "Nostalgic"
    case melancholy = "Melancholy"
    case defiant    = "Defiant"
    case dark       = "Dark"

    var symbol: String {
        switch self {
        case .euphoric:   "sparkles"
        case .joyful:     "sun.max.fill"
        case .tender:     "heart.fill"
        case .serene:     "leaf.fill"
        case .dreamy:     "moon.haze.fill"
        case .nostalgic:  "clock.arrow.circlepath"
        case .melancholy: "cloud.moon.fill"
        case .defiant:    "flame.fill"
        case .dark:       "circle.lefthalf.filled"
        }
    }
}

/// What a song is about (subject matter), distinct from how it feels.
enum Theme: String, CaseIterable {
    case love        = "Love & Romance"
    case heartbreak  = "Heartbreak"
    case longing     = "Longing & Desire"
    case loneliness  = "Loneliness"
    case memory      = "Memory & Nostalgia"
    case freedom     = "Freedom & Escape"
    case empowerment = "Empowerment & Self-Worth"
    case rebellion   = "Rebellion & Protest"
    case comingOfAge = "Coming of Age"
    case hope        = "Hope & Perseverance"

    var symbol: String {
        switch self {
        case .love:        "heart.circle.fill"
        case .heartbreak:  "heart.slash.fill"
        case .longing:     "sparkle.magnifyingglass"
        case .loneliness:  "person.fill"
        case .memory:      "photo.on.rectangle.angled"
        case .freedom:     "bird.fill"
        case .empowerment: "figure.stand"
        case .rebellion:   "megaphone.fill"
        case .comingOfAge: "graduationcap.fill"
        case .hope:        "sunrise.fill"
        }
    }
}

/// Energy band labels for the 1–5 scale.
enum EnergyBand: String {
    case low  = "Low"
    case mid  = "Medium"
    case high = "High"

    static func band(for energy: Int) -> EnergyBand {
        switch energy {
        case ...2: .low
        case 3:    .mid
        default:   .high
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Models/MusicTaxonomy.swift"
git commit -m "feat: add Mood/Theme taxonomy as single source of truth"
```

---

## Task 4: `TasteMirror` types + overall like-rate (TDD)

**Files:**
- Create: `Daily Music/Models/TasteMirror.swift`
- Test: `Daily MusicTests/TasteMirrorTests.swift`

- [ ] **Step 1: Write the failing test**

Replace `Daily MusicTests/TasteMirrorTests.swift` with:
```swift
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
}
```

- [ ] **Step 2: Run to verify it fails**

Run the **Test** command. Expected: FAIL — "cannot find 'TasteMirror'/'RatedSong' in scope".

- [ ] **Step 3: Create the engine**

Create `Daily Music/Models/TasteMirror.swift`:
```swift
//
//  TasteMirror.swift
//  Daily Music
//
//  The pure, deterministic engine behind Insights. Given the songs a user has
//  rated (👍/👎) and their hand-tagged attributes, it computes per-dimension
//  standouts and a synthesized archetype — transparent arithmetic, no I/O, no
//  scoring model. Fully unit-tested (TasteMirrorTests).
//

import Foundation

/// One rated song: a tagged entry plus the user's judgment (+1 👍 / -1 👎).
struct RatedSong: Equatable {
    let entry: DailyEntry
    let value: Int
}

/// Tallies for one category within a dimension (e.g. mood "Melancholy").
struct CategoryStat: Equatable, Identifiable {
    let name: String
    let likes: Int
    let dislikes: Int
    var total: Int { likes + dislikes }
    var likeRate: Double { total > 0 ? Double(likes) / Double(total) : 0 }
    var id: String { name }
}

/// A categorical dimension's full picture (mood/decade/theme/genre/language).
struct DimensionInsight: Equatable, Identifiable {
    let id: String
    let title: String
    let categories: [CategoryStat]
    let dominant: CategoryStat?
    let overIndex: CategoryStat?
    let skip: CategoryStat?
    let isUnlocked: Bool
}

/// Energy is scalar: a lean from liked songs + a 3-band like-rate breakdown.
struct EnergyInsight: Equatable {
    let likedMean: Double?
    let leanLabel: String?
    let bands: [CategoryStat]
    let isUnlocked: Bool
}

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

    enum Thresholds {
        static let minPerCategory = 3
        static let overIndexMargin = 0.10
        static let minRatedDimension = 10
        static let minRatedArchetype = 20
    }

    static func build(from rated: [RatedSong]) -> TasteMirror {
        let total = rated.count
        let likes = rated.filter { $0.value > 0 }.count
        let overall = total > 0 ? Double(likes) / Double(total) : 0

        // --- dimensions (replaced in Task 5) ---
        let empty = DimensionInsight(id: "", title: "", categories: [],
                                     dominant: nil, overIndex: nil, skip: nil, isUnlocked: false)
        let mood = empty, decade = empty, theme = empty, genre = empty, language = empty
        // --- energy (replaced in Task 6) ---
        let energy = EnergyInsight(likedMean: nil, leanLabel: nil, bands: [], isUnlocked: false)
        // --- archetype (replaced in Task 12) ---
        let archetype: TasteProfile? = nil
        let isArchetypeUnlocked = false

        return TasteMirror(
            totalRated: total, overallLikeRate: overall,
            mood: mood, decade: decade, theme: theme, genre: genre, language: language,
            energy: energy, archetype: archetype, isArchetypeUnlocked: isArchetypeUnlocked
        )
    }
}
```

> `TasteProfile` already exists; the `archetype: TasteProfile?` field compiles against the current struct (it's only set to `nil` here until Task 12).

- [ ] **Step 4: Run to verify it passes**

Run the **Test** command. Expected: PASS, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/TasteMirror.swift" "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat: TasteMirror engine skeleton + overall like-rate (TDD)"
```

---

## Task 5: Categorical math — dominant / over-index / skip (TDD)

**Files:**
- Modify: `Daily Music/Models/TasteMirror.swift`
- Test: `Daily MusicTests/TasteMirrorTests.swift`

- [ ] **Step 1: Write the failing tests**

Append inside `struct TasteMirrorTests` (before its closing brace):
```swift
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
```

- [ ] **Step 2: Run to verify they fail**

Run the **Test** command. Expected: the four new tests FAIL (dimensions are empty).

- [ ] **Step 3: Implement the categorical reducer**

In `TasteMirror.swift`, add at end of file:
```swift
extension TasteMirror {
    /// Build one categorical dimension. `key` returns the category for a song, or
    /// nil to exclude it (untagged → never guessed).
    static func dimension(
        id: String, title: String,
        from rated: [RatedSong], overall: Double, totalRated: Int,
        key: (DailyEntry) -> String?
    ) -> DimensionInsight {
        var likes: [String: Int] = [:]
        var dislikes: [String: Int] = [:]
        for r in rated {
            guard let name = key(r.entry), !name.isEmpty else { continue }
            if r.value > 0 { likes[name, default: 0] += 1 } else { dislikes[name, default: 0] += 1 }
        }
        let names = Set(likes.keys).union(dislikes.keys)
        let cats = names
            .map { CategoryStat(name: $0, likes: likes[$0] ?? 0, dislikes: dislikes[$0] ?? 0) }
            .sorted { ($0.likes, $0.total, $1.name) > ($1.likes, $1.total, $0.name) }

        let eligible = cats.filter { $0.total >= Thresholds.minPerCategory }
        let dominant = cats.first { $0.likes > 0 }
        let overIndex = eligible
            .filter { $0.likeRate >= overall + Thresholds.overIndexMargin }
            .max { ($0.likeRate, Double($0.total)) < ($1.likeRate, Double($1.total)) }
        let skip = eligible
            .filter { $0.likeRate < overall }
            .min { ($0.likeRate, -Double($0.total)) < ($1.likeRate, -Double($1.total)) }
        let unlocked = totalRated >= Thresholds.minRatedDimension && eligible.count >= 2

        return DimensionInsight(id: id, title: title, categories: cats,
                                dominant: dominant, overIndex: overIndex, skip: skip,
                                isUnlocked: unlocked)
    }
}
```
Then in `build(from:)` replace the line
```swift
        let mood = empty, decade = empty, theme = empty, genre = empty, language = empty
```
with:
```swift
        let mood = dimension(id: "mood", title: "Mood", from: rated, overall: overall, totalRated: total) { $0.mood }
        let decade = dimension(id: "decade", title: "Decade", from: rated, overall: overall, totalRated: total) { $0.decade }
        let theme = dimension(id: "theme", title: "Theme", from: rated, overall: overall, totalRated: total) { $0.theme }
        let genre = dimension(id: "genre", title: "Genre", from: rated, overall: overall, totalRated: total) { $0.genre }
        let language = dimension(id: "language", title: "Language", from: rated, overall: overall, totalRated: total) { $0.language }
```
(The now-unused `let empty = …` line can be deleted.)

- [ ] **Step 4: Run to verify they pass**

Run the **Test** command. Expected: all pass, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/TasteMirror.swift" "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat: categorical dimension math (dominant/over-index/skip)"
```

---

## Task 6: Energy insight + dimension lock (TDD)

**Files:**
- Modify: `Daily Music/Models/TasteMirror.swift`
- Test: `Daily MusicTests/TasteMirrorTests.swift`

- [ ] **Step 1: Write the failing tests**

Append inside `struct TasteMirrorTests`:
```swift
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
```

- [ ] **Step 2: Run to verify they fail**

Run the **Test** command. Expected: `energyLeanFromLikedSongs` FAILS (`leanLabel` nil). `dimensionLocksBelowMinimumRatings` may already pass.

- [ ] **Step 3: Implement the energy insight**

In the `extension TasteMirror` add:
```swift
    static func energyInsight(from rated: [RatedSong], overall: Double, totalRated: Int) -> EnergyInsight {
        let likedEnergies = rated.filter { $0.value > 0 }.compactMap { $0.entry.energy }
        let mean = likedEnergies.isEmpty ? nil
            : Double(likedEnergies.reduce(0, +)) / Double(likedEnergies.count)
        let lean: String? = mean.map {
            switch $0 {
            case ...2.0: "Intimate"
            case 3.5...: "Explosive"
            default:     "Balanced"
            }
        }
        let banded = dimension(id: "energy", title: "Energy", from: rated,
                               overall: overall, totalRated: totalRated) { entry in
            entry.energy.map { EnergyBand.band(for: $0).rawValue }
        }
        return EnergyInsight(likedMean: mean, leanLabel: lean,
                             bands: banded.categories, isUnlocked: banded.isUnlocked)
    }
```
Then in `build(from:)` replace the line
```swift
        let energy = EnergyInsight(likedMean: nil, leanLabel: nil, bands: [], isUnlocked: false)
```
with:
```swift
        let energy = energyInsight(from: rated, overall: overall, totalRated: total)
```

- [ ] **Step 4: Run to verify they pass**

Run the **Test** command. Expected: both pass, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/TasteMirror.swift" "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat: energy lean + banded like-rate; dimension lock threshold"
```

---

## Task 7: `topStandout` selector (TDD)

**Files:**
- Modify: `Daily Music/Models/TasteMirror.swift`
- Test: `Daily MusicTests/TasteMirrorTests.swift`

- [ ] **Step 1: Write the failing test**

Append inside `struct TasteMirrorTests`:
```swift
    @Test func topStandoutPrefersOverIndexThenDominant() {
        let m = TasteMirror.build(from: Self.workedExample())
        #expect(m.mood.topStandout?.name == "Melancholy")   // over-index present
        #expect(m.decade.topStandout?.name == "1980s")       // dominant fallback
    }
```

- [ ] **Step 2: Run to verify it fails**

Run the **Test** command. Expected: FAIL — no member `topStandout`.

- [ ] **Step 3: Implement**

In `TasteMirror.swift` add:
```swift
extension DimensionInsight {
    /// The headline category: a genuine over-index if present, else the most-liked.
    var topStandout: CategoryStat? { overIndex ?? dominant }
}
```

- [ ] **Step 4: Run to verify it passes**

Run the **Test** command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/TasteMirror.swift" "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat: DimensionInsight.topStandout (over-index then dominant)"
```

---

## Task 8: Enrich mock entries with tags + deterministic ids

**Files:**
- Modify: `Daily Music/Services/EntryService.swift`

- [ ] **Step 1: Add static helpers + seed tables and generate entries**

In `MockEntryService`, add these `static` members (e.g. just under `private let entries: [DailyEntry]`):
```swift
    /// Deterministic id for the Nth mock entry (shared with MockRatingService).
    static func mockEntryID(_ i: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i))!
    }

    /// (title, artist, genre, year, mood, energy 1–5, theme)
    static let seed: [(String, String, String, Int, String, Int, String)] = [
        ("Nightswimming", "R.E.M.", "Alternative", 1992, "Melancholy", 2, "Memory & Nostalgia"),
        ("A Real Hero", "College & Electric Youth", "Synthwave", 2010, "Dreamy", 3, "Hope & Perseverance"),
        ("Pyramid Song", "Radiohead", "Alternative", 2001, "Melancholy", 2, "Loneliness"),
        ("This Must Be the Place", "Talking Heads", "Alternative", 1983, "Tender", 3, "Love & Romance"),
        ("Running Up That Hill", "Kate Bush", "Pop", 1985, "Defiant", 4, "Longing & Desire"),
        ("Atmosphere", "Joy Division", "Alternative", 1980, "Melancholy", 2, "Loneliness"),
        ("Just Like Heaven", "The Cure", "Alternative", 1987, "Euphoric", 4, "Love & Romance"),
        ("Heroes", "David Bowie", "Rock", 1977, "Defiant", 4, "Hope & Perseverance"),
        ("Enjoy the Silence", "Depeche Mode", "Synthwave", 1990, "Melancholy", 3, "Love & Romance"),
        ("Dreams", "Fleetwood Mac", "Rock", 1977, "Serene", 3, "Heartbreak"),
        ("Cherry-coloured Funk", "Cocteau Twins", "Alternative", 1990, "Dreamy", 2, "Longing & Desire"),
        ("Blue Monday", "New Order", "Synthwave", 1983, "Defiant", 5, "Loneliness"),
        ("In the Aeroplane Over the Sea", "Neutral Milk Hotel", "Alternative", 1998, "Tender", 3, "Memory & Nostalgia"),
        ("Such Great Heights", "The Postal Service", "Electronic", 2003, "Euphoric", 4, "Love & Romance"),
        ("Avril 14th", "Aphex Twin", "Electronic", 2001, "Melancholy", 1, "Loneliness"),
        ("Fade Into You", "Mazzy Star", "Alternative", 1993, "Dreamy", 2, "Longing & Desire"),
        ("Age of Consent", "New Order", "Synthwave", 1983, "Melancholy", 4, "Heartbreak"),
        ("Boys of Summer", "Don Henley", "Rock", 1984, "Nostalgic", 3, "Memory & Nostalgia"),
        ("Teardrop", "Massive Attack", "Electronic", 1998, "Melancholy", 2, "Love & Romance"),
        ("Once in a Lifetime", "Talking Heads", "Alternative", 1980, "Defiant", 4, "Coming of Age"),
        ("Space Song", "Beach House", "Alternative", 2015, "Dreamy", 2, "Longing & Desire"),
        ("Vienna", "Billy Joel", "Pop", 1977, "Tender", 2, "Coming of Age"),
        ("The Killing Moon", "Echo & the Bunnymen", "Alternative", 1984, "Melancholy", 3, "Loneliness"),
        ("Holocene", "Bon Iver", "Alternative", 2011, "Serene", 2, "Memory & Nostalgia"),
    ]

    /// Ratings aligned by index to `seed` (+1 👍 / -1 👎). Skews toward liking
    /// melancholy & 1980s songs so the mock mirror reads "Melancholy / 1980s".
    static let seedRatingValues: [Int] = [
        1, -1, 1, 1, 1, 1, -1, 1, 1, -1,
        1, -1, 1, -1, 1, 1, 1, -1, 1, -1,
        1, 1, 1, 1
    ]
```
Then replace the `entries = [ … ]` assignment in `init()` (and the now-unused `today`/`day` locals if you prefer) with:
```swift
    init() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }

        entries = Self.seed.enumerated().map { index, s in
            DailyEntry(
                id: Self.mockEntryID(index),
                date: day(-index),
                title: s.0, artist: s.1,
                albumArtURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/97/1a/9b/971a9bf7-b6dc-8712-ac3a-1d4351512c8b/17CRGIM03466.rgb.jpg/1200x1200bb.jpg"),
                journalMarkdown: "A note about *\(s.0)* by \(s.1).",
                appleMusicID: "1440947554",
                spotifyURI: "spotify:track:4gphxUgq0JSFv2BCLhNDiE",
                genre: s.2, year: s.3, mood: s.4, energy: s.5, theme: s.6,
                language: "English"
            )
        }
    }
```

- [ ] **Step 2: Verify build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **` (old Insights still compiles — untouched).

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Services/EntryService.swift"
git commit -m "feat: enrich mock entries with tags + deterministic ids"
```

---

## Task 9: `RatingService` protocol + mock

**Files:**
- Create: `Daily Music/Services/RatingService.swift`

- [ ] **Step 1: Create the protocol + seeded mock**

Create `Daily Music/Services/RatingService.swift`:
```swift
//
//  RatingService.swift
//  Daily Music
//
//  The 👍/👎 taste-judgment seam — the primary signal behind Insights. Three
//  states: like (+1), dislike (-1), none (no row). Mirrors ReactionsService. The
//  mock seeds ratings (aligned to MockEntryService) so Insights is explorable
//  without a backend.
//

import Foundation

protocol RatingService {
    /// The current user's rating for this entry: +1, -1, or nil (none).
    func myRating(entryID: UUID) async throws -> Int?
    /// Set (+1/-1) or clear (nil) the current user's rating.
    func setRating(_ value: Int?, entryID: UUID) async throws
    /// All of the current user's ratings, keyed by entry id.
    func myRatings() async throws -> [UUID: Int]
}

actor MockRatingService: RatingService {
    private var mine: [UUID: Int]

    init() {
        var seed: [UUID: Int] = [:]
        for (index, value) in MockEntryService.seedRatingValues.enumerated() {
            seed[MockEntryService.mockEntryID(index)] = value
        }
        mine = seed
    }

    func myRating(entryID: UUID) async throws -> Int? { mine[entryID] }
    func setRating(_ value: Int?, entryID: UUID) async throws { mine[entryID] = value }
    func myRatings() async throws -> [UUID: Int] { mine }
}
```

- [ ] **Step 2: Verify build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **` (`MockRatingService` is defined but not yet wired — compiles unused).

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Services/RatingService.swift"
git commit -m "feat: RatingService protocol + seeded mock"
```

---

## Task 10: Live `SupabaseRatingService` + decode columns + AppEnvironment

**Files:**
- Create: `Daily Music/Services/Supabase/SupabaseRatingService.swift`
- Modify: `Daily Music/Services/Supabase/SupabaseEntryService.swift`
- Modify: `Daily Music/App/AppEnvironment.swift`

- [ ] **Step 1: Decode the new columns in the live row**

In `SupabaseEntryService.swift`, add to `private struct DailyEntryRow` after `let genre: String?`:
```swift
    let year: Int?
    let mood: String?
    let energy: Int?
    let theme: String?
    let language: String?
```
and in `toEntry()` replace `genre: genre` with:
```swift
            genre: genre,
            year: year,
            mood: mood,
            energy: energy,
            theme: theme,
            language: language
```

- [ ] **Step 2: Create the live rating service**

Create `Daily Music/Services/Supabase/SupabaseRatingService.swift`:
```swift
//
//  SupabaseRatingService.swift
//  Daily Music
//
//  Live 👍/👎 ratings against `song_ratings`. Owner-scoped via RLS. value: +1
//  like, -1 dislike; clearing deletes the row.
//

import Foundation
import Supabase

final class SupabaseRatingService: RatingService {
    private let client = Supa.client

    func myRating(entryID: UUID) async throws -> Int? {
        let userID = try await client.auth.session.user.id
        let rows: [RatingRow] = try await client
            .from("song_ratings").select("value")
            .eq("user_id", value: userID).eq("entry_id", value: entryID)
            .limit(1).execute().value
        return rows.first.map { Int($0.value) }
    }

    func setRating(_ value: Int?, entryID: UUID) async throws {
        let userID = try await client.auth.session.user.id
        if let value {
            try await client.from("song_ratings")
                .upsert(RatingInsert(user_id: userID, entry_id: entryID, value: Int16(value)),
                        onConflict: "user_id,entry_id")
                .execute()
        } else {
            try await client.from("song_ratings").delete()
                .eq("user_id", value: userID).eq("entry_id", value: entryID)
                .execute()
        }
    }

    func myRatings() async throws -> [UUID: Int] {
        let userID = try await client.auth.session.user.id
        let rows: [RatingRow] = try await client
            .from("song_ratings").select("entry_id,value")
            .eq("user_id", value: userID).execute().value
        return Dictionary(rows.compactMap { r in r.entry_id.map { ($0, Int(r.value)) } },
                          uniquingKeysWith: { a, _ in a })
    }
}

private struct RatingRow: Decodable { let entry_id: UUID?; let value: Int16 }
private struct RatingInsert: Encodable { let user_id: UUID; let entry_id: UUID; let value: Int16 }
```

- [ ] **Step 3: Register in AppEnvironment**

In `AppEnvironment.swift`:
- After `let reactions: ReactionsService` add: `    let ratings: RatingService`
- After the init param `reactions: ReactionsService,` add: `        ratings: RatingService,`
- After `self.reactions = reactions` add: `        self.ratings = ratings`
- In `mock()` after `reactions: MockReactionsService(),` add: `            ratings: MockRatingService(),`
- In `live()` after `reactions: SupabaseReactionsService(),` add: `            ratings: SupabaseRatingService(),`

- [ ] **Step 4: Verify build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/Supabase/SupabaseRatingService.swift" \
        "Daily Music/Services/Supabase/SupabaseEntryService.swift" \
        "Daily Music/App/AppEnvironment.swift"
git commit -m "feat: live SupabaseRatingService, decode tag columns, wire AppEnvironment"
```

---

## Task 11: `RatingBar` component + insert into `EntryDetailView`

**Files:**
- Create: `Daily Music/Views/RatingBar.swift`
- Modify: `Daily Music/Views/EntryDetailView.swift`

- [ ] **Step 1: Create the RatingBar**

Create `Daily Music/Views/RatingBar.swift`:
```swift
//
//  RatingBar.swift
//  Daily Music
//
//  The everyday taste judgment: 👍 / 👎 on a song. Three states (like/dislike/
//  none); tapping the active one clears it. Optimistic, mirrors ReactionsBar.
//  This is the primary signal behind the Insights taste mirror.
//

import SwiftUI

@MainActor
@Observable
final class RatingModel {
    private(set) var mine: Int?
    private(set) var isSaving = false
    private let service: RatingService

    init(service: RatingService) { self.service = service }

    func load(entryID: UUID, includesMine: Bool = true) async {
        mine = includesMine ? ((try? await service.myRating(entryID: entryID)) ?? nil) : nil
    }

    func tap(_ value: Int, entryID: UUID, allowsPersistence: Bool = true) async {
        guard allowsPersistence, !isSaving else { return }
        let next = (mine == value) ? nil : value
        mine = next
        isSaving = true
        do { try await service.setRating(next, entryID: entryID) }
        catch { await load(entryID: entryID) }
        isSaving = false
    }
}

struct RatingBar: View {
    let entry: DailyEntry
    var accent: Color = Theme.Brand.gradient[0]

    @Environment(AppEnvironment.self) private var env
    @State private var model: RatingModel?

    var body: some View {
        HStack(spacing: 10) {
            button(value: 1, symbol: "hand.thumbsup", filled: "hand.thumbsup.fill", label: "Like")
            button(value: -1, symbol: "hand.thumbsdown", filled: "hand.thumbsdown.fill", label: "Dislike")
        }
        .padding(.horizontal)
        .task(id: loadID) {
            if model == nil { model = RatingModel(service: env.ratings) }
            await model?.load(entryID: entry.id, includesMine: !isGuestSession)
        }
    }

    private func button(value: Int, symbol: String, filled: String, label: String) -> some View {
        let selected = model?.mine == value
        return Button {
            Task { await model?.tap(value, entryID: entry.id, allowsPersistence: !isGuestSession) }
        } label: {
            Image(systemName: selected ? filled : symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(selected ? .white : accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selected ? AnyShapeStyle(accent) : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(model?.isSaving == true || isGuestSession)
        .animation(.spring(duration: 0.3), value: selected)
        .accessibilityLabel(label)
    }

    private var isGuestSession: Bool { env.session.session?.isGuest == true }
    private var loadID: String {
        "\(entry.id.uuidString)-\(env.session.session?.userID.uuidString ?? "signed-out")"
    }
}
```

- [ ] **Step 2: Insert into the shared detail view**

In `EntryDetailView.swift` `body`, immediately after `FavoriteButton(entry: entry, accent: palette.accent)` and before `ReactionsBar(...)`, add:
```swift
                    RatingBar(entry: entry, accent: palette.accent)
```

- [ ] **Step 3: Verify build + simulator**

Run the **Build** command (expected `** BUILD SUCCEEDED **`). Then launch and confirm 👍/👎 appears under the heart and toggles:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build build 2>&1 | tail -5
xcrun simctl install booted "$(find build -name 'Daily Music.app' -type d | head -1)"
xcrun simctl launch booted maxhagi.Daily-Music
xcrun simctl io booted screenshot /tmp/today.png
```
View `/tmp/today.png`. Expected: 👍/👎 row visible; tapping fills one, re-tapping clears.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/RatingBar.swift" "Daily Music/Views/EntryDetailView.swift"
git commit -m "feat: 👍/👎 RatingBar in EntryDetailView"
```

---

## Task 12: Swap Insights to the taste mirror (TasteProfile + ViewModel + View)

This is one compile-coherent unit — rewriting the view-model's output type breaks the old view, so they change together with a single commit and gate.

**Files:**
- Modify: `Daily Music/Models/TasteProfile.swift`
- Modify: `Daily Music/Models/TasteMirror.swift` (wire archetype)
- Modify: `Daily Music/ViewModels/InsightsViewModel.swift`
- Modify: `Daily Music/Views/InsightsView.swift`
- Test: `Daily MusicTests/TasteMirrorTests.swift`

- [ ] **Step 1: Rewrite `TasteProfile` as an identifier catalogue**

Replace the entire contents of `Daily Music/Models/TasteProfile.swift` with:
```swift
//
//  TasteProfile.swift
//  Daily Music
//
//  The synthesized archetype. NOT scored — a lookup on the user's top standouts
//  (mood, with an optional decade/theme modifier), resolved in priority order
//  with a mood-only fallback. Titles are IDENTIFIERS for now (rename freely).
//

import SwiftUI

struct TasteProfile: Equatable {
    let id: String          // stable identifier; survives renaming `title`
    let title: String       // shown in the hero — currently == id
    let symbol: String
    let colors: [Color]

    private init(_ id: String, _ symbol: String, _ colors: [Color]) {
        self.id = id; self.title = id; self.symbol = symbol; self.colors = colors
    }

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    static let melancholy1980s   = TasteProfile("MELANCHOLY_1980S", "moon.stars.fill", [c(0.42,0.31,0.93), c(0.18,0.13,0.45)])
    static let melancholyDefault = TasteProfile("MELANCHOLY_DEFAULT", "cloud.moon.fill", [c(0.34,0.40,0.62), c(0.16,0.20,0.38)])
    static let defiantProtest    = TasteProfile("DEFIANT_PROTEST", "megaphone.fill", [c(0.86,0.20,0.18), c(0.50,0.10,0.10)])
    static let defiantDefault    = TasteProfile("DEFIANT_DEFAULT", "flame.fill", [c(0.90,0.32,0.16), c(0.55,0.12,0.10)])
    static let euphoric2010s     = TasteProfile("EUPHORIC_2010S", "sparkles", [c(0.96,0.28,0.62), c(0.55,0.20,0.90)])
    static let euphoricDefault   = TasteProfile("EUPHORIC_DEFAULT", "sun.max.fill", [c(1.0,0.55,0.16), c(0.92,0.27,0.35)])
    static let sereneDefault     = TasteProfile("SERENE_DEFAULT", "leaf.fill", [c(0.18,0.72,0.58), c(0.05,0.45,0.50)])
    static let dreamyDefault     = TasteProfile("DREAMY_DEFAULT", "moon.haze.fill", [c(0.55,0.50,0.90), c(0.30,0.26,0.62)])
    static let nostalgicDefault  = TasteProfile("NOSTALGIC_DEFAULT", "clock.arrow.circlepath", [c(0.92,0.62,0.20), c(0.66,0.36,0.14)])
    static let tenderDefault     = TasteProfile("TENDER_DEFAULT", "heart.fill", [c(0.96,0.34,0.50), c(0.79,0.16,0.50)])
    static let joyfulDefault     = TasteProfile("JOYFUL_DEFAULT", "face.smiling.fill", [c(1.0,0.74,0.16), c(0.96,0.45,0.18)])
    static let darkDefault       = TasteProfile("DARK_DEFAULT", "circle.lefthalf.filled", [c(0.30,0.28,0.40), c(0.12,0.11,0.18)])
    static let balancedDefault   = TasteProfile("BALANCED_DEFAULT", "circle.grid.2x2.fill", [c(0.21,0.49,0.93), c(0.11,0.31,0.70)])

    /// Resolve from the user's top standouts. `decade` like "1980s".
    static func resolve(mood: String?, decade: String?, theme: String?) -> TasteProfile {
        if mood == "Melancholy", decade == "1980s" { return melancholy1980s }
        if mood == "Euphoric", let y = decadeYear(decade), y >= 2010 { return euphoric2010s }
        if mood == "Defiant", theme == "Rebellion & Protest" { return defiantProtest }

        switch mood {
        case "Melancholy": return melancholyDefault
        case "Defiant":    return defiantDefault
        case "Euphoric":   return euphoricDefault
        case "Serene":     return sereneDefault
        case "Dreamy":     return dreamyDefault
        case "Nostalgic":  return nostalgicDefault
        case "Tender":     return tenderDefault
        case "Joyful":     return joyfulDefault
        case "Dark":       return darkDefault
        default:           return balancedDefault
        }
    }

    private static func decadeYear(_ decade: String?) -> Int? {
        guard let decade, decade.count >= 4 else { return nil }
        return Int(decade.prefix(4))
    }
}
```

- [ ] **Step 2: Wire the archetype into the engine**

In `Daily Music/Models/TasteMirror.swift` `build(from:)`, replace the two placeholder lines
```swift
        let archetype: TasteProfile? = nil
        let isArchetypeUnlocked = false
```
with:
```swift
        let isArchetypeUnlocked = total >= Thresholds.minRatedArchetype
        let archetype: TasteProfile? = isArchetypeUnlocked
            ? TasteProfile.resolve(mood: mood.topStandout?.name,
                                   decade: decade.topStandout?.name,
                                   theme: theme.topStandout?.name)
            : nil
```

- [ ] **Step 3: Add archetype tests**

Append inside `struct TasteMirrorTests`:
```swift
    @Test func archetypeLockedUntilTwentyRatings() {
        let m = TasteMirror.build(from: Self.workedExample())   // 30 ratings, melancholy+1980s
        #expect(m.isArchetypeUnlocked == true)
        #expect(m.archetype?.id == "MELANCHOLY_1980S")
    }

    @Test func archetypeNilBelowThreshold() {
        let m = TasteMirror.build(from: Self.mood("Melancholy", likes: 8, dislikes: 2, year: 1985))
        #expect(m.isArchetypeUnlocked == false)
        #expect(m.archetype == nil)
    }

    @Test func archetypeFallsBackToMoodOnly() {
        // 24 melancholy songs, no year → no decade standout → mood-only default.
        let m = TasteMirror.build(from: Self.mood("Melancholy", likes: 18, dislikes: 6))
        #expect(m.archetype?.id == "MELANCHOLY_DEFAULT")
    }
```

- [ ] **Step 4: Rewrite `InsightsViewModel`**

Replace the entire contents of `Daily Music/ViewModels/InsightsViewModel.swift` with:
```swift
//
//  InsightsViewModel.swift
//  Daily Music
//
//  Feeds the pure TasteMirror engine: joins the user's 👍/👎 ratings with the
//  tagged published catalog, then exposes the resulting mirror as a LoadState.
//  Degrades gracefully — missing sources yield an empty mirror, not an error.
//

import Foundation

@MainActor
@Observable
final class InsightsViewModel {
    private(set) var state: LoadState<TasteMirror> = .loading

    private let entries: EntryService
    private let ratings: RatingService

    init(entries: EntryService, ratings: RatingService) {
        self.entries = entries
        self.ratings = ratings
    }

    func load() async {
        state = .loading
        let history = (try? await entries.publishedHistory()) ?? []
        let myRatings = (try? await ratings.myRatings()) ?? [:]
        let rated = history.compactMap { entry in
            myRatings[entry.id].map { RatedSong(entry: entry, value: $0) }
        }
        state = .loaded(TasteMirror.build(from: rated))
    }
}
```

- [ ] **Step 5: Rewrite `InsightsView`**

Replace the entire contents of `Daily Music/Views/InsightsView.swift` with:
```swift
//
//  InsightsView.swift
//  Daily Music
//
//  The taste mirror: synthesized archetype hero, a "what stands out" strip, and a
//  per-dimension like-rate breakdown — all from real 👍/👎 data via TasteMirror.
//  Progressive reveal: each piece stays "forming" until it has enough ratings.
//  Insights uses the archetype's color, not album art.
//

import SwiftUI

struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: InsightsViewModel?
    @State private var showingWrapped = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(
                        state: model.state,
                        emptyTitle: "No ratings yet",
                        emptyMessage: "Rate songs 👍 / 👎 to start your taste mirror.",
                        onRetry: { await model.load() }
                    ) { mirror in
                        content(mirror)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(pageBackground)
                }
            }
            .navigationTitle("Insights")
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(pageBackground)
            .fullScreenCover(isPresented: $showingWrapped) {
                WrappedView(favoriteIDs: env.favoritesStore.ids)
            }
        }
        .task(id: env.favoritesStore.ids) {
            if model == nil {
                model = InsightsViewModel(entries: env.entries, ratings: env.ratings)
            }
            await model?.load()
        }
    }

    private var pageBackground: some View {
        LinearGradient(colors: Theme.Surface.insightsBackground,
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private func content(_ mirror: TasteMirror) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                hero(mirror)
                standoutStrip(mirror)
                breakdown(mirror)
                wrappedButton(mirror)
            }
            .padding()
        }
        .background(pageBackground)
    }

    // MARK: hero

    @ViewBuilder
    private func hero(_ mirror: TasteMirror) -> some View {
        if let archetype = mirror.archetype {
            heroCard(profile: archetype, headline: archetype.title,
                     subtitle: heroWhy(mirror), badge: "YOUR ARCHETYPE")
        } else {
            let remaining = max(TasteMirror.Thresholds.minRatedArchetype - mirror.totalRated, 0)
            heroCard(profile: .balancedDefault, headline: "\(remaining) to go",
                     subtitle: "Your portrait takes shape at \(TasteMirror.Thresholds.minRatedArchetype) ratings.",
                     badge: "FORMING")
        }
    }

    private func heroCard(profile: TasteProfile, headline: String, subtitle: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .top) {
                Image(systemName: profile.symbol)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Spacer()
                Text(badge).font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.72))
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(headline)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: profile.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: profile.colors[0].opacity(0.28), radius: 18, y: 10)
    }

    /// Templated "why it's you" from the real standouts — never generated text.
    private func heroWhy(_ mirror: TasteMirror) -> String {
        let mood = mirror.mood.topStandout
        let pct = Int((mood?.likeRate ?? 0) * 100)
        let overall = Int(mirror.overallLikeRate * 100)
        let moodName = mood?.name.lowercased() ?? "the songs you keep"
        let era = mirror.decade.topStandout.map { " \($0.name)" } ?? ""
        return "Because you keep \(moodName)\(era) songs more than anything else (\(pct)% yes vs \(overall)% overall)."
    }

    // MARK: standout strip

    private func standoutStrip(_ mirror: TasteMirror) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            tile(mirror.mood, lead: "Top mood")
            tile(mirror.decade, lead: "The era you live in")
            tile(mirror.theme, lead: "Your recurring theme")
            energyTile(mirror.energy)
        }
    }

    @ViewBuilder
    private func tile(_ dim: DimensionInsight, lead: String) -> some View {
        if dim.isUnlocked, let s = dim.topStandout {
            standoutCard(lead: lead, headline: s.name,
                         detail: "You keep \(s.likes) of \(s.total) (\(Int(s.likeRate * 100))%).")
        } else {
            lockedCard(lead: lead)
        }
    }

    @ViewBuilder
    private func energyTile(_ energy: EnergyInsight) -> some View {
        if energy.isUnlocked, let lean = energy.leanLabel, let mean = energy.likedMean {
            standoutCard(lead: "Your energy lean", headline: lean,
                         detail: "Your liked songs average \(String(format: "%.1f", mean))/5.")
        } else {
            lockedCard(lead: "Your energy lean")
        }
    }

    private func standoutCard(lead: String, headline: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lead.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Text(headline).font(.system(size: 22, weight: .heavy, design: .rounded))
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.Surface.cardStroke, lineWidth: 1) }
    }

    private func lockedCard(lead: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(lead).font(.subheadline.weight(.semibold))
                Text("Keep rating to reveal this.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.Surface.cardStroke, lineWidth: 1) }
    }

    // MARK: breakdown

    @ViewBuilder
    private func breakdown(_ mirror: TasteMirror) -> some View {
        let dims = [mirror.mood, mirror.theme, mirror.genre, mirror.decade, mirror.language]
            .filter { $0.isUnlocked && !$0.categories.isEmpty }
        if !dims.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("The breakdown").font(.dmTitle())
                ForEach(dims) { dim in dimensionSection(dim) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.Surface.cardStroke, lineWidth: 1) }
        }
    }

    private func dimensionSection(_ dim: DimensionInsight) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(dim.title).font(.subheadline.weight(.bold))
            ForEach(dim.categories.prefix(6)) { cat in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(cat.name).font(.footnote.weight(.semibold))
                        if dim.overIndex?.id == cat.id {
                            Text("↑ stands out").font(.caption2.weight(.bold)).foregroundStyle(.green)
                        } else if dim.skip?.id == cat.id {
                            Text("you skip").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(cat.likes)/\(cat.total) · \(Int(cat.likeRate * 100))%")
                            .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.Surface.subtleTrack)
                            Capsule().fill((dim.overIndex?.id == cat.id ? Color.green : Color.accentColor).gradient)
                                .frame(width: max(8, proxy.size.width * cat.likeRate))
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }

    // MARK: wrapped

    private func wrappedButton(_ mirror: TasteMirror) -> some View {
        Button { showingWrapped = true } label: {
            Label("See your month", systemImage: "sparkles").frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: (mirror.archetype ?? .balancedDefault).colors[0]))
        .padding(.top, Theme.Spacing.xs)
    }
}
```

- [ ] **Step 6: Verify build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Run the full engine suite**

Run the **Test** command. Expected: all tests pass (including the three archetype tests), `** TEST SUCCEEDED **`.

- [ ] **Step 8: Verify in the simulator (mock data path)**

Rebuild + relaunch (as in Task 11 Step 3), open the **Insights** tab, screenshot `/tmp/insights.png`.
Expected: hero shows `MELANCHOLY_1980S` with "Because you keep melancholy 1980s songs…"; standout strip Top mood = Melancholy; breakdown lists mood/theme/genre/decade with a green "↑ stands out" on Melancholy.

- [ ] **Step 9: Commit (single)**

```bash
git add "Daily Music/Models/TasteProfile.swift" "Daily Music/Models/TasteMirror.swift" \
        "Daily Music/ViewModels/InsightsViewModel.swift" "Daily Music/Views/InsightsView.swift" \
        "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat: swap Insights to taste mirror (archetype + viewmodel + view)"
```

---

## Task 13: Final gate

**Files:** none.

- [ ] **Step 1: Full test suite** — run the **Test** command. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 2: Full build** — run the **Build** command. Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 3:** `git status` — expect a clean tree.

---

## Task 14: Supabase migration (user runs in dashboard)

**Files:**
- Create: `docs/superpowers/specs/insights-taste-mirror.sql`

- [ ] **Step 1: Write the migration**

Create `docs/superpowers/specs/insights-taste-mirror.sql`:
```sql
-- Daily Music — Insights taste mirror migration. Run in the Supabase SQL editor.

-- 1) Song tag columns (safe to re-run).
alter table daily_entries add column if not exists year     int;
alter table daily_entries add column if not exists mood     text;
alter table daily_entries add column if not exists energy   int;   -- 1..5
alter table daily_entries add column if not exists theme    text;
alter table daily_entries add column if not exists language text;

-- 2) Per-user 👍/👎 ratings.
create table if not exists song_ratings (
  user_id    uuid not null references auth.users(id) on delete cascade,
  entry_id   uuid not null references daily_entries(id) on delete cascade,
  value      smallint not null check (value in (-1, 1)),  -- 1 = 👍, -1 = 👎
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, entry_id)
);

alter table song_ratings enable row level security;

create policy "song_ratings owner read"
  on song_ratings for select using (auth.uid() = user_id);

create policy "song_ratings owner write"
  on song_ratings for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

- [ ] **Step 2: Commit**

```bash
git add "docs/superpowers/specs/insights-taste-mirror.sql"
git commit -m "docs: Supabase migration for tags + song_ratings"
```

- [ ] **Step 3: Hand off to the user** — they (1) run the SQL; (2) tag a few `daily_entries` rows with mood/year/energy/theme/genre/language; (3) sign in and toggle 👍/👎 to confirm it round-trips. Live Insights stays "forming" until ~10–20 ratings exist.

---

## Self-Review (against the spec)

**Spec coverage:**
- §1 philosophy/guardrails → untagged excluded (Task 5 `key`→nil skip); every UI claim shows counts (Task 12 View). ✓
- §2 signals: 👍/👎 drives mirror (Tasks 9–12); ❤️ + reactions untouched. ✓
- §3 tags + Mood(9)/Theme(10) → Tasks 2, 3. ✓
- §4 `song_ratings` + unchanged favourites/reactions → Tasks 10, 14. ✓
- §5 math (overall, dominant, over-index, skip, energy lean, thresholds) → Tasks 4–7, tested. ✓
- §6 archetype synthesis (precedence, identifiers) → Task 12. ✓
- §7 layout (hero/strip/breakdown/wrapped, progressive reveal) → Task 12. ✓
- §8 Today 👍/👎 control → Task 11. ✓
- §9 components/files → all present. ✓
- §10 testing (pure engine) → Tasks 1, 4–7, 12. ✓
- §11 deferred → not built (correct). ✓
- §12 open items → identifiers + named `Thresholds` left tunable. ✓

**Type consistency:** `RatedSong(entry:value:)`, `CategoryStat`, `DimensionInsight`, `EnergyInsight`, `TasteMirror.build(from:)`, `Thresholds.*`, `DimensionInsight.topStandout`, `TasteProfile.resolve(mood:decade:theme:)` + catalogue statics (`.balancedDefault` etc.), `RatingService.{myRating,setRating,myRatings}`, `MockEntryService.{mockEntryID,seed,seedRatingValues}` — names match across tasks. ✓

**Resolved spec ambiguity:** §3 said "language blank → English"; the plan treats blank/nil language as untagged (excluded), consistent with guardrail #2 (never guess). Mock data tags `language: "English"` explicitly so the dimension still populates.

**Ordering integrity:** the app target compiles after every task (Tasks 2–11 never touch `TasteProfile`/`InsightsView`; Task 12 swaps the three coupled files together). Engine tests are runnable at every TDD gate.
