# Archetype Visual Identity + Copy Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each archetype's hero card a distinct visual identity through per-archetype backgrounds, and replace cold statistical copy with warm, witty, archetype-voiced text throughout.

**Architecture:** Extract hero copy logic into a testable standalone function (`archetypeHeroCopy`). Extract background rendering into a dedicated `ArchetypeHeroBackground` view that `TasteMirrorBoard.hero()` composes into its existing layout. Stats copy helpers live in `TasteMirrorBoard` alongside their call sites.

**Tech Stack:** SwiftUI (`Canvas`, `TimelineView`, `RadialGradient`, `AngularGradient`, `GeometryReader`), XCTest.

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `Daily Music/Views/Components/ArchetypeCopy.swift` | `archetypeHeroCopy(profile:winningModifier:isCurrentUser:) -> String` — pure function, fully testable |
| Create | `Daily MusicTests/ArchetypeCopyTests.swift` | Unit tests for all archetype copy variants |
| Create | `Daily Music/Views/Components/ArchetypeHeroBackground.swift` | Per-archetype background view (gradient + decorative layers) |
| Modify | `Daily Music/Models/TasteProfile.swift` | Add `heroTopTint: Color` computed property (Hopeless Romantic has a light-top gradient requiring dark badge text) |
| Modify | `Daily Music/Views/Components/TasteMirrorBoard.swift` | Wire `ArchetypeHeroBackground`, call `archetypeHeroCopy`, add `featuredLine` helper, update stats copy, update locked tile |

---

## Build command

All test runs use (xcode-select points at CommandLineTools — the DEVELOPER_DIR override is required):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -only-testing "Daily MusicTests/ArchetypeCopyTests" \
  | grep -E "Test (Suite|Case|passed|failed)|error:"
```

---

## Task 1: Create ArchetypeCopy.swift and tests

**Files:**
- Create: `Daily Music/Views/Components/ArchetypeCopy.swift`
- Create: `Daily MusicTests/ArchetypeCopyTests.swift`

The function is internal (not private) so tests can reach it without mocking the view.

### Pronouns

`you/your/them` cover every case:
- `you` — subject ("you say yes", "they say yes")
- `them` — object ("gets you" → "gets them")
- `your` — possessive

---

- [ ] **Step 1: Create `ArchetypeCopy.swift`**

```swift
// Daily Music/Views/Components/ArchetypeCopy.swift

import Foundation

/// Pure function that returns the "why you're you" hero copy for a given archetype.
/// Extracted from TasteMirrorBoard so it can be unit-tested independently.
func archetypeHeroCopy(
    profile: TasteProfile,
    winningModifier: WinningModifier?,
    isCurrentUser: Bool
) -> String {
    let you   = isCurrentUser ? "you"    : "they"
    let them  = isCurrentUser ? "you"    : "them"
    let your  = isCurrentUser ? "your"   : "their"
    let You   = isCurrentUser ? "You"    : "They"
    let Your  = isCurrentUser ? "Your"   : "Their"
    let youve = isCurrentUser ? "you've" : "they've"
    let youre = isCurrentUser ? "you're" : "they're"

    switch profile.id {
    case "party_animal":
        if let wm = winningModifier, wm.dimensionID == "decade" {
            return "Turns out \(wm.categoryName) music is basically a standing invitation and \(you) never say no. Almost every track makes the cut."
        }
        return "Euphoric songs show up and \(you) say yes. Consistently, enthusiastically, every time."

    case "flower_child":
        return "Joyful songs make up more of \(your) keeps than almost any other mood. Guilty pleasure? Never met her."

    case "hopeless_romantic":
        if let wm = winningModifier, wm.dimensionID == "genre" {
            return "\(wm.categoryName) gets \(them) every time. \(Your) keep rate there is almost embarrassingly high."
        }
        return "A tender song comes on and \(you) say yes. More often than not. More often than almost anything."

    case "the_hippie":
        return "\(You) keep serene songs more than almost any other mood. Everything else is just noise."

    case "the_stargazer":
        if let wm = winningModifier, wm.dimensionID == "theme" {
            return "Songs about \(wm.categoryName.lowercased()) take \(them) somewhere. \(You) follow. \(You) keep nearly every one."
        }
        return "Dreamy songs take \(them) somewhere. \(You) keep nearly all of them. It's less a habit than a timezone."

    case "born_in_the_wrong_generation":
        if let wm = winningModifier, wm.dimensionID == "decade" {
            return "\(wm.categoryName) was made for \(you) and \(you) both know it. \(Your) keep rate there is almost unfairly high for someone who technically wasn't there."
        }
        return "Nostalgic songs make up more of \(your) keeps than almost any other mood. Homesick for somewhere \(youve) never been."

    case "the_melancholic":
        if let wm = winningModifier, wm.dimensionID == "decade" {
            return "There's a weight to \(wm.categoryName) music that \(you) understand on a level most people don't even look for. \(You) keep nearly all of it."
        }
        return "Melancholy songs make up more of \(your) keeps than almost any other mood. Not because \(youre) not paying attention. Because \(you) are."

    case "loud_and_proud":
        return "\(You) keep defiant songs more than almost any other mood. \(Your) eardrums will heal."

    case "the_outsider":
        return "\(You) keep dark songs more than almost any other mood. \(You) smile, sometimes."

    default: // the_shapeshifter + any future archetypes
        return "\(You) don't have one defining taste. \(You) have all of them. \(Your) keep rate spreads pretty evenly across every mood, and that says a lot about \(you). A lot of good things."
    }
}
```

- [ ] **Step 2: Write failing tests in `ArchetypeCopyTests.swift`**

```swift
// Daily MusicTests/ArchetypeCopyTests.swift

import XCTest
@testable import Daily_Music

final class ArchetypeCopyTests: XCTestCase {

    // MARK: - Current user / modifier wins

    func test_partyAnimal_eraModifier_currentUser() {
        let wm = WinningModifier(dimensionID: "decade", categoryName: "1980s",
                                 likeRate: 0.72, total: 18, margin: 0.14)
        let copy = archetypeHeroCopy(profile: .partyAnimal, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Turns out 1980s music is basically a standing invitation and you never say no. Almost every track makes the cut.")
    }

    func test_partyAnimal_noModifier_currentUser() {
        let copy = archetypeHeroCopy(profile: .partyAnimal, winningModifier: nil, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Euphoric songs show up and you say yes. Consistently, enthusiastically, every time.")
    }

    func test_hopelessRomantic_genreModifier_currentUser() {
        let wm = WinningModifier(dimensionID: "genre", categoryName: "R&B",
                                 likeRate: 0.81, total: 12, margin: 0.23)
        let copy = archetypeHeroCopy(profile: .hopelessRomantic, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "R&B gets you every time. Your keep rate there is almost embarrassingly high.")
    }

    func test_stargazer_themeModifier_currentUser() {
        let wm = WinningModifier(dimensionID: "theme", categoryName: "Longing",
                                 likeRate: 0.75, total: 10, margin: 0.17)
        let copy = archetypeHeroCopy(profile: .theStargazer, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Songs about longing take you somewhere. You follow. You keep nearly every one.")
    }

    func test_bornWrongGen_eraModifier_currentUser() {
        let wm = WinningModifier(dimensionID: "decade", categoryName: "1970s",
                                 likeRate: 0.80, total: 14, margin: 0.22)
        let copy = archetypeHeroCopy(profile: .bornInTheWrongGeneration, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "1970s was made for you and you both know it. Your keep rate there is almost unfairly high for someone who technically wasn't there.")
    }

    func test_melancholic_eraModifier_currentUser() {
        let wm = WinningModifier(dimensionID: "decade", categoryName: "1990s",
                                 likeRate: 0.79, total: 16, margin: 0.21)
        let copy = archetypeHeroCopy(profile: .theMelancholic, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "There's a weight to 1990s music that you understand on a level most people don't even look for. You keep nearly all of it.")
    }

    // MARK: - Mood fallbacks (no modifier / wrong dimension)

    func test_stargazer_genreModifier_fallsBackToMood() {
        // theme is primary for Stargazer; a genre win should fall through to mood fallback
        let wm = WinningModifier(dimensionID: "genre", categoryName: "Ambient",
                                 likeRate: 0.75, total: 10, margin: 0.17)
        let copy = archetypeHeroCopy(profile: .theStargazer, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Dreamy songs take you somewhere. You keep nearly all of them. It's less a habit than a timezone.")
    }

    func test_melancholic_themeModifier_fallsBackToMood() {
        let wm = WinningModifier(dimensionID: "theme", categoryName: "Loss",
                                 likeRate: 0.79, total: 14, margin: 0.21)
        let copy = archetypeHeroCopy(profile: .theMelancholic, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Melancholy songs make up more of your keeps than almost any other mood. Not because you're not paying attention. Because you are.")
    }

    // MARK: - Mood-only archetypes (modifier ignored)

    func test_flowerChild_ignoresModifier() {
        let wm = WinningModifier(dimensionID: "decade", categoryName: "1990s",
                                 likeRate: 0.7, total: 10, margin: 0.12)
        let copy = archetypeHeroCopy(profile: .flowerChild, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Joyful songs make up more of your keeps than almost any other mood. Guilty pleasure? Never met her.")
    }

    func test_loudAndProud_ignoresModifier() {
        let wm = WinningModifier(dimensionID: "genre", categoryName: "Metal",
                                 likeRate: 0.85, total: 10, margin: 0.27)
        let copy = archetypeHeroCopy(profile: .loudAndProud, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "You keep defiant songs more than almost any other mood. Your eardrums will heal.")
    }

    func test_outsider_ignoresModifier() {
        let copy = archetypeHeroCopy(profile: .theOutsider, winningModifier: nil, isCurrentUser: true)
        XCTAssertEqual(copy,
            "You keep dark songs more than almost any other mood. You smile, sometimes.")
    }

    func test_shapeshifter_noModifier() {
        let copy = archetypeHeroCopy(profile: .theShapeshifter, winningModifier: nil, isCurrentUser: true)
        XCTAssertEqual(copy,
            "You don't have one defining taste. You have all of them. Your keep rate spreads pretty evenly across every mood, and that says a lot about you. A lot of good things.")
    }

    // MARK: - Friend mirror (isCurrentUser: false)

    func test_partyAnimal_eraModifier_friend() {
        let wm = WinningModifier(dimensionID: "decade", categoryName: "1980s",
                                 likeRate: 0.72, total: 18, margin: 0.14)
        let copy = archetypeHeroCopy(profile: .partyAnimal, winningModifier: wm, isCurrentUser: false)
        XCTAssertEqual(copy,
            "Turns out 1980s music is basically a standing invitation and they never say no. Almost every track makes the cut.")
    }

    func test_hippie_friend() {
        let copy = archetypeHeroCopy(profile: .theHippie, winningModifier: nil, isCurrentUser: false)
        XCTAssertEqual(copy,
            "They keep serene songs more than almost any other mood. Everything else is just noise.")
    }

    func test_hopelessRomantic_genreModifier_friend() {
        let wm = WinningModifier(dimensionID: "genre", categoryName: "Soul",
                                 likeRate: 0.78, total: 11, margin: 0.2)
        let copy = archetypeHeroCopy(profile: .hopelessRomantic, winningModifier: wm, isCurrentUser: false)
        XCTAssertEqual(copy,
            "Soul gets them every time. Their keep rate there is almost embarrassingly high.")
    }

    func test_outsider_friend() {
        let copy = archetypeHeroCopy(profile: .theOutsider, winningModifier: nil, isCurrentUser: false)
        XCTAssertEqual(copy,
            "They keep dark songs more than almost any other mood. They smile, sometimes.")
    }

    // MARK: - No em-dashes in any output

    func test_noEmDashesInAnyOutput() {
        let allProfiles = TasteProfile.allCases
        let modifiers: [WinningModifier?] = [
            nil,
            WinningModifier(dimensionID: "decade", categoryName: "1980s", likeRate: 0.72, total: 10, margin: 0.14),
            WinningModifier(dimensionID: "theme",  categoryName: "Love",  likeRate: 0.75, total: 10, margin: 0.17),
            WinningModifier(dimensionID: "genre",  categoryName: "Rock",  likeRate: 0.80, total: 10, margin: 0.22),
        ]
        for profile in allProfiles {
            for modifier in modifiers {
                let copy = archetypeHeroCopy(profile: profile, winningModifier: modifier, isCurrentUser: true)
                XCTAssertFalse(copy.contains("\u{2014}"),
                    "Em-dash found in \(profile.id) copy: \(copy)")
            }
        }
    }
}
```

- [ ] **Step 3: Run tests — expect all to fail** (function doesn't exist yet)

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -only-testing "Daily MusicTests/ArchetypeCopyTests" \
  | grep -E "Test (Suite|Case|passed|failed)|error:"
```

Expected: compile error — `archetypeHeroCopy` not found.

- [ ] **Step 4: Run tests — expect all to pass**

Same command as Step 3. The file from Step 1 should already be saved; this confirms the function is reachable from the test target.

Expected: all 17 tests pass.

- [ ] **Step 5: Replace `heroWhy()` in `TasteMirrorBoard.swift`**

Find the existing `heroWhy` method (around line 155) and replace it entirely:

```swift
private func heroWhy(_ mirror: TasteMirror) -> String {
    let profile = displayArchetype ?? mirror.archetype ?? .theShapeshifter
    return archetypeHeroCopy(
        profile: profile,
        winningModifier: mirror.winningModifier,
        isCurrentUser: isCurrentUser
    )
}
```

Delete the old `let moodStat`, `let overall`, `let keep`, `let your`, `guard let wm`, and all the switch cases — they're now in `ArchetypeCopy.swift`.

- [ ] **Step 6: Build and confirm no compile errors**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild build \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Views/Components/ArchetypeCopy.swift" \
        "Daily Music/Views/Components/TasteMirrorBoard.swift" \
        "Daily MusicTests/ArchetypeCopyTests.swift"
git commit -m "feat(insights): archetype-voiced hero copy, fully tested"
```

---

## Task 2: Rewrite stats copy

**Files:**
- Modify: `Daily Music/Views/Components/TasteMirrorBoard.swift`
- Create: `Daily MusicTests/StatsCopyTests.swift`

---

- [ ] **Step 1: Write failing tests for `featuredLine`**

```swift
// Daily MusicTests/StatsCopyTests.swift

import XCTest
@testable import Daily_Music

final class StatsCopyTests: XCTestCase {
    // Tests call the helper via a minimal TasteMirrorBoard.
    // Because featuredLine is private, test through a thin wrapper we'll add in Step 2.
    // For now, write the tests against the expected string format.

    func test_featuredLine_highRate_currentUser() {
        // 7 of 10 = 70% >= 60%
        let result = featuredLineString(likes: 7, total: 10, likeRate: 0.7, isCurrentUser: true)
        XCTAssertEqual(result, "7 of 10 kept. You're basically a fan.")
    }

    func test_featuredLine_midRate_currentUser() {
        // 5 of 10 = 50%, in 40–59% band
        let result = featuredLineString(likes: 5, total: 10, likeRate: 0.5, isCurrentUser: true)
        XCTAssertEqual(result, "5 of 10 kept. About half make the cut.")
    }

    func test_featuredLine_lowRate_currentUser() {
        // 3 of 10 = 30% < 40%
        let result = featuredLineString(likes: 3, total: 10, likeRate: 0.3, isCurrentUser: true)
        XCTAssertEqual(result, "3 of 10 kept. Not really your thing.")
    }

    func test_featuredLine_highRate_friend() {
        let result = featuredLineString(likes: 8, total: 10, likeRate: 0.8, isCurrentUser: false)
        XCTAssertEqual(result, "8 of 10 kept. They're basically a fan.")
    }

    func test_featuredLine_lowRate_friend() {
        let result = featuredLineString(likes: 2, total: 10, likeRate: 0.2, isCurrentUser: false)
        XCTAssertEqual(result, "2 of 10 kept. Not really their thing.")
    }

    func test_featuredLine_noEmDash() {
        let cases: [(Int, Int, Double)] = [(7,10,0.7),(5,10,0.5),(2,10,0.2)]
        for (l, t, r) in cases {
            let result = featuredLineString(likes: l, total: t, likeRate: r, isCurrentUser: true)
            XCTAssertFalse(result.contains("\u{2014}"), "Em-dash in: \(result)")
        }
    }
}
```

Add a thin internal helper to `TasteMirrorBoard.swift` that the test target can call — add this **outside** the struct, at the bottom of the file, marked `internal`:

```swift
// Testable wrapper — lets StatsCopyTests call the private logic without exposing the view.
func featuredLineString(likes: Int, total: Int, likeRate: Double, isCurrentUser: Bool) -> String {
    let subj = isCurrentUser ? "You're" : "They're"
    let poss = isCurrentUser ? "your"   : "their"
    let qualifier: String
    switch likeRate {
    case 0.6...: qualifier = "\(subj) basically a fan."
    case 0.4..<0.6: qualifier = "About half make the cut."
    default: qualifier = "Not really \(poss) thing."
    }
    return "\(likes) of \(total) kept. \(qualifier)"
}
```

- [ ] **Step 2: Run tests — expect failure** (file compiles but logic not wired yet — tests should pass once the function is added)

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -only-testing "Daily MusicTests/StatsCopyTests" \
  | grep -E "Test (Suite|Case|passed|failed)|error:"
```

Expected: all 5 tests **pass** (the free function is already there from Step 1).

- [ ] **Step 3: Update `makeDetail` in `TasteMirrorBoard.swift`**

Find the `makeDetail` function. Replace the `featuredLine:` argument:

```swift
// Before:
featuredLine: "Keeps \(featured.likes) of \(featured.total) — \(Int(featured.likeRate * 100))% yes.",

// After:
featuredLine: featuredLineString(
    likes: featured.likes, total: featured.total,
    likeRate: featured.likeRate, isCurrentUser: isCurrentUser
),
```

- [ ] **Step 4: Update `makeEnergyDetail` in `TasteMirrorBoard.swift`**

Find the `makeEnergyDetail` function. Replace the `featuredLine:` argument:

```swift
// Before:
featuredLine: "Liked songs average \(String(format: "%.1f", mean)) out of 5.",

// After:
featuredLine: "Saved songs lean \(lean), averaging a \(String(format: "%.1f", mean)) out of 5 on energy.",
```

- [ ] **Step 5: Update locked tile text**

Find `lockedTile` in `TasteMirrorBoard.swift`. Replace the label:

```swift
// Before:
Text("Keep rating")
    .font(.subheadline.weight(.semibold))
    .foregroundStyle(.secondary)

// After:
Text("Rate more to unlock")
    .font(.subheadline.weight(.semibold))
    .foregroundStyle(.secondary)
```

- [ ] **Step 6: Build and confirm no compile errors**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild build \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  | grep -E "error:|Build succeeded"
```

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Views/Components/TasteMirrorBoard.swift" \
        "Daily MusicTests/StatsCopyTests.swift"
git commit -m "feat(insights): warm stats copy, friendlier locked tile text"
```

---

## Task 3: Create ArchetypeHeroBackground

**Files:**
- Create: `Daily Music/Views/Components/ArchetypeHeroBackground.swift`
- Modify: `Daily Music/Models/TasteProfile.swift`

No unit tests for this task — it is a purely visual component.

---

- [ ] **Step 1: Add `heroTopTint` to `TasteProfile.swift`**

The Hopeless Romantic background has a light top (`#ffd6e8`) that needs dark text on the badge and icon. All other archetypes keep white.

At the bottom of `TasteProfile`, before the closing `}`:

```swift
/// Tint applied to the badge label and icon at the top of the hero card.
/// Hopeless Romantic's light-top gradient requires a dark tint for contrast.
var heroTopTint: Color {
    id == "hopeless_romantic"
        ? Color(red: 0.37, green: 0.0, blue: 0.22).opacity(0.8)
        : .white
}
```

- [ ] **Step 2: Create `ArchetypeHeroBackground.swift`**

```swift
// Daily Music/Views/Components/ArchetypeHeroBackground.swift

import SwiftUI

/// Per-archetype hero card background: gradient base + mood-specific decorative layers.
/// Drop this into the hero ZStack as a `.background()` replacement.
struct ArchetypeHeroBackground: View {
    let profile: TasteProfile

    var body: some View {
        switch profile.id {
        case "party_animal":           PartyAnimalBg()
        case "flower_child":           FlowerChildBg(colors: profile.colors)
        case "hopeless_romantic":      RomanticBg()
        case "the_hippie":             HippieBg(colors: profile.colors)
        case "the_stargazer":          StargazerBg()
        case "born_in_the_wrong_generation": BornWrongGenBg(colors: profile.colors)
        case "the_melancholic":        MelancholicBg()
        case "loud_and_proud":         LoudBg(colors: profile.colors)
        case "the_outsider":           OutsiderBg()
        default:                       ShapeshifterBg(colors: profile.colors)
        }
    }
}

// MARK: - Party Animal: 3-stop gradient + spinning conic burst

private struct PartyAnimalBg: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let angle = t.truncatingRemainder(dividingBy: 8) / 8 * 360
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 1.0, green: 0.584, blue: 0.141), location: 0),
                        .init(color: Color(red: 1.0, green: 0.271, blue: 0.0),   location: 0.5),
                        .init(color: Color(red: 0.788, green: 0.047, blue: 0.0), location: 1),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                GeometryReader { geo in
                    AngularGradient(
                        stops: [
                            .init(color: .yellow.opacity(0.28), location: 0.0),
                            .init(color: .orange.opacity(0.04), location: 0.25),
                            .init(color: .yellow.opacity(0.28), location: 0.5),
                            .init(color: .orange.opacity(0.04), location: 0.75),
                            .init(color: .yellow.opacity(0.28), location: 1.0),
                        ],
                        center: .center
                    )
                    .clipShape(Circle())
                    .frame(width: 200, height: 200)
                    .position(x: geo.size.width + 20, y: -20)
                    .rotationEffect(.degrees(angle))
                }
            }
        }
    }
}

// MARK: - Flower Child: existing gradient + radial bloom + bokeh

private struct FlowerChildBg: View {
    let colors: [Color]
    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(
                colors: [.white.opacity(0.22), .clear],
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 0, endRadius: 100
            )
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                Circle().fill(.white.opacity(0.16)).frame(width: 20, height: 20).blur(radius: 4).position(x: w*0.15, y: h*0.15)
                Circle().fill(.white.opacity(0.11)).frame(width: 14, height: 14).blur(radius: 4).position(x: w*0.72, y: h*0.12)
                Circle().fill(.white.opacity(0.13)).frame(width: 18, height: 18).blur(radius: 4).position(x: w*0.40, y: h*0.30)
                Circle().fill(.white.opacity(0.09)).frame(width: 12, height: 12).blur(radius: 4).position(x: w*0.85, y: h*0.38)
                Circle().fill(.white.opacity(0.12)).frame(width: 16, height: 16).blur(radius: 4).position(x: w*0.25, y: h*0.58)
                Circle().fill(.white.opacity(0.07)).frame(width: 10, height: 10).blur(radius: 4).position(x: w*0.65, y: h*0.62)
            }
        }
    }
}

// MARK: - Hopeless Romantic: light-to-dark + heart tile + top glow

private struct RomanticBg: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.0,   green: 0.839, blue: 0.910), location: 0.0),
                    .init(color: Color(red: 1.0,   green: 0.373, blue: 0.655), location: 0.3),
                    .init(color: Color(red: 0.690, green: 0.094, blue: 0.431), location: 0.72),
                    .init(color: Color(red: 0.369, green: 0.0,   blue: 0.220), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [.white.opacity(0.18), .clear],
                center: UnitPoint(x: 0.25, y: 0.08),
                startRadius: 0, endRadius: 80
            )
            Canvas { ctx, size in
                let spacing: CGFloat = 32
                let cols = Int(size.width / spacing) + 2
                let rows = Int(size.height / spacing) + 2
                for row in 0..<rows {
                    for col in 0..<cols {
                        let x = CGFloat(col) * spacing + (row.isMultiple(of: 2) ? spacing / 2 : 0)
                        let y = CGFloat(row) * spacing
                        ctx.draw(
                            Text("♡").font(.system(size: 13)).foregroundColor(.white.opacity(0.07)),
                            at: CGPoint(x: x, y: y)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - The Hippie: existing gradient + ripple rings

private struct HippieBg: View {
    let colors: [Color]
    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                let cx = geo.size.width * 0.85
                let cy = geo.size.height * 0.85
                ForEach([80, 130, 180] as [CGFloat], id: \.self) { r in
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                        .frame(width: r * 2, height: r * 2)
                        .position(x: cx, y: cy)
                }
            }
        }
    }
}

// MARK: - The Stargazer: deep radial + star field + aurora

private struct StargazerBg: View {
    // (x_fraction, y_fraction, diameter, opacity)
    private let stars: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.18, 0.10, 2.0, 0.90), (0.55, 0.07, 1.5, 0.70),
        (0.80, 0.20, 2.0, 0.80), (0.33, 0.36, 1.0, 0.55),
        (0.44, 0.17, 1.5, 0.85), (0.65, 0.28, 1.0, 0.50),
        (0.90, 0.06, 2.0, 0.90), (0.82, 0.52, 1.0, 0.40),
        (0.12, 0.42, 1.5, 0.65), (0.59, 0.44, 1.0, 0.45),
    ]

    var body: some View {
        ZStack {
            RadialGradient(
                stops: [
                    .init(color: Color(red: 0.427, green: 0.310, blue: 0.788), location: 0.0),
                    .init(color: Color(red: 0.165, green: 0.063, blue: 0.376), location: 0.45),
                    .init(color: Color(red: 0.020, green: 0.004, blue: 0.063), location: 1.0),
                ],
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 0, endRadius: 280
            )
            // Aurora
            RadialGradient(
                colors: [Color(red: 0.47, green: 0.24, blue: 0.78).opacity(0.28), .clear],
                center: UnitPoint(x: 0.3, y: 0.65),
                startRadius: 0, endRadius: 140
            )
            // Stars
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ForEach(0..<stars.count, id: \.self) { i in
                    let s = stars[i]
                    Circle()
                        .fill(.white.opacity(s.3))
                        .frame(width: s.2, height: s.2)
                        .position(x: w * s.0, y: h * s.1)
                }
            }
        }
    }
}

// MARK: - Born in the Wrong Generation: existing gradient + warm vignette

private struct BornWrongGenBg: View {
    let colors: [Color]
    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            // Warm vignette: subtle darkening at edges to evoke analog warmth
            RadialGradient(
                colors: [.clear, .black.opacity(0.22)],
                center: .center,
                startRadius: 60, endRadius: 200
            )
        }
    }
}

// MARK: - The Melancholic: 4-stop gradient + animated rain + moon glow

private struct MelancholicBg: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(t.truncatingRemainder(dividingBy: 3.0) / 3.0)
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.431, green: 0.565, blue: 0.784), location: 0.0),
                        .init(color: Color(red: 0.176, green: 0.306, blue: 0.565), location: 0.35),
                        .init(color: Color(red: 0.067, green: 0.106, blue: 0.306), location: 0.70),
                        .init(color: Color(red: 0.020, green: 0.031, blue: 0.094), location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                // Moon glow
                RadialGradient(
                    colors: [.white.opacity(0.18), .clear],
                    center: UnitPoint(x: 0.88, y: 0.0),
                    startRadius: 0, endRadius: 70
                )
                // Animated rain streaks
                GeometryReader { geo in
                    Canvas { ctx2, size in
                        let spacing: CGFloat = 28
                        let streakH: CGFloat = 48
                        let cols = Int(size.width / spacing) + 2
                        let yOffset = phase * streakH
                        for col in 0..<cols {
                            let x = CGFloat(col) * spacing
                            var y = yOffset - streakH
                            while y < size.height + streakH {
                                let path = Path { p in
                                    p.move(to: CGPoint(x: x + 5, y: y))
                                    p.addLine(to: CGPoint(x: x, y: y + streakH * 0.65))
                                }
                                ctx2.stroke(path, with: .color(.white.opacity(0.11)), lineWidth: 1)
                                y += streakH
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Loud & Proud: existing gradient + edge burn

private struct LoudBg: View {
    let colors: [Color]
    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(
                colors: [.clear, .black.opacity(0.40)],
                center: .center,
                startRadius: 40, endRadius: 200
            )
        }
    }
}

// MARK: - The Outsider: deep purple gradient + half-circle motif

private struct OutsiderBg: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.478, green: 0.310, blue: 0.749),
                    Color(red: 0.102, green: 0.039, blue: 0.188),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            GeometryReader { geo in
                // Half-circle echoing the circle.lefthalf.filled symbol
                Circle()
                    .trim(from: 0.0, to: 0.5)
                    .fill(.white.opacity(0.06))
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(90))
                    .position(x: geo.size.width + 50, y: geo.size.height * 0.5)
            }
        }
    }
}

// MARK: - The Shapeshifter: existing gradient (restrained — no dominant identity)

private struct ShapeshifterBg: View {
    let colors: [Color]
    var body: some View {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
```

- [ ] **Step 3: Build and confirm no compile errors**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild build \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/Components/ArchetypeHeroBackground.swift" \
        "Daily Music/Models/TasteProfile.swift"
git commit -m "feat(insights): per-archetype hero backgrounds"
```

---

## Task 4: Wire ArchetypeHeroBackground into TasteMirrorBoard

**Files:**
- Modify: `Daily Music/Views/Components/TasteMirrorBoard.swift`

---

- [ ] **Step 1: Replace gradient background in `hero()`**

In `TasteMirrorBoard.swift`, find the hero card's `.background(...)` modifier (around line 149):

```swift
// Before:
.background(LinearGradient(colors: profile.colors, startPoint: .topLeading, endPoint: .bottomTrailing))

// After:
.background(ArchetypeHeroBackground(profile: profile))
```

- [ ] **Step 2: Update badge and icon to use `heroTopTint`**

Still in `hero()`, find the HStack with the icon and badge. Replace `.white` color references for the badge label and icon:

```swift
// Before (badge label):
.foregroundStyle(.white.opacity(0.75))

// After:
.foregroundStyle(profile.heroTopTint.opacity(0.75))
```

```swift
// Before (icon foreground):
.foregroundStyle(.white)

// After:
.foregroundStyle(profile.heroTopTint)
```

```swift
// Before (icon background):
.background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

// After:
.background(profile.heroTopTint.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
```

The title, tagline, and heroWhy text are at the bottom of the card where the Romantic gradient is dark — they keep `.white` as-is.

- [ ] **Step 3: Update drop shadow to use archetype lead color**

The shadow is already using `profile.colors[0]` — no change needed. Confirm the existing line reads:

```swift
.shadow(color: profile.colors[0].opacity(0.35), radius: 20, y: 10)
```

For Romantic, `profile.colors[0]` is the light pink `c(1.0, 0.39, 0.67)`. The shadow will be a light pink glow which looks fine. No change needed.

- [ ] **Step 4: Build and confirm no compile errors**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild build \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 5: Run the full test suite to catch regressions**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  | grep -E "Test (Suite|Case|passed|failed)|error:"
```

Expected: all tests pass, no regressions.

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Views/Components/TasteMirrorBoard.swift"
git commit -m "feat(insights): wire per-archetype backgrounds into hero card"
```
