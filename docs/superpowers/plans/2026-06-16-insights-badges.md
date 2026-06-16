# Insights Badges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a habit-rewarding badge system to the Insights tab — tiered count badges (streak, mint, crate, saves, ratings, rescues) and hidden one-time "moment" badges — derived entirely from data the app already syncs.

**Architecture:** Pure-derived. A `BadgeDeriver` computes `[EarnedBadge]` from a plain `BadgeInputs` snapshot (entries + listens + favorites + ratings + check-ins + archetype state). A `BadgeService` protocol wraps it as the seam for a future Supabase/friend source. A tiny `BadgeSeenStore` (UserDefaults) drives lightweight earn celebrations without ever deciding whether a badge is earned. `BadgesViewModel` assembles inputs from the existing stores and feeds an Insights summary card + a full `BadgesView`.

**Tech Stack:** Swift 5.9, SwiftUI, `@Observable` MVVM, Swift Testing (`import Testing`, `@Test`, `#expect`).

**Spec:** `docs/superpowers/specs/2026-06-15-insights-badges-design.md`

---

## Conventions for every task

- **Build the app** (compiles new files in `Daily Music/` automatically — file-system-synchronized group):
  ```bash
  cd "/Users/maximesavehilaghi/Developer/Daily Music"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    xcodebuild -scheme "Daily Music" \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build
  ```
- **Run the badge tests:**
  ```bash
  cd "/Users/maximesavehilaghi/Developer/Daily Music"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    xcodebuild test -scheme "Daily Music" \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:"Daily MusicTests/BadgeTests"
  ```
- **Test target is NOT auto-synchronized.** All unit tests in this plan live in ONE new file, `Daily MusicTests/BadgeTests.swift`. It must be added to the `Daily MusicTests` target in Xcode **once** (Task 1) before tests can run. After that, later tasks append to the same file with no further registration.
- Commit after each task. Commit messages use the bodies shown; end each with the Co-Authored-By trailer the repo uses.

---

## File structure

**Create (app target — auto-compiles):**
- `Daily Music/Models/Badge.swift` — `BadgeKind`, `BadgeDefinition`, `TierProgress`, `EarnedBadge`, `BadgeMath`, `BadgeCatalog`. Pure data + tier math.
- `Daily Music/Models/BadgeInputs.swift` — the snapshot struct fed to the deriver.
- `Daily Music/Services/BadgeDeriver.swift` — pure derivation of `[EarnedBadge]` from `BadgeInputs`.
- `Daily Music/Services/BadgeService.swift` — `BadgeService` protocol + `DerivedBadgeService`.
- `Daily Music/Services/BadgeSeenStore.swift` — UserDefaults "already-celebrated" keys + baseline + newly-earned diff.
- `Daily Music/ViewModels/BadgesViewModel.swift` — assembles inputs, exposes badges/summary/newlyEarned.
- `Daily Music/Views/BadgesView.swift` — full badge grid screen.
- `Daily Music/Views/Components/BadgeCelebrationCard.swift` — lightweight earn toast.

**Modify:**
- `Daily Music/Views/InsightsView.swift` — add the summary card (between hero and history card), the `NavigationLink` to `BadgesView`, and the celebration overlay.

**Create (test target — needs one-time Xcode registration):**
- `Daily MusicTests/BadgeTests.swift` — all unit tests.

---

## Task 1: Badge models + tier math

**Files:**
- Create: `Daily Music/Models/Badge.swift`
- Test: `Daily MusicTests/BadgeTests.swift`

- [ ] **Step 1: Create `Daily Music/Models/Badge.swift` with the model skeleton (no tier math yet)**

```swift
//
//  Badge.swift
//  Daily Music
//
//  Pure data for the Insights badge system: the catalogue of badge definitions,
//  the tier-progress math, and the EarnedBadge value the UI renders. No I/O — the
//  BadgeDeriver turns a BadgeInputs snapshot into [EarnedBadge] using these types.
//

import SwiftUI

/// How a badge progresses. Tiered badges count toward thresholds; moments are
/// a single hidden achievement.
enum BadgeKind: Equatable {
    case tiered(thresholds: [Int])
    case moment
}

/// Static description of a badge — the catalogue entry. No user state.
struct BadgeDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String      // emoji glyph rendered on the disc
    let tint: Color
    let kind: BadgeKind
}

/// Where a tiered badge sits relative to its thresholds.
struct TierProgress: Equatable {
    /// Number of thresholds met (0 = nothing earned yet).
    let unlockedTier: Int
    /// The next threshold to reach, nil once maxed.
    let nextThreshold: Int?
    /// 0…1 progress from the current tier floor to the next threshold; 1 when maxed.
    let progressToNext: Double

    var isEarned: Bool { unlockedTier > 0 }
    var isMaxed: Bool { nextThreshold == nil }
}

/// A definition joined with the user's current state. The UI renders this.
struct EarnedBadge: Identifiable, Equatable {
    let definition: BadgeDefinition
    let value: Int          // raw count (tiered) or 0/1 (moment)
    let isEarned: Bool
    let tier: TierProgress? // nil for moments

    var id: String { definition.id }

    /// Celebration key: a tiered badge can celebrate once per tier; a moment once.
    var seenKey: String {
        if let tier { return "\(definition.id):\(tier.unlockedTier)" }
        return "moment:\(definition.id)"
    }
}
```

- [ ] **Step 2: Create `Daily MusicTests/BadgeTests.swift` with the first failing test**

```swift
//
//  BadgeTests.swift
//  Daily MusicTests
//
//  All unit tests for the Insights badge system: tier math, derivation, the
//  seen-store diff, and summary building.
//

import Foundation
import Testing
@testable import Daily_Music

struct BadgeTests {

    // MARK: - Tier math

    @Test func tierProgressBelowFirstThreshold() {
        let p = BadgeMath.tierProgress(value: 2, thresholds: [3, 7, 14])
        #expect(p.unlockedTier == 0)
        #expect(p.nextThreshold == 3)
        #expect(!p.isEarned)
        #expect(abs(p.progressToNext - (2.0 / 3.0)) < 0.0001)
    }

    @Test func tierProgressExactlyOnThreshold() {
        let p = BadgeMath.tierProgress(value: 7, thresholds: [3, 7, 14])
        #expect(p.unlockedTier == 2)
        #expect(p.nextThreshold == 14)
        #expect(abs(p.progressToNext - 0.0) < 0.0001) // at the floor of tier 3
    }

    @Test func tierProgressBetweenThresholds() {
        let p = BadgeMath.tierProgress(value: 10, thresholds: [3, 7, 14])
        #expect(p.unlockedTier == 2)
        #expect(p.nextThreshold == 14)
        // floor 7, span 7, value 10 → 3/7
        #expect(abs(p.progressToNext - (3.0 / 7.0)) < 0.0001)
    }

    @Test func tierProgressPastMax() {
        let p = BadgeMath.tierProgress(value: 99, thresholds: [3, 7, 14])
        #expect(p.unlockedTier == 3)
        #expect(p.nextThreshold == nil)
        #expect(p.isMaxed)
        #expect(p.progressToNext == 1.0)
    }
}
```

- [ ] **Step 3: Register the test file with the test target, then run to verify it fails**

Open `Daily Music.xcodeproj` in Xcode, drag `BadgeTests.swift` into the `Daily MusicTests` group, and ensure **Target Membership → Daily MusicTests** is checked (this updates `project.pbxproj`). Quit Xcode (it removes `Package.resolved`; restore it if needed — see memory).

Run: the test command above.
Expected: FAIL — `BadgeMath` is undefined / does not compile.

- [ ] **Step 4: Add `BadgeMath` to `Daily Music/Models/Badge.swift`**

Append to `Badge.swift`:

```swift
/// Pure tier-progress math. `value` is the user's count; `thresholds` the badge's
/// tier ladder (any order — sorted internally).
enum BadgeMath {
    static func tierProgress(value: Int, thresholds: [Int]) -> TierProgress {
        let sorted = thresholds.sorted()
        let unlocked = sorted.filter { value >= $0 }.count

        guard unlocked < sorted.count else {
            return TierProgress(unlockedTier: unlocked, nextThreshold: nil, progressToNext: 1.0)
        }

        let next = sorted[unlocked]
        let floor = unlocked == 0 ? 0 : sorted[unlocked - 1]
        let span = next - floor
        let progress = span <= 0 ? 0 : Double(value - floor) / Double(span)
        return TierProgress(
            unlockedTier: unlocked,
            nextThreshold: next,
            progressToNext: min(max(progress, 0), 1)
        )
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: the test command above.
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Models/Badge.swift" "Daily MusicTests/BadgeTests.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "feat(badges): badge models + tier-progress math"
```

---

## Task 2: Badge catalogue

**Files:**
- Modify: `Daily Music/Models/Badge.swift`
- Test: `Daily MusicTests/BadgeTests.swift`

- [ ] **Step 1: Add a failing test for the catalogue**

Append inside `struct BadgeTests`:

```swift
// MARK: - Catalogue

@Test func catalogueHasSixTieredAndSixMoments() {
    #expect(BadgeCatalog.tiered.count == 6)
    #expect(BadgeCatalog.moments.count == 6)
    #expect(BadgeCatalog.all.count == 12)
}

@Test func catalogueIDsAreUnique() {
    let ids = BadgeCatalog.all.map(\.id)
    #expect(Set(ids).count == ids.count)
}

@Test func tieredBadgesAreTieredAndMomentsAreMoments() {
    for def in BadgeCatalog.tiered {
        if case .tiered = def.kind {} else { Issue.record("\(def.id) not tiered") }
    }
    for def in BadgeCatalog.moments {
        #expect(def.kind == .moment)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: the test command.
Expected: FAIL — `BadgeCatalog` undefined.

- [ ] **Step 3: Add `BadgeCatalog` to `Daily Music/Models/Badge.swift`**

Append to `Badge.swift`:

```swift
/// The static catalogue of every badge. IDs are stable (used as seen-keys), so
/// never rename an id once shipped.
enum BadgeCatalog {
    // Tiered — counts
    static let dailyStreak = BadgeDefinition(
        id: "streak", title: "Daily Streak", subtitle: "Days in a row",
        symbol: "🔥", tint: .orange, kind: .tiered(thresholds: [3, 7, 14, 30, 100]))
    static let mint = BadgeDefinition(
        id: "mint", title: "Mint Collector", subtitle: "Heard on its drop day",
        symbol: "💿", tint: .teal, kind: .tiered(thresholds: [5, 25, 50, 100, 250]))
    static let crate = BadgeDefinition(
        id: "crate", title: "Crate Digger", subtitle: "Songs collected",
        symbol: "🗄️", tint: .indigo, kind: .tiered(thresholds: [10, 50, 100, 250]))
    static let saved = BadgeDefinition(
        id: "saved", title: "Kept Forever", subtitle: "Songs saved",
        symbol: "❤️", tint: .pink, kind: .tiered(thresholds: [5, 25, 50, 100]))
    static let critic = BadgeDefinition(
        id: "critic", title: "Critic", subtitle: "Songs rated",
        symbol: "⚖️", tint: .yellow, kind: .tiered(thresholds: [10, 50, 100, 250]))
    static let rescuer = BadgeDefinition(
        id: "rescuer", title: "Rescuer", subtitle: "Salvaged missed drops",
        symbol: "🛟", tint: .purple, kind: .tiered(thresholds: [1, 5, 10, 25]))

    // Moments — one-time, hidden until earned
    static let firstPress = BadgeDefinition(
        id: "firstPress", title: "First Press", subtitle: "Your first mint song",
        symbol: "✨", tint: .teal, kind: .moment)
    static let perfectWeek = BadgeDefinition(
        id: "perfectWeek", title: "Perfect Week", subtitle: "7 same-day pickups in a row",
        symbol: "🗓️", tint: .orange, kind: .moment)
    static let comeback = BadgeDefinition(
        id: "comeback", title: "Comeback", subtitle: "Rebuilt a streak to a week",
        symbol: "🌱", tint: .green, kind: .moment)
    static let nightOwl = BadgeDefinition(
        id: "nightOwl", title: "Night Owl", subtitle: "Caught a drop after midnight",
        symbol: "🦉", tint: .indigo, kind: .moment)
    static let flawlessMonth = BadgeDefinition(
        id: "flawlessMonth", title: "Flawless Month", subtitle: "A month with no misses",
        symbol: "🌕", tint: .yellow, kind: .moment)
    static let revealed = BadgeDefinition(
        id: "revealed", title: "Revealed", subtitle: "Unlocked your archetype",
        symbol: "🔮", tint: .purple, kind: .moment)

    static let tiered: [BadgeDefinition] = [dailyStreak, mint, crate, saved, critic, rescuer]
    static let moments: [BadgeDefinition] = [firstPress, perfectWeek, comeback, nightOwl, flawlessMonth, revealed]
    static let all: [BadgeDefinition] = tiered + moments
}
```

- [ ] **Step 4: Run to verify pass**

Run: the test command.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/Badge.swift" "Daily MusicTests/BadgeTests.swift"
git commit -m "feat(badges): badge catalogue (6 tiered, 6 moments)"
```

---

## Task 3: BadgeInputs snapshot

**Files:**
- Create: `Daily Music/Models/BadgeInputs.swift`

- [ ] **Step 1: Create `Daily Music/Models/BadgeInputs.swift`**

```swift
//
//  BadgeInputs.swift
//  Daily Music
//
//  An immutable snapshot of everything the BadgeDeriver needs. Assembled by
//  BadgesViewModel from the live stores, then handed to the pure deriver — which
//  keeps derivation fully testable with fixtures (no stores, no async).
//

import Foundation

struct BadgeInputs {
    /// Published catalogue entries (any order); status is derived against `heardAt`.
    let entries: [DailyEntry]
    /// entry_id → earliest heard_at (from ListensStore).
    let heardAt: [UUID: Date]
    /// Saved/favourited entry ids.
    let favoriteIDs: Set<UUID>
    /// entry_id → rating (+1 / -1 / 0). Non-zero counts as "rated".
    let ratings: [UUID: Int]
    /// All daily check-in days (for streak + comeback).
    let checkInDays: Set<Date>
    /// True once a taste archetype has been locked in (snapshot.stableArchetypeID != nil).
    let hasRevealedArchetype: Bool

    var now: Date = Date()
    var calendar: Calendar = .current
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: the build command.
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Models/BadgeInputs.swift"
git commit -m "feat(badges): BadgeInputs snapshot type"
```

---

## Task 4: BadgeDeriver — tiered values

**Files:**
- Create: `Daily Music/Services/BadgeDeriver.swift`
- Test: `Daily MusicTests/BadgeTests.swift`

- [ ] **Step 1: Add failing tests for tiered derivation**

Append inside `struct BadgeTests`. These build fixtures with a fixed calendar/now:

```swift
// MARK: - Deriver fixtures

private static let cal = Calendar(identifier: .gregorian)
private static var refNow: Date {
    cal.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 12))!
}
private static func day(_ offset: Int) -> Date {
    cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: refNow))!
}
private static func entry(_ id: UUID = UUID(), daysAgo: Int, genre: String? = nil) -> DailyEntry {
    DailyEntry(
        id: id, date: day(-daysAgo), title: "T", artist: "A",
        albumArtURL: nil, journalMarkdown: "", appleMusicID: "", spotifyURI: "",
        genre: genre)
}

// MARK: - Deriver: tiered values

@Test func mintCountsSameDayListensOnly() {
    let e1 = UUID(); let e2 = UUID(); let e3 = UUID()
    let inputs = BadgeInputs(
        entries: [
            Self.entry(e1, daysAgo: 0),   // heard same day → mint
            Self.entry(e2, daysAgo: 5),   // heard late → not mint
            Self.entry(e3, daysAgo: 2),   // never heard → not mint
        ],
        heardAt: [e1: Self.day(0), e2: Self.day(0)], // e2 heard today, 5 days late
        favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
        now: Self.refNow, calendar: Self.cal)

    let badges = BadgeDeriver().deriveAll(from: inputs)
    let mint = badges.first { $0.id == "mint" }!
    #expect(mint.value == 1)
}

@Test func crateCountsAllHeard() {
    let e1 = UUID(); let e2 = UUID()
    let inputs = BadgeInputs(
        entries: [], heardAt: [e1: Self.day(-1), e2: Self.day(-2)],
        favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
        now: Self.refNow, calendar: Self.cal)
    let crate = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "crate" }!
    #expect(crate.value == 2)
}

@Test func savedCountsFavorites() {
    let inputs = BadgeInputs(
        entries: [], heardAt: [:], favoriteIDs: [UUID(), UUID(), UUID()],
        ratings: [:], checkInDays: [], hasRevealedArchetype: false,
        now: Self.refNow, calendar: Self.cal)
    let saved = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "saved" }!
    #expect(saved.value == 3)
}

@Test func criticCountsNonZeroRatings() {
    let inputs = BadgeInputs(
        entries: [], heardAt: [:], favoriteIDs: [],
        ratings: [UUID(): 1, UUID(): -1, UUID(): 0],
        checkInDays: [], hasRevealedArchetype: false,
        now: Self.refNow, calendar: Self.cal)
    let critic = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "critic" }!
    #expect(critic.value == 2)
}

@Test func rescuerCountsRescuedListens() {
    let e1 = UUID()
    // Drop 40 days ago, heard today → past the catch-up window → .rescued
    let inputs = BadgeInputs(
        entries: [Self.entry(e1, daysAgo: 40)],
        heardAt: [e1: Self.day(0)],
        favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
        now: Self.refNow, calendar: Self.cal)
    let rescuer = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "rescuer" }!
    #expect(rescuer.value == 1)
}

@Test func streakUsesBestRun() {
    let inputs = BadgeInputs(
        entries: [], heardAt: [:], favoriteIDs: [], ratings: [:],
        checkInDays: [Self.day(0), Self.day(-1), Self.day(-2)],
        hasRevealedArchetype: false, now: Self.refNow, calendar: Self.cal)
    let streak = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "streak" }!
    #expect(streak.value == 3)
    #expect(streak.tier?.unlockedTier == 1) // met threshold 3
}

@Test func tieredBadgeCarriesTierProgress() {
    let inputs = BadgeInputs(
        entries: [], heardAt: [:], favoriteIDs: Set((0..<6).map { _ in UUID() }),
        ratings: [:], checkInDays: [], hasRevealedArchetype: false,
        now: Self.refNow, calendar: Self.cal)
    let saved = BadgeDeriver().deriveAll(from: inputs).first { $0.id == "saved" }!
    #expect(saved.value == 6)
    #expect(saved.tier?.unlockedTier == 1)        // met 5
    #expect(saved.tier?.nextThreshold == 25)
    #expect(saved.isEarned)
}
```

- [ ] **Step 2: Run to verify failure**

Run: the test command.
Expected: FAIL — `BadgeDeriver` undefined.

- [ ] **Step 3: Create `Daily Music/Services/BadgeDeriver.swift` (tiered only for now)**

```swift
//
//  BadgeDeriver.swift
//  Daily Music
//
//  Pure derivation: BadgeInputs → [EarnedBadge]. No stores, no async, no UI —
//  every value comes from the snapshot, so the whole thing is unit-testable with
//  fixtures. The view model assembles the inputs; this just does the math.
//

import Foundation

struct BadgeDeriver {

    func deriveAll(from inputs: BadgeInputs) -> [EarnedBadge] {
        BadgeCatalog.tiered.map { tiered($0, inputs) }
            + BadgeCatalog.moments.map { moment($0, inputs) }
    }

    // MARK: - Tiered

    private func tiered(_ def: BadgeDefinition, _ i: BadgeInputs) -> EarnedBadge {
        guard case .tiered(let thresholds) = def.kind else {
            return EarnedBadge(definition: def, value: 0, isEarned: false, tier: nil)
        }
        let value = tieredValue(def.id, i)
        let progress = BadgeMath.tierProgress(value: value, thresholds: thresholds)
        return EarnedBadge(definition: def, value: value, isEarned: progress.isEarned, tier: progress)
    }

    private func tieredValue(_ id: String, _ i: BadgeInputs) -> Int {
        switch id {
        case "streak":
            return Streak.compute(from: i.checkInDays, calendar: i.calendar, asOf: i.now).best
        case "mint":
            return i.entries.filter { status($0, i) == .heardSameDay }.count
        case "crate":
            return i.heardAt.count
        case "saved":
            return i.favoriteIDs.count
        case "critic":
            return i.ratings.values.filter { $0 != 0 }.count
        case "rescuer":
            return i.entries.filter { status($0, i) == .rescued }.count
        default:
            return 0
        }
    }

    // MARK: - Moments (stub until Task 5)

    private func moment(_ def: BadgeDefinition, _ i: BadgeInputs) -> EarnedBadge {
        EarnedBadge(definition: def, value: 0, isEarned: false, tier: nil)
    }

    // MARK: - Helpers

    private func status(_ entry: DailyEntry, _ i: BadgeInputs) -> ListenStatus {
        ListenStatus.of(
            entryDate: entry.date, heardAt: i.heardAt[entry.id],
            calendar: i.calendar, asOf: i.now)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: the test command.
Expected: PASS (all tiered tests).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/BadgeDeriver.swift" "Daily MusicTests/BadgeTests.swift"
git commit -m "feat(badges): derive tiered badge values"
```

---

## Task 5: BadgeDeriver — moment predicates

**Files:**
- Modify: `Daily Music/Services/BadgeDeriver.swift`
- Test: `Daily MusicTests/BadgeTests.swift`

- [ ] **Step 1: Add failing tests for moment predicates**

Append inside `struct BadgeTests`:

```swift
// MARK: - Deriver: moments

private static func mintInputs(daysAgo: [Int], checkIns: Set<Date> = [], reveal: Bool = false,
                               heardOverride: [Int: Int] = [:]) -> BadgeInputs {
    // Each entry dropped `daysAgo` is heard same-day unless overridden via
    // heardOverride[daysAgo] = listenDaysAgo.
    var entries: [DailyEntry] = []
    var heardAt: [UUID: Date] = [:]
    for d in daysAgo {
        let id = UUID()
        entries.append(BadgeTests.entry(id, daysAgo: d))
        let listen = heardOverride[d] ?? d
        heardAt[id] = BadgeTests.day(-listen)
    }
    return BadgeInputs(
        entries: entries, heardAt: heardAt, favoriteIDs: [], ratings: [:],
        checkInDays: checkIns, hasRevealedArchetype: reveal,
        now: BadgeTests.refNow, calendar: BadgeTests.cal)
}

@Test func firstPressEarnedWithOneMint() {
    let badges = BadgeDeriver().deriveAll(from: Self.mintInputs(daysAgo: [1]))
    #expect(badges.first { $0.id == "firstPress" }!.isEarned)
}

@Test func firstPressNotEarnedWithNoMint() {
    let badges = BadgeDeriver().deriveAll(from: Self.mintInputs(daysAgo: []))
    #expect(!(badges.first { $0.id == "firstPress" }!.isEarned))
}

@Test func perfectWeekNeedsSevenConsecutiveSameDay() {
    let seven = BadgeDeriver().deriveAll(from: Self.mintInputs(daysAgo: Array(0...6)))
    #expect(seven.first { $0.id == "perfectWeek" }!.isEarned)

    let six = BadgeDeriver().deriveAll(from: Self.mintInputs(daysAgo: Array(0...5)))
    #expect(!(six.first { $0.id == "perfectWeek" }!.isEarned))
}

@Test func perfectWeekBrokenByAGap() {
    // 0,1,2,3,4,5 then skip 6, then 7 → longest run of mint days is 6, not 7
    let badges = BadgeDeriver().deriveAll(from: Self.mintInputs(daysAgo: [0,1,2,3,4,5,7]))
    #expect(!(badges.first { $0.id == "perfectWeek" }!.isEarned))
}

@Test func comebackNeedsAWeekRunAfterAnEarlierBreak() {
    // Earlier short run (days -20,-19), gap, then a fresh 7-day run ending today.
    let recent = (0...6).map { Self.day(-$0) }
    let earlier = [Self.day(-20), Self.day(-19)]
    let inputs = BadgeInputs(
        entries: [], heardAt: [:], favoriteIDs: [], ratings: [:],
        checkInDays: Set(recent + earlier), hasRevealedArchetype: false,
        now: Self.refNow, calendar: Self.cal)
    #expect(BadgeDeriver().deriveAll(from: inputs).first { $0.id == "comeback" }!.isEarned)
}

@Test func comebackNotEarnedForAFirstUnbrokenRun() {
    let inputs = BadgeInputs(
        entries: [], heardAt: [:], favoriteIDs: [], ratings: [:],
        checkInDays: Set((0...9).map { Self.day(-$0) }), // one long first run, no earlier break
        hasRevealedArchetype: false, now: Self.refNow, calendar: Self.cal)
    #expect(!(BadgeDeriver().deriveAll(from: inputs).first { $0.id == "comeback" }!.isEarned))
}

@Test func nightOwlEarnedForAfterMidnightListen() {
    let e = UUID()
    let lateNight = Self.cal.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 1))!
    let inputs = BadgeInputs(
        entries: [Self.entry(e, daysAgo: 6)], heardAt: [e: lateNight],
        favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
        now: Self.refNow, calendar: Self.cal)
    #expect(BadgeDeriver().deriveAll(from: inputs).first { $0.id == "nightOwl" }!.isEarned)
}

@Test func flawlessMonthEarnedWhenAPastMonthHasNoMisses() {
    // May 2026: two drops, both heard same day → no misses in a completed month.
    let e1 = UUID(); let e2 = UUID()
    let may1 = Self.cal.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 12))!
    let may2 = Self.cal.date(from: DateComponents(year: 2026, month: 5, day: 18, hour: 12))!
    let mkEntry: (UUID, Date) -> DailyEntry = { id, d in
        DailyEntry(id: id, date: d, title: "T", artist: "A", albumArtURL: nil,
                   journalMarkdown: "", appleMusicID: "", spotifyURI: "")
    }
    let inputs = BadgeInputs(
        entries: [mkEntry(e1, may1), mkEntry(e2, may2)],
        heardAt: [e1: may1, e2: may2],
        favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
        now: Self.refNow, calendar: Self.cal)
    #expect(BadgeDeriver().deriveAll(from: inputs).first { $0.id == "flawlessMonth" }!.isEarned)
}

@Test func flawlessMonthNotEarnedWithAMiss() {
    let e1 = UUID(); let e2 = UUID()
    let may1 = Self.cal.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 12))!
    let may2 = Self.cal.date(from: DateComponents(year: 2026, month: 5, day: 18, hour: 12))!
    let mkEntry: (UUID, Date) -> DailyEntry = { id, d in
        DailyEntry(id: id, date: d, title: "T", artist: "A", albumArtURL: nil,
                   journalMarkdown: "", appleMusicID: "", spotifyURI: "")
    }
    let inputs = BadgeInputs(
        entries: [mkEntry(e1, may1), mkEntry(e2, may2)],
        heardAt: [e1: may1], // e2 never heard → missed
        favoriteIDs: [], ratings: [:], checkInDays: [], hasRevealedArchetype: false,
        now: Self.refNow, calendar: Self.cal)
    #expect(!(BadgeDeriver().deriveAll(from: inputs).first { $0.id == "flawlessMonth" }!.isEarned))
}

@Test func revealedTracksFlag() {
    let on = Self.mintInputs(daysAgo: [], reveal: true)
    #expect(BadgeDeriver().deriveAll(from: on).first { $0.id == "revealed" }!.isEarned)
    let off = Self.mintInputs(daysAgo: [], reveal: false)
    #expect(!(BadgeDeriver().deriveAll(from: off).first { $0.id == "revealed" }!.isEarned))
}
```

- [ ] **Step 2: Run to verify failure**

Run: the test command.
Expected: FAIL — moments still stubbed to `isEarned: false`.

- [ ] **Step 3: Replace the moment stub in `BadgeDeriver.swift`**

Replace the `// MARK: - Moments (stub until Task 5)` section with:

```swift
    // MARK: - Moments

    private func moment(_ def: BadgeDefinition, _ i: BadgeInputs) -> EarnedBadge {
        let earned = isMomentEarned(def.id, i)
        return EarnedBadge(definition: def, value: earned ? 1 : 0, isEarned: earned, tier: nil)
    }

    private func isMomentEarned(_ id: String, _ i: BadgeInputs) -> Bool {
        switch id {
        case "firstPress":
            return i.entries.contains { status($0, i) == .heardSameDay }
        case "perfectWeek":
            return longestSameDayRun(i) >= 7
        case "comeback":
            return hasComeback(i)
        case "nightOwl":
            return i.heardAt.values.contains { i.calendar.component(.hour, from: $0) < 5 }
        case "flawlessMonth":
            return hasFlawlessMonth(i)
        case "revealed":
            return i.hasRevealedArchetype
        default:
            return false
        }
    }

    /// Longest run of consecutive calendar days where each day's drop was heard
    /// same-day. Built from the set of same-day drop-days.
    private func longestSameDayRun(_ i: BadgeInputs) -> Int {
        let mintDays = Set(
            i.entries
                .filter { status($0, i) == .heardSameDay }
                .map { i.calendar.startOfDay(for: $0.date) })
        return longestConsecutiveRun(of: mintDays, calendar: i.calendar)
    }

    /// True if a run of ≥7 consecutive check-in days exists that is NOT the first
    /// run — i.e. the streak broke and was rebuilt to a week.
    private func hasComeback(_ i: BadgeInputs) -> Bool {
        let runs = consecutiveRuns(of: i.checkInDays, calendar: i.calendar)
        guard runs.count >= 2 else { return false }
        return runs.dropFirst().contains { $0 >= 7 }
    }

    /// True if any completed month (strictly before the current month) had at least
    /// one drop and none of its drops were missed.
    private func hasFlawlessMonth(_ i: BadgeInputs) -> Bool {
        let currentMonth = i.calendar.dateInterval(of: .month, for: i.now)?.start
        let byMonth = Dictionary(grouping: i.entries) {
            i.calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date
        }
        for (month, entries) in byMonth {
            if let currentMonth,
               i.calendar.isDate(month, equalTo: currentMonth, toGranularity: .month) { continue }
            guard !entries.isEmpty else { continue }
            let anyMissed = entries.contains { status($0, i) == .missed }
            if !anyMissed { return true }
        }
        return false
    }

    // MARK: - Run helpers (consecutive calendar days)

    private func longestConsecutiveRun(of days: Set<Date>, calendar: Calendar) -> Int {
        consecutiveRuns(of: days, calendar: calendar).max() ?? 0
    }

    /// Lengths of each maximal run of consecutive calendar days, in chronological order.
    private func consecutiveRuns(of days: Set<Date>, calendar: Calendar) -> [Int] {
        let sorted = days.map { calendar.startOfDay(for: $0) }.sorted()
        guard !sorted.isEmpty else { return [] }
        var runs: [Int] = []
        var run = 1
        for idx in 1..<sorted.count {
            let expected = calendar.date(byAdding: .day, value: 1, to: sorted[idx - 1])!
            if calendar.isDate(sorted[idx], inSameDayAs: expected) {
                run += 1
            } else {
                runs.append(run)
                run = 1
            }
        }
        runs.append(run)
        return runs
    }
```

- [ ] **Step 4: Run to verify pass**

Run: the test command.
Expected: PASS (all moment tests).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/BadgeDeriver.swift" "Daily MusicTests/BadgeTests.swift"
git commit -m "feat(badges): derive moment badges"
```

---

## Task 6: BadgeService protocol + DerivedBadgeService

**Files:**
- Create: `Daily Music/Services/BadgeService.swift`

- [ ] **Step 1: Create `Daily Music/Services/BadgeService.swift`**

```swift
//
//  BadgeService.swift
//  Daily Music
//
//  The seam. Today badges are purely derived on-device (DerivedBadgeService); the
//  protocol exists so a Supabase- or friend-profile-backed source can slot in
//  later (spec Approach C) without the view model or views changing.
//

import Foundation

protocol BadgeService {
    func badges() async -> [EarnedBadge]
}

/// Computes badges from an on-device snapshot. Holds the inputs captured by the
/// view model; the heavy lifting is in the pure BadgeDeriver.
struct DerivedBadgeService: BadgeService {
    let inputs: BadgeInputs
    private let deriver = BadgeDeriver()

    func badges() async -> [EarnedBadge] {
        deriver.deriveAll(from: inputs)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: the build command.
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Services/BadgeService.swift"
git commit -m "feat(badges): BadgeService protocol + derived implementation"
```

---

## Task 7: BadgeSeenStore

**Files:**
- Create: `Daily Music/Services/BadgeSeenStore.swift`
- Test: `Daily MusicTests/BadgeTests.swift`

- [ ] **Step 1: Add failing tests**

Append inside `struct BadgeTests`:

```swift
// MARK: - Seen store

private static func suiteDefaults() -> UserDefaults {
    let name = "badge.tests.\(UUID().uuidString)"
    return UserDefaults(suiteName: name)!
}

private static func earned(_ id: String, tier: Int?) -> EarnedBadge {
    let def = BadgeDefinition(id: id, title: id, subtitle: "", symbol: "", tint: .gray,
                              kind: tier == nil ? .moment : .tiered(thresholds: [1]))
    let progress = tier.map { TierProgress(unlockedTier: $0, nextThreshold: nil, progressToNext: 1) }
    return EarnedBadge(definition: def, value: tier ?? 1, isEarned: true, tier: progress)
}

@Test func firstLoadBaselinesWithoutCelebrating() {
    let store = BadgeSeenStore(defaults: Self.suiteDefaults())
    let newly = store.newlyEarned(in: [Self.earned("mint", tier: 2)])
    #expect(newly.isEmpty) // baseline run never celebrates pre-existing badges
}

@Test func laterEarnsAreReportedOnce() {
    let defaults = Self.suiteDefaults()
    let store = BadgeSeenStore(defaults: defaults)
    _ = store.newlyEarned(in: [Self.earned("mint", tier: 1)]) // baseline

    let newly = store.newlyEarned(in: [Self.earned("mint", tier: 1), Self.earned("crate", tier: 1)])
    #expect(newly.map(\.id) == ["crate"])

    store.markSeen(newly.map(\.seenKey))
    let after = store.newlyEarned(in: [Self.earned("mint", tier: 1), Self.earned("crate", tier: 1)])
    #expect(after.isEmpty)
}

@Test func higherTierCelebratesAgain() {
    let defaults = Self.suiteDefaults()
    let store = BadgeSeenStore(defaults: defaults)
    _ = store.newlyEarned(in: [Self.earned("mint", tier: 1)]) // baseline at tier 1

    let newly = store.newlyEarned(in: [Self.earned("mint", tier: 2)]) // climbed a tier
    #expect(newly.map(\.id) == ["mint"])
}
```

- [ ] **Step 2: Run to verify failure**

Run: the test command.
Expected: FAIL — `BadgeSeenStore` undefined.

- [ ] **Step 3: Create `Daily Music/Services/BadgeSeenStore.swift`**

```swift
//
//  BadgeSeenStore.swift
//  Daily Music
//
//  Tracks which badge tiers have already been celebrated, so an earn moment shows
//  exactly once. Mirrors ArchetypeSnapshotStore's UserDefaults pattern. Crucially,
//  nothing about whether a badge is *earned* depends on this — it only gates the
//  celebration. On the very first run it baselines (records all current earns
//  silently) so a user with existing history isn't spammed.
//

import Foundation

final class BadgeSeenStore {
    private let defaults: UserDefaults
    private static let seenKey = "badges.seenKeys"
    private static let baselinedKey = "badges.baselined"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func seenKeys() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.seenKey) ?? [])
    }

    func markSeen(_ keys: [String]) {
        var set = seenKeys()
        keys.forEach { set.insert($0) }
        defaults.set(Array(set), forKey: Self.seenKey)
    }

    /// Earned badges not yet celebrated. The first call ever baselines silently.
    func newlyEarned(in badges: [EarnedBadge]) -> [EarnedBadge] {
        let earned = badges.filter { $0.isEarned }

        guard defaults.bool(forKey: Self.baselinedKey) else {
            markSeen(earned.map(\.seenKey))
            defaults.set(true, forKey: Self.baselinedKey)
            return []
        }

        let seen = seenKeys()
        return earned.filter { !seen.contains($0.seenKey) }
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: the test command.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/BadgeSeenStore.swift" "Daily MusicTests/BadgeTests.swift"
git commit -m "feat(badges): BadgeSeenStore with first-run baseline"
```

---

## Task 8: BadgesViewModel (summary building)

**Files:**
- Create: `Daily Music/ViewModels/BadgesViewModel.swift`
- Test: `Daily MusicTests/BadgeTests.swift`

- [ ] **Step 1: Add failing tests for the pure summary builder**

Append inside `struct BadgeTests`:

```swift
// MARK: - Summary

@Test func summaryCountsEarnedAndClose() {
    let badges: [EarnedBadge] = [
        Self.tieredFixture("mint", value: 50, thresholds: [5, 25, 50, 100]),   // earned, mid
        Self.tieredFixture("saved", value: 4, thresholds: [5, 25]),            // not earned, close (4/5)
        Self.tieredFixture("crate", value: 1, thresholds: [10, 50]),           // not earned, far
    ]
    let summary = BadgesViewModel.makeSummary(badges)
    #expect(summary.earnedCount == 1)
    #expect(summary.closeCount == 1) // only "saved" is ≥ 0.5 to next and not maxed
}

@Test func summaryNearestGoalIsHighestProgressUnmaxed() {
    let badges: [EarnedBadge] = [
        Self.tieredFixture("saved", value: 4, thresholds: [5]),     // 4/5 = 0.8
        Self.tieredFixture("crate", value: 1, thresholds: [10]),    // 0.1
        Self.tieredFixture("mint", value: 5, thresholds: [5]),      // maxed → excluded
    ]
    let summary = BadgesViewModel.makeSummary(badges)
    #expect(summary.nearestGoal?.id == "saved")
}

@Test func summaryPeekPutsEarnedFirstAndCapsAtFive() {
    let badges: [EarnedBadge] = [
        Self.tieredFixture("a", value: 0, thresholds: [5]),
        Self.tieredFixture("b", value: 5, thresholds: [5]), // earned
        Self.tieredFixture("c", value: 0, thresholds: [5]),
        Self.tieredFixture("d", value: 5, thresholds: [5]), // earned
        Self.tieredFixture("e", value: 0, thresholds: [5]),
        Self.tieredFixture("f", value: 0, thresholds: [5]),
    ]
    let peek = BadgesViewModel.makeSummary(badges).peek
    #expect(peek.count == 5)
    #expect(peek.prefix(2).map(\.id) == ["b", "d"]) // earned first, original order preserved
}

private static func tieredFixture(_ id: String, value: Int, thresholds: [Int]) -> EarnedBadge {
    let def = BadgeDefinition(id: id, title: id, subtitle: "", symbol: "", tint: .gray,
                              kind: .tiered(thresholds: thresholds))
    let p = BadgeMath.tierProgress(value: value, thresholds: thresholds)
    return EarnedBadge(definition: def, value: value, isEarned: p.isEarned, tier: p)
}
```

- [ ] **Step 2: Run to verify failure**

Run: the test command.
Expected: FAIL — `BadgesViewModel` undefined.

- [ ] **Step 3: Create `Daily Music/ViewModels/BadgesViewModel.swift`**

```swift
//
//  BadgesViewModel.swift
//  Daily Music
//
//  Drives the Insights badge UI. Assembles a BadgeInputs snapshot from the live
//  stores, runs it through a BadgeService, exposes the full list + a compact
//  summary for the Insights card, and diffs against BadgeSeenStore to surface
//  newly-earned badges to celebrate.
//

import Foundation

@MainActor
@Observable
final class BadgesViewModel {

    struct Summary: Equatable {
        let earnedCount: Int
        /// Tiered badges not yet maxed whose progress to the next tier is ≥ 0.5.
        let closeCount: Int
        /// The single tiered badge closest to its next tier (highest progress, unmaxed).
        let nearestGoal: EarnedBadge?
        /// Up to 5 representative badges, earned first, original order otherwise.
        let peek: [EarnedBadge]
    }

    private(set) var badges: [EarnedBadge] = []
    private(set) var summary: Summary?
    private(set) var newlyEarned: [EarnedBadge] = []

    private let entries: EntryService
    private let listensStore: ListensStore
    private let favoritesStore: FavoritesStore
    private let ratingsStore: RatingsStore
    private let checkIns: CheckInService
    private let snapshotStore: ArchetypeSnapshotStore
    private let seenStore: BadgeSeenStore

    init(
        entries: EntryService,
        listensStore: ListensStore,
        favoritesStore: FavoritesStore,
        ratingsStore: RatingsStore,
        checkIns: CheckInService,
        snapshotStore: ArchetypeSnapshotStore = ArchetypeSnapshotStore(),
        seenStore: BadgeSeenStore = BadgeSeenStore()
    ) {
        self.entries = entries
        self.listensStore = listensStore
        self.favoritesStore = favoritesStore
        self.ratingsStore = ratingsStore
        self.checkIns = checkIns
        self.snapshotStore = snapshotStore
        self.seenStore = seenStore
    }

    func load() async {
        let history = (try? await entries.publishedHistory()) ?? []
        let checkInDays = (try? await checkIns.checkInDates()) ?? []

        let inputs = BadgeInputs(
            entries: history,
            heardAt: listensStore.heardAt,
            favoriteIDs: favoritesStore.ids,
            ratings: ratingsStore.ratings,
            checkInDays: checkInDays,
            hasRevealedArchetype: snapshotStore.load().stableArchetypeID != nil
        )

        let service: BadgeService = DerivedBadgeService(inputs: inputs)
        let all = await service.badges()
        badges = all
        summary = Self.makeSummary(all)
        newlyEarned = seenStore.newlyEarned(in: all)
    }

    /// Mark the current celebrations as seen and clear them.
    func acknowledgeCelebrations() {
        seenStore.markSeen(newlyEarned.map(\.seenKey))
        newlyEarned = []
    }

    // MARK: - Pure summary builder

    static func makeSummary(_ badges: [EarnedBadge]) -> Summary {
        let earnedCount = badges.filter { $0.isEarned }.count

        let unmaxed = badges.filter { ($0.tier?.isMaxed == false) }
        let closeCount = unmaxed.filter { ($0.tier?.progressToNext ?? 0) >= 0.5 }.count
        let nearestGoal = unmaxed.max { ($0.tier?.progressToNext ?? 0) < ($1.tier?.progressToNext ?? 0) }

        let earned = badges.filter { $0.isEarned }
        let locked = badges.filter { !$0.isEarned }
        let peek = Array((earned + locked).prefix(5))

        return Summary(earnedCount: earnedCount, closeCount: closeCount,
                       nearestGoal: nearestGoal, peek: peek)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: the test command.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/ViewModels/BadgesViewModel.swift" "Daily MusicTests/BadgeTests.swift"
git commit -m "feat(badges): BadgesViewModel + summary builder"
```

---

## Task 9: BadgesView (full grid screen)

**Files:**
- Create: `Daily Music/Views/BadgesView.swift`

This is SwiftUI; verify by build + `#Preview`, not unit tests (the codebase has no view tests).

- [ ] **Step 1: Create `Daily Music/Views/BadgesView.swift`**

```swift
//
//  BadgesView.swift
//  Daily Music
//
//  The full badge grid: a tiered section (with progress) and a moments section
//  (earned tiles + "?" mysteries for the unearned). Tinted to the active accent.
//

import SwiftUI

struct BadgesView: View {
    let badges: [EarnedBadge]
    let accent: Color

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    private var tiered: [EarnedBadge] { badges.filter { $0.tier != nil } }
    private var moments: [EarnedBadge] { badges.filter { $0.tier == nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                section(title: "Tiered", items: tiered) { BadgeTile(badge: $0, accent: accent) }
                section(title: "Moments", items: moments) { MomentTile(badge: $0, accent: accent) }
            }
            .padding()
        }
        .navigationTitle("Badges")
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    @ViewBuilder
    private func section(title: String, items: [EarnedBadge],
                         @ViewBuilder tile: @escaping (EarnedBadge) -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { tile($0) }
            }
        }
    }
}

private struct BadgeDisc: View {
    let symbol: String
    let tint: Color
    var dimmed: Bool = false

    var body: some View {
        Text(symbol)
            .font(.system(size: 26))
            .frame(width: 58, height: 58)
            .background(
                RadialGradient(colors: [tint.opacity(0.55), tint.opacity(0.12)],
                               center: .topLeading, startRadius: 2, endRadius: 56),
                in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
            .opacity(dimmed ? 0.45 : 1)
            .saturation(dimmed ? 0 : 1)
    }
}

private struct BadgeTile: View {
    let badge: EarnedBadge
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            BadgeDisc(symbol: badge.definition.symbol, tint: badge.definition.tint,
                      dimmed: !badge.isEarned)
            Text(badge.definition.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let tier = badge.tier {
                if tier.isMaxed {
                    Text("MAX").font(.caption2.weight(.heavy)).foregroundStyle(accent)
                } else {
                    ProgressView(value: tier.progressToNext)
                        .tint(accent)
                    Text("\(badge.value) · next \(tier.nextThreshold ?? 0)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

private struct MomentTile: View {
    let badge: EarnedBadge
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            if badge.isEarned {
                BadgeDisc(symbol: badge.definition.symbol, tint: badge.definition.tint)
                Text(badge.definition.title)
                    .font(.caption.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(badge.definition.subtitle)
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).lineLimit(2)
            } else {
                BadgeDisc(symbol: "?", tint: .gray, dimmed: true)
                Text("Mystery").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text("Locked moment").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        BadgesView(badges: BadgeCatalog.all.map { def in
            let tier: TierProgress? = {
                if case .tiered(let t) = def.kind { return BadgeMath.tierProgress(value: 7, thresholds: t) }
                return nil
            }()
            return EarnedBadge(definition: def, value: 7,
                               isEarned: (tier?.isEarned ?? false) || def.id == "firstPress",
                               tier: tier)
        }, accent: .purple)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: the build command.
Expected: BUILD SUCCEEDED. (Optionally open the `#Preview` in Xcode to eyeball it.)

> Note: if `Theme.Spacing.sm` / `Theme.Radius.card` names differ, check `Daily Music/DesignSystem/Theme.swift` and match the existing tokens used in `InsightsView.swift` (e.g. `Theme.Spacing.md`, `Theme.Radius.card`).

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/BadgesView.swift"
git commit -m "feat(badges): full badge grid screen"
```

---

## Task 10: Insights summary card + navigation

**Files:**
- Modify: `Daily Music/Views/InsightsView.swift`

- [ ] **Step 1: Hold the BadgesViewModel in InsightsView**

In `InsightsView`, add a state property next to `@State private var model: InsightsViewModel?`:

```swift
    @State private var badges: BadgesViewModel?
```

- [ ] **Step 2: Build the badges view model + load it in the existing `.task`**

In the `.task(id: env.favoritesStore.ids)` block, after the `InsightsViewModel` setup, add:

```swift
            if badges == nil {
                badges = BadgesViewModel(
                    entries: env.entries,
                    listensStore: env.listensStore,
                    favoritesStore: env.favoritesStore,
                    ratingsStore: env.ratingsStore,
                    checkIns: env.checkIns
                )
            }
            await badges?.load()
```

- [ ] **Step 3: Add the summary card builder**

Add this method to `InsightsView` (near `historySummaryCard`):

```swift
    @ViewBuilder
    private func badgesSummaryCard(accent: Color) -> some View {
        if let summary = badges?.summary, let list = badges?.badges {
            NavigationLink {
                BadgesView(badges: list, accent: accent)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rosette")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(accent)
                        .frame(width: 42, height: 42)
                        .glassEffect(.regular.tint(accent.opacity(0.14)), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("YOUR BADGES")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.secondary)
                        Text("\(summary.earnedCount) earned · \(summary.closeCount) close")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.primary)
                        if let goal = summary.nearestGoal, let tier = goal.tier, let next = tier.nextThreshold {
                            Text("\(goal.definition.title) — \(max(0, next - goal.value)) to go")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: -8) {
                        ForEach(summary.peek) { badge in
                            Text(badge.isEarned ? badge.definition.symbol : "·")
                                .font(.system(size: 16))
                                .frame(width: 28, height: 28)
                                .background(.regularMaterial, in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                                .opacity(badge.isEarned ? 1 : 0.45)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
            }
            .buttonStyle(PressableCardButtonStyle())
        }
    }
```

- [ ] **Step 4: Place the card in the content stack**

In `content(_:)`, insert the card between the `TasteMirrorBoard` and `historySummaryCard(accent:)`:

```swift
                TasteMirrorBoard(
                    mirror: mirror,
                    displayArchetype: mirror.archetype,
                    onRatingChanged: { Task { await model?.load(favoriteIDs: env.favoritesStore.ids, startingRead: startingRead) } },
                    onReplay: mirror.isArchetypeUnlocked ? { model?.replayReveal() } : nil,
                    revealCountdownText: countdownText(for: mirror)
                )
                badgesSummaryCard(accent: accent)
                historySummaryCard(accent: accent)
```

- [ ] **Step 5: Build to verify it compiles and the card appears**

Run: the build command.
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Views/InsightsView.swift"
git commit -m "feat(badges): Insights summary card + link to grid"
```

---

## Task 11: Earn celebration

**Files:**
- Create: `Daily Music/Views/Components/BadgeCelebrationCard.swift`
- Modify: `Daily Music/Views/InsightsView.swift`

- [ ] **Step 1: Create `Daily Music/Views/Components/BadgeCelebrationCard.swift`**

```swift
//
//  BadgeCelebrationCard.swift
//  Daily Music
//
//  Lightweight earn moment: a card that slides up when a badge is newly earned.
//  Tap or "Nice" to dismiss (which marks it seen). One card at a time — if several
//  were earned at once, it shows the first and the rest stay flagged for next open.
//

import SwiftUI

struct BadgeCelebrationCard: View {
    let badge: EarnedBadge
    let accent: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(badge.definition.symbol)
                .font(.system(size: 44))
                .frame(width: 84, height: 84)
                .background(
                    RadialGradient(colors: [badge.definition.tint.opacity(0.6), badge.definition.tint.opacity(0.15)],
                                   center: .topLeading, startRadius: 2, endRadius: 80),
                    in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))

            VStack(spacing: 4) {
                Text("Badge earned")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
                Text(badge.definition.title)
                    .font(.title3.weight(.heavy))
                Text(tierLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Nice") { onDismiss() }
                .buttonStyle(PrimaryActionButtonStyle(tint: accent))
        }
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .padding(Theme.Spacing.lg)
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
    }

    private var tierLine: String {
        if let tier = badge.tier {
            return "Tier \(tier.unlockedTier) · \(badge.value)"
        }
        return badge.definition.subtitle
    }
}
```

- [ ] **Step 2: Present it from InsightsView when a badge is newly earned**

In `InsightsView.body`, add an overlay on the `NavigationStack`'s content (alongside the existing `.fullScreenCover` modifiers). Add this computed binding/property and overlay:

```swift
    private var celebrating: EarnedBadge? { badges?.newlyEarned.first }
```

Then attach to the `Group { ... }` inside `NavigationStack` (after `.background(wash)`):

```swift
            .overlay {
                if let badge = celebrating {
                    Color.black.opacity(0.45).ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { dismissCelebration() }
                    BadgeCelebrationCard(
                        badge: badge,
                        accent: (badge.definition.tint),
                        onDismiss: { dismissCelebration() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: celebrating)
```

Add the dismiss helper to `InsightsView`:

```swift
    private func dismissCelebration() {
        badges?.acknowledgeCelebrations()
        Haptics.success()
    }
```

> Note: confirm `Haptics.success()` exists in `Daily Music/DesignSystem/Haptics.swift`; if the success variant is named differently (e.g. `Haptics.tap()`), use the available one.

- [ ] **Step 3: Build to verify it compiles**

Run: the build command.
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/Components/BadgeCelebrationCard.swift" "Daily Music/Views/InsightsView.swift"
git commit -m "feat(badges): lightweight earn celebration on Insights"
```

---

## Task 12: Full verification + architecture doc

**Files:**
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Run the full badge test suite**

Run: the test command.
Expected: PASS (all suites green).

- [ ] **Step 2: Run a full build**

Run: the build command.
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual smoke check (simulator or device)**

Launch the app, open the **Insights** tab. Verify:
- The "YOUR BADGES" card appears between the taste mirror and history card with a count, a goal line, and a peek strip.
- Tapping it opens the full grid: tiered badges show progress; unearned moments render as "?".
- (Optional) Force a celebration by deleting the `badges.baselined` / `badges.seenKeys` defaults keys and re-opening Insights with at least one earned badge.

- [ ] **Step 4: Update `docs/ARCHITECTURE.md`**

Add a short Insights-badges subsection under the Insights feature drill-down: the new files (`Badge`, `BadgeInputs`, `BadgeDeriver`, `BadgeService`, `BadgeSeenStore`, `BadgesViewModel`, `BadgesView`, `BadgeCelebrationCard`) and the data-flow line: *stores → BadgeInputs → BadgeDeriver → EarnedBadge → BadgesViewModel → Insights card / BadgesView*. Note the `BadgeService` seam reserved for a future Supabase/friend source.

- [ ] **Step 5: Commit**

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs(architecture): add Insights badges system"
```

---

## Notes for the implementer

- **DailyEntry initializer:** tests construct `DailyEntry(id:date:title:artist:albumArtURL:journalMarkdown:appleMusicID:spotifyURI:genre:…)`. Confirm the exact memberwise signature in `Daily Music/Models/DailyEntry.swift` and adjust fixture calls if a parameter is required/ordered differently.
- **Catch-up window:** `.rescued` vs `.caughtUp` depends on `CatchUp.windowDays`. The Rescuer/Flawless tests assume a drop heard 40 days late is `.rescued`; if `windowDays` is unusually large, bump the fixture offset past the window.
- **Theme tokens:** match the spacing/radius names already used in `InsightsView.swift` rather than inventing new ones.
- **Do not rename badge `id`s** once shipped — they're persisted as seen-keys.
```
