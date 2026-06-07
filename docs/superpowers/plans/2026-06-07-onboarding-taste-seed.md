# Onboarding Taste-Seed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playful "this or that" calibration after the name step in onboarding that ends with an instant first taste-read, computed through the existing `TasteMirror`, persisted as a "you started here" note in Insights.

**Architecture:** A bundled, in-app `StarterPack` of 14 recognizable, fully-tagged songs (reusing the `DailyEntry` model — NOT a Supabase table, so it never touches or pre-rates the daily catalog). `TasteSeedView` runs a self-contained flow (intro → 7 rounds → reveal) presented as a full-screen cover right after the "Say hello" step; tap-to-preview reuses the shared `MusicPlayer`/`PreviewMusicEngine`. The 7 picks (👍) + 7 passes (👎) build a `TasteMirror`; its dominant standouts become a `StartingRead` shown in friendly prose and saved to `@AppStorage` for an Insights memento. The read is onboarding-only — it is NOT written to `song_ratings` (those starter songs aren't in the catalog).

**Tech Stack:** SwiftUI, `@Observable` MVVM-lite, the existing `TasteMirror`/`TasteProfile`/`MusicPlayer`, Swift Testing (`Daily MusicTests`), `scripts/add_test_files.rb`.

---

## Build & test commands

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```
- **Build:** `xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`
- **Test:** `xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests" 2>&1 | tail -30`
- **Register a new test file:** `/opt/homebrew/opt/ruby/bin/ruby scripts/add_test_files.rb "Daily MusicTests/<file>.swift"`

New `.swift` files under `Daily Music/` auto-join the app target (synchronized folder). New files under `Daily MusicTests/` must be registered with the ruby script.

## File structure

**Create:**
- `Daily Music/Models/StarterPack.swift` — the 14 tagged starter songs + the 7 contrast pairs.
- `Daily Music/Models/StartingRead.swift` — pure: picks → `TasteMirror` → dominant mood/genre/decade.
- `Daily Music/Views/Onboarding/TasteSeedView.swift` — the cover flow (intro → rounds → reveal) with tap-to-preview.
- `Daily MusicTests/TasteSeedTests.swift` — tests for `StarterPack.rounds()` coverage + `StartingRead`.

**Modify:**
- `Daily Music/Views/Onboarding/OnboardingView.swift` — present `TasteSeedView` after Hello; persist the read.
- `Daily Music/Views/InsightsView.swift` — show the "you started here" memento when present.

---

### Task 1: Create the bundled `StarterPack`

**Files:**
- Create: `Daily Music/Models/StarterPack.swift`

- [ ] **Step 1: Create the file** with EXACTLY this content. (The 14 songs use real iTunes IDs + 600px art + valid Mood/SongTheme tags. The `pairIndices` array pairs each of the 14 indices 0–13 exactly once — Task 3's test enforces this.)

```swift
//
//  StarterPack.swift
//  Daily Music
//
//  A bundled, onboarding-only set of recognizable songs (reusing DailyEntry).
//  Used by the taste-seed "this or that" rounds. NOT in the Supabase catalog and
//  never written to song_ratings — purely to compute an onboarding first-read.
//  Swap freely; tags use the same Mood/SongTheme vocabularies as the catalog.
//

import Foundation

enum StarterPack {
    /// One starter song. `date` is irrelevant here (.distantPast); the read uses tags.
    private static func song(
        _ title: String, _ artist: String, _ appleMusicID: String, _ art: String,
        genre: String, year: Int, mood: String, energy: Int, theme: String
    ) -> DailyEntry {
        DailyEntry(
            id: UUID(), date: .distantPast, title: title, artist: artist,
            albumArtURL: URL(string: art), journalMarkdown: "",
            appleMusicID: appleMusicID, spotifyURI: "",
            genre: genre, year: year, mood: mood, energy: energy,
            theme: theme, language: "English"
        )
    }

    // Indices: 0 Dancing Queen · 1 Teen Spirit · 2 Hurt · 3 Levitating · 4 Space Song
    // 5 bad guy · 6 Vienna · 7 Feels Like Summer · 8 Seven Nation Army · 9 Night We Met
    // 10 Good as Hell · 11 Landslide · 12 HUMBLE. · 13 Skinny Love
    static let songs: [DailyEntry] = [
        song("Dancing Queen", "ABBA", "1422648513",
             "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/60/f8/a6/60f8a6bc-e875-238d-f2f8-f34a6034e6d2/14UMGIM07615.rgb.jpg/600x600bb.jpg",
             genre: "Pop", year: 1976, mood: "Euphoric", energy: 4, theme: "Freedom & Escape"),
        song("Smells Like Teen Spirit", "Nirvana", "1440783625",
             "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/95/fd/b9/95fdb9b2-6d2b-92a6-97f2-51c1a6d77f1a/00602527874609.rgb.jpg/600x600bb.jpg",
             genre: "Rock", year: 1991, mood: "Defiant", energy: 5, theme: "Rebellion & Protest"),
        song("Hurt", "Johnny Cash", "1452875626",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/9f/b0/3c/9fb03c5a-28f5-9609-a5fa-8471b6b32fc1/00602498613351.rgb.jpg/600x600bb.jpg",
             genre: "Country", year: 2002, mood: "Melancholy", energy: 2, theme: "Memory & Nostalgia"),
        song("Levitating", "Dua Lipa", "1538003843",
             "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6c/11/d6/6c11d681-aa3a-d59e-4c2e-f77e181026ab/190295092665.jpg/600x600bb.jpg",
             genre: "Pop", year: 2020, mood: "Euphoric", energy: 4, theme: "Love & Romance"),
        song("Space Song", "Beach House", "997914096",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/09/e0/d5/09e0d559-0682-f0f0-5e0c-3cd11e3114fd/beachhouse_depressioncherry_2400_300.jpg/600x600bb.jpg",
             genre: "Alternative", year: 2015, mood: "Dreamy", energy: 2, theme: "Longing & Desire"),
        song("bad guy", "Billie Eilish", "1450695739",
             "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/1a/37/d1/1a37d1b1-8508-54f2-f541-bf4e437dda76/19UMGIM05028.rgb.jpg/600x600bb.jpg",
             genre: "Alternative", year: 2019, mood: "Dark", energy: 3, theme: "Empowerment & Self-Worth"),
        song("Vienna", "Billy Joel", "158618071",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/37/68/4c/37684c52-dbdf-9bfe-0d87-07492f43dc4c/dj.gmcbwich.jpg/600x600bb.jpg",
             genre: "Rock", year: 1977, mood: "Nostalgic", energy: 2, theme: "Coming of Age"),
        song("Feels Like Summer", "Childish Gambino", "1410354351",
             "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/e5/bc/65/e5bc6574-1f2a-24a7-6fe0-d17fd32b9869/886447214268.jpg/600x600bb.jpg",
             genre: "R&B/Soul", year: 2018, mood: "Dreamy", energy: 2, theme: "Hope & Perseverance"),
        song("Seven Nation Army", "The White Stripes", "1533513537",
             "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/07/25/09/0725098a-09f4-f240-e551-94384a590371/886448799009.jpg/600x600bb.jpg",
             genre: "Rock", year: 2003, mood: "Defiant", energy: 5, theme: "Rebellion & Protest"),
        song("The Night We Met", "Lord Huron", "1806531961",
             "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/55/41/4a/55414a18-861a-79d1-e575-5bf8cf205dbe/886445056839_Cover.jpg/600x600bb.jpg",
             genre: "Alternative", year: 2015, mood: "Melancholy", energy: 2, theme: "Heartbreak"),
        song("Good as Hell", "Lizzo", "1150159755",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/7f/d4/43/7fd443a8-861d-dd70-27a1-f23e221883dc/075679905956.jpg/600x600bb.jpg",
             genre: "Pop", year: 2016, mood: "Joyful", energy: 5, theme: "Empowerment & Self-Worth"),
        song("Landslide", "Fleetwood Mac", "1308648844",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/64/cc/0b/64cc0b3b-92fb-66cf-1240-e2afba504e4b/603497863105.jpg/600x600bb.jpg",
             genre: "Rock", year: 1975, mood: "Tender", energy: 2, theme: "Memory & Nostalgia"),
        song("HUMBLE.", "Kendrick Lamar", "1440882165",
             "https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/ab/16/ef/ab16efe9-e7f1-66ec-021c-5592a23f0f9e/17UMGIM88793.rgb.jpg/600x600bb.jpg",
             genre: "Hip-Hop/Rap", year: 2017, mood: "Defiant", energy: 4, theme: "Empowerment & Self-Worth"),
        song("Skinny Love", "Bon Iver", "947059829",
             "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/21/2f/ea/212fea18-5fdc-ba4d-5dd7-1b07aaa88b67/656605211565.tif/600x600bb.jpg",
             genre: "Alternative", year: 2007, mood: "Tender", energy: 1, theme: "Heartbreak"),
    ]

    /// 7 contrast pairs — each song (indices 0–13) appears exactly once.
    private static let pairIndices: [(Int, Int)] = [
        (0, 2),    // Dancing Queen (Euphoric) vs Hurt (Melancholy)
        (1, 13),   // Smells Like Teen Spirit (Defiant) vs Skinny Love (Tender)
        (10, 9),   // Good as Hell (Joyful) vs The Night We Met (Melancholy)
        (8, 4),    // Seven Nation Army (Defiant) vs Space Song (Dreamy)
        (3, 11),   // Levitating (Euphoric) vs Landslide (Tender)
        (12, 6),   // HUMBLE. (Defiant) vs Vienna (Nostalgic)
        (5, 7),    // bad guy (Dark) vs Feels Like Summer (Dreamy)
    ]

    /// The rounds as concrete song pairs.
    static func rounds() -> [(DailyEntry, DailyEntry)] {
        pairIndices.map { (songs[$0.0], songs[$0.1]) }
    }
}
```

- [ ] **Step 2: Build**

Run the **Build** command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Models/StarterPack.swift"
git commit -m "feat(onboarding): add bundled StarterPack for the taste-seed"
```

---

### Task 2: Register the test file

**Files:**
- Create: `Daily MusicTests/TasteSeedTests.swift`

- [ ] **Step 1: Create `Daily MusicTests/TasteSeedTests.swift`** with a placeholder:

```swift
import Testing
@testable import Daily_Music

struct TasteSeedTests {
    @Test func placeholder() { #expect(true) }
}
```

- [ ] **Step 2: Register it**

Run: `/opt/homebrew/opt/ruby/bin/ruby scripts/add_test_files.rb "Daily MusicTests/TasteSeedTests.swift"`
Expected: `added: Daily MusicTests/TasteSeedTests.swift` then `OK`.

- [ ] **Step 3: Verify it runs**

Run the **Test** command. Expected: PASS, output includes `TasteSeedTests`.

- [ ] **Step 4: Commit**

```bash
git add "Daily MusicTests/TasteSeedTests.swift" "Daily Music.xcodeproj"
git commit -m "test: register TasteSeedTests"
```

---

### Task 3: `StarterPack.rounds()` coverage test + `StartingRead` (TDD)

**Files:**
- Create: `Daily Music/Models/StartingRead.swift`
- Modify: `Daily MusicTests/TasteSeedTests.swift`

- [ ] **Step 1: Write the failing tests.** Replace the contents of `TasteSeedTests.swift` with:

```swift
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
```

- [ ] **Step 2: Run, verify failure**

Run the **Test** command. Expected: FAIL — `StartingRead` is undefined. (Confirm `roundsCoverAllSongsOnce` itself passes — if it fails, the Task 1 `pairIndices` array does not cover indices 0–13 exactly once; fix it to `(0,2),(1,13),(10,9),(8,4),(3,11),(12,6),(5,7)`.)

- [ ] **Step 3: Create `Daily Music/Models/StartingRead.swift`:**

```swift
//
//  StartingRead.swift
//  Daily Music
//
//  The onboarding "first read": the dominant mood/genre/decade from the taste-seed
//  picks, computed through the same TasteMirror the real Insights use. Pure +
//  Codable so it can be persisted (the "you started here" memento).
//

import Foundation

struct StartingRead: Equatable, Codable {
    var mood: String?
    var genre: String?
    var decade: String?

    var isEmpty: Bool { mood == nil && genre == nil && decade == nil }

    /// Build from rated starter songs (👍 = +1, 👎 = -1) via TasteMirror's dominant
    /// standouts (dominant works at any count — no unlock threshold needed here).
    static func from(picks: [RatedSong]) -> StartingRead {
        let mirror = TasteMirror.build(from: picks)
        return StartingRead(
            mood: mirror.mood.topStandout?.name,
            genre: mirror.genre.topStandout?.name,
            decade: mirror.decade.topStandout?.name
        )
    }
}
```

- [ ] **Step 4: Run, verify pass**

Run the **Test** command. Expected: PASS (all `TasteSeedTests` + the full suite).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/StartingRead.swift" "Daily MusicTests/TasteSeedTests.swift"
git commit -m "feat(onboarding): StarterPack rounds coverage + StartingRead (TDD)"
```

---

### Task 4: `TasteSeedView` (the cover flow)

**Files:**
- Create: `Daily Music/Views/Onboarding/TasteSeedView.swift`

- [ ] **Step 1: Create the file** with EXACTLY this content:

```swift
//
//  TasteSeedView.swift
//  Daily Music
//
//  The onboarding "find your frequency" flow, shown as a full-screen cover right
//  after the name step: a warm intro → 7 "this or that" rounds (tap a cover to
//  preview, tap Choose to pick) → an instant first-read reveal. Picks build a
//  StartingRead via the real TasteMirror. Onboarding-only: nothing is written to
//  song_ratings.
//

import SwiftUI

struct TasteSeedView: View {
    let displayName: String
    var onComplete: (StartingRead) -> Void
    var onSkip: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: Equatable { case intro, rounds, reveal }
    @State private var phase: Phase = .intro
    @State private var roundIndex = 0
    @State private var picks: [RatedSong] = []
    @State private var read = StartingRead()

    private let rounds = StarterPack.rounds()
    private var player: MusicPlayer { env.musicPlayer }
    private var firstName: String {
        let n = displayName.split(separator: " ").first.map(String.init) ?? displayName
        return n.isEmpty ? "there" : n
    }

    var body: some View {
        ZStack {
            Theme.Brand.gradient.first.map { $0.opacity(0.12) }?.ignoresSafeArea()
            Color(.systemGroupedBackground).opacity(0.6).ignoresSafeArea()
            switch phase {
            case .intro:  intro
            case .rounds: roundsView
            case .reveal: reveal
            }
        }
        .overlay(alignment: .topTrailing) {
            if phase != .reveal {
                Button("Skip") { stopAndExit(onSkip) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: phase)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: roundIndex)
    }

    // MARK: intro
    private var intro: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "dial.medium.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.Brand.gradient[0])
            Text("Alright, \(firstName) —\nlet's find your frequency")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            Text("A few quick taps. For each pair, pick the one that pulls you — tap a cover to hear a taste first.")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Spacer()
            Button { phase = .rounds } label: {
                Text("Begin").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: Theme.Brand.gradient[0]))
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    // MARK: rounds
    private var roundsView: some View {
        let pair = rounds[roundIndex]
        return VStack(spacing: Theme.Spacing.lg) {
            Text("\(roundIndex + 1) of \(rounds.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Spacing.xl)
            Text("Which pulls you?")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
            HStack(spacing: Theme.Spacing.md) {
                choiceCard(pair.0)
                choiceCard(pair.1)
            }
            .padding(.horizontal, Theme.Spacing.md)
            Spacer()
        }
    }

    private func choiceCard(_ song: DailyEntry) -> some View {
        let isPreviewing = player.isPlaying(song)
        return VStack(spacing: Theme.Spacing.sm) {
            Button { togglePreview(song) } label: {
                ZStack(alignment: .bottomTrailing) {
                    AlbumArtView(url: song.albumArtURL, cornerRadius: 16)
                    Image(systemName: isPreviewing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .padding(8)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPreviewing ? "Pause preview of \(song.title)" : "Preview \(song.title)")

            VStack(spacing: 2) {
                Text(song.title).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Button { choose(song) } label: {
                Text("Choose").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Brand.gradient[0])
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: reveal
    private var reveal: some View {
        let profile = TasteProfile.resolve(mood: read.mood, decade: read.decade, theme: nil)
        return VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: profile.symbol)
                .font(.system(size: 56))
                .foregroundStyle(profile.colors.first ?? Theme.Brand.gradient[0])
            Text("Your starting frequency")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(readHeadline)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Text("A starting point — your real taste mirror grows as you rate your daily songs.")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Spacer()
            Button { stopAndExit { onComplete(read) } } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: profile.colors.first ?? Theme.Brand.gradient[0]))
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    private var readHeadline: String {
        let parts = [read.mood, read.genre].compactMap { $0 }
        return parts.isEmpty ? "An open book 📖" : parts.joined(separator: " · ")
    }

    // MARK: actions
    private func togglePreview(_ song: DailyEntry) {
        Task { await player.toggle(song) }
    }

    private func choose(_ song: DailyEntry) {
        Haptics.tap()
        let pair = rounds[roundIndex]
        let other = song.id == pair.0.id ? pair.1 : pair.0
        picks.append(RatedSong(entry: song, value: 1))
        picks.append(RatedSong(entry: other, value: -1))
        Task { await player.stop() }
        if roundIndex + 1 < rounds.count {
            roundIndex += 1
        } else {
            read = StartingRead.from(picks: picks)
            phase = .reveal
        }
    }

    private func stopAndExit(_ action: @escaping () -> Void) {
        Task { await player.stop() }
        action()
    }
}
```

- [ ] **Step 2: Build**

Run the **Build** command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Onboarding/TasteSeedView.swift"
git commit -m "feat(onboarding): add TasteSeedView this-or-that flow"
```

---

### Task 5: Present the taste-seed after "Say hello" + persist the read

**Files:**
- Modify: `Daily Music/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Add state.** After the existing `@State private var goingForward = true` line, add:

```swift
    @State private var showingTasteSeed = false
    @State private var tasteSeedDone = false
    @AppStorage("startingMood") private var startingMood = ""
    @AppStorage("startingGenre") private var startingGenre = ""
    @AppStorage("startingDecade") private var startingDecade = ""
```

- [ ] **Step 2: Present the cover.** In `body`, attach a `.fullScreenCover` to the root `VStack` — add it immediately AFTER the existing `.task { ... }` modifier (which is the last modifier on that `VStack`):

```swift
        .fullScreenCover(isPresented: $showingTasteSeed) {
            TasteSeedView(displayName: displayName) { read in
                startingMood = read.mood ?? ""
                startingGenre = read.genre ?? ""
                startingDecade = read.decade ?? ""
                tasteSeedDone = true
                showingTasteSeed = false
                advance()
            } onSkip: {
                tasteSeedDone = true
                showingTasteSeed = false
                advance()
            }
        }
```

- [ ] **Step 3: Route step 0 through the taste-seed.** Replace the whole `primaryAction()` method with:

```swift
    private func primaryAction() {
        if step == 0 && !tasteSeedDone {
            showingTasteSeed = true   // run the taste-seed; it calls advance() on finish/skip
            return
        }
        guard step == 1 else {
            advance()
            return
        }
        enableReminderAndAdvance()
    }
```

(The taste-seed's `onComplete`/`onSkip` both call `advance()`, moving step 0 → 1 exactly as before. `tasteSeedDone` prevents re-presenting if the user navigates back to step 0.)

- [ ] **Step 4: Build**

Run the **Build** command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/Onboarding/OnboardingView.swift"
git commit -m "feat(onboarding): run taste-seed after name step + persist starting read"
```

---

### Task 6: "You started here" memento in Insights

**Files:**
- Modify: `Daily Music/Views/InsightsView.swift`

- [ ] **Step 1: Add the AppStorage reads.** After the existing `@State private var showingWrapped = false` line in `InsightsView`, add:

```swift
    @AppStorage("startingMood") private var startingMood = ""
    @AppStorage("startingGenre") private var startingGenre = ""
```

- [ ] **Step 2: Render the memento.** In `content(_:)`, replace the existing `return ScrollView { VStack(spacing: Theme.Spacing.lg) { TasteMirrorBoard(mirror: mirror); wrappedButton(accent) } .padding() }` body with one that adds `startedHereCard` above the board:

```swift
        return ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                startedHereCard
                TasteMirrorBoard(mirror: mirror)
                wrappedButton(accent)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .refreshable {
            await model?.load()
            Haptics.tap()
        }
```

- [ ] **Step 3: Add the card view.** Add this computed property to `InsightsView` (e.g., after `wrappedButton`):

```swift
    @ViewBuilder private var startedHereCard: some View {
        let parts = [startingMood, startingGenre].filter { !$0.isEmpty }
        if !parts.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOU STARTED HERE")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)
                    Text(parts.joined(separator: " · "))
                        .font(.subheadline.weight(.bold))
                }
                Spacer()
            }
            .padding(Theme.Spacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
```

- [ ] **Step 4: Build**

Run the **Build** command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/InsightsView.swift"
git commit -m "feat(insights): show the onboarding 'you started here' memento"
```

---

### Task 7: Verification

**Files:** none.

- [ ] **Step 1: Full test suite** — run the **Test** command. Expected: PASS (all `TasteSeedTests` + existing suite).

- [ ] **Step 2: Simulator walkthrough.** Run the app; sign out to reach onboarding (or clear `hasCompletedOnboarding`). Enter a name → Continue → the **taste-seed cover** appears ("let's find your frequency"). Tap a cover to hear a preview (live env = real audio; mock env = silent but the play/pause state flips), tap **Choose** through 7 rounds → a **reveal** ("Your starting frequency: …"). Continue → lands on the reminder step → finish onboarding.

- [ ] **Step 3: Memento.** Open **Insights** → a "YOU STARTED HERE · {mood} · {genre}" card shows above the mirror.

- [ ] **Step 4: Skip path.** Re-run onboarding, tap **Skip** in the taste-seed → it advances to the reminder step with no read stored (no memento).

- [ ] **Step 5: Reduce Motion** — enable it; the flow still works, transitions calm.

- [ ] **Step 6: Commit any tweaks**

```bash
git add -A && git commit -m "test(onboarding): verify taste-seed flow"
```

---

## Self-review notes (author)

- **Spec coverage:** Implements the strategy spec's Section 4 taste-seed as the agreed starter-pack variant: bundled recognizable songs (Task 1), the "this or that" rounds with tap-to-preview (Task 4), a first-read via the real `TasteMirror` (Task 3), persistence + the "you started here" memento (Tasks 5–6). Onboarding-only (no `song_ratings` writes), as designed.
- **Type consistency:** `StarterPack.songs: [DailyEntry]`, `StarterPack.rounds() -> [(DailyEntry, DailyEntry)]`, `StartingRead.from(picks: [RatedSong]) -> StartingRead` (fields `mood/genre/decade`, `isEmpty`), `TasteSeedView(displayName:onComplete:onSkip:)`. Uses existing APIs verified in this repo: `TasteMirror.build(from:)`, `DimensionInsight.topStandout`, `RatedSong(entry:value:)`, `TasteProfile.resolve(mood:decade:theme:)` + `.symbol`/`.colors`, `MusicPlayer.toggle(_:)`/`stop()`/`isPlaying(_:)`, `AlbumArtView(url:cornerRadius:)`, `PrimaryActionButtonStyle(tint:)`, `Theme.Brand.gradient`, `Theme.Spacing`, `Haptics.tap()`.
- **Pairs verified:** `pairIndices = (0,2),(1,13),(10,9),(8,4),(3,11),(12,6),(5,7)` uses each index 0–13 exactly once; `roundsCoverAllSongsOnce` (Task 3) enforces it.
- **Known limitations:** mood "Serene" isn't represented in the 14 (8/9 moods covered) — swap a song later if desired. Tap-to-preview is silent in the mock environment by design; real audio is live-env only.
