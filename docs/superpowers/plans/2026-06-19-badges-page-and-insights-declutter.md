# Badges Page & Insights Declutter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface recently-earned badges prominently on Insights with a dedicated full Badges page, hide unearned "moment" badges until earned, and make the earn celebration fire app-wide the instant a badge is earned — while decluttering Insights into a clear visual hierarchy.

**Architecture:** Promote the badge engine from a view-local `BadgesViewModel` (only alive on the Insights tab) to a shared `@MainActor @Observable BadgeCenter` held by `AppEnvironment`. `MainTabView` drives `BadgeCenter.refresh()` off the live stores and hosts the celebration overlay over the whole tab bar. A new `BadgeEarnLog` records earn timestamps so the Insights shelf and Badges page can order by recency.

**Tech Stack:** SwiftUI, Swift `@Observable`, UserDefaults-backed stores, Swift Testing (`import Testing`, `@Test`, `#expect`).

**Conventions for this codebase:**
- Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`
- Test: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/BadgeTests"`
- The **app target** uses an Xcode-16 file-system-synchronized group: new `.swift` files placed under `Daily Music/` compile automatically — no `project.pbxproj` edit needed.
- The **test target** is NOT synchronized: all new tests in this plan go into the **existing** `Daily MusicTests/BadgeTests.swift` (already registered) so no `project.pbxproj` edit is needed.

---

## File Structure

**Create:**
- `Daily Music/Services/BadgeEarnLog.swift` — UserDefaults persistence of badge `seenKey` → first-earned `Date`. Pure storage; no derivation.
- `Daily Music/ViewModels/BadgeCenter.swift` — app-level `@Observable` source of badge truth: derives badges, builds the summary, orders `recent` by earn time, computes `currentStreak`, and owns the newly-earned celebration queue.

**Modify:**
- `Daily Music/App/AppEnvironment.swift` — add a `badgeCenter` stored property, constructed in `init`.
- `Daily Music/Views/MainTabView.swift` — host the app-wide celebration overlay and drive `BadgeCenter.refresh()`.
- `Daily Music/Views/InsightsView.swift` — read `env.badgeCenter`; replace the dense badges card with a recent-badges shelf; demote History + Taste Arc to lighter rows; remove the tab-local celebration and view model.
- `Daily Music/Views/BadgesView.swift` — new signature + layout: hero (earned + streak), "In Progress" tiered grid, "Moments · Unlocked" (earned-only), secret-hint footer.
- `Daily MusicTests/BadgeTests.swift` — repoint summary tests to `BadgeCenter.makeSummary`; add earn-log + recency tests.

**Delete:**
- `Daily Music/ViewModels/BadgesViewModel.swift` — responsibilities move into `BadgeCenter`.

---

## Task 1: BadgeEarnLog (earn-timestamp persistence)

**Files:**
- Create: `Daily Music/Services/BadgeEarnLog.swift`
- Test: `Daily MusicTests/BadgeTests.swift` (append to existing file)

- [ ] **Step 1: Write the failing tests**

Append this section to `Daily MusicTests/BadgeTests.swift`, just before the final closing `}` of `struct BadgeTests`. It reuses the existing `Self.suiteDefaults()`, `Self.earned(_:tier:)`, `Self.cal`, and `Self.tieredFixture(_:value:thresholds:)` helpers already defined in that file.

```swift
    // MARK: - Earn log

    @Test func earnLogBaselinesAllCurrentEarnsAtOneTimestamp() {
        let log = BadgeEarnLog(defaults: Self.suiteDefaults())
        let t0 = Self.cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        log.record([Self.earned("mint", tier: 1), Self.earned("crate", tier: 1)], now: t0)
        let dates = log.dates()
        #expect(dates[Self.earned("mint", tier: 1).seenKey] == t0)
        #expect(dates[Self.earned("crate", tier: 1).seenKey] == t0)
    }

    @Test func earnLogStampsLaterEarnsWithTheirOwnTime() {
        let log = BadgeEarnLog(defaults: Self.suiteDefaults())
        let t0 = Self.cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        log.record([Self.earned("mint", tier: 1)], now: t0) // baseline
        let t1 = Self.cal.date(from: DateComponents(year: 2026, month: 6, day: 5))!
        log.record([Self.earned("mint", tier: 1), Self.earned("crate", tier: 1)], now: t1)
        let dates = log.dates()
        #expect(dates[Self.earned("mint", tier: 1).seenKey] == t0)  // unchanged
        #expect(dates[Self.earned("crate", tier: 1).seenKey] == t1) // newly earned
    }

    @Test func earnLogTierUpRecordsAFreshKey() {
        let log = BadgeEarnLog(defaults: Self.suiteDefaults())
        let t0 = Self.cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        log.record([Self.earned("mint", tier: 1)], now: t0) // baseline at tier 1
        let t1 = Self.cal.date(from: DateComponents(year: 2026, month: 6, day: 5))!
        log.record([Self.earned("mint", tier: 2)], now: t1) // climbed to tier 2
        // The tier-2 seenKey is distinct from tier-1's and gets the new timestamp.
        #expect(log.dates()[Self.earned("mint", tier: 2).seenKey] == t1)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/BadgeTests"`
Expected: FAIL — compile error "cannot find 'BadgeEarnLog' in scope".

- [ ] **Step 3: Write the implementation**

Create `Daily Music/Services/BadgeEarnLog.swift`:

```swift
//
//  BadgeEarnLog.swift
//  Daily Music
//
//  Persists WHEN each badge tier was first earned, so the Insights shelf and the
//  Badges page can show "recently earned" order. Keyed by EarnedBadge.seenKey, so
//  climbing a tier records a fresh timestamp and jumps to the front. Independent of
//  BadgeSeenStore: seen-state gates the celebration, this only orders. The very
//  first call baselines every current earn at one timestamp (so a user with history
//  isn't given a fake recency order spread across days).
//

import Foundation

final class BadgeEarnLog {
    private let defaults: UserDefaults
    private static let datesKey = "badges.earnLog.dates"
    private static let baselinedKey = "badges.earnLog.baselined"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// seenKey → first-earned date.
    func dates() -> [String: Date] {
        let raw = defaults.dictionary(forKey: Self.datesKey) as? [String: Double] ?? [:]
        return raw.mapValues { Date(timeIntervalSinceReferenceDate: $0) }
    }

    /// Record any earned tiers not yet stamped. The first call ever baselines every
    /// current earn at `now`; later calls stamp only seenKeys not seen before.
    func record(_ badges: [EarnedBadge], now: Date = Date()) {
        var raw = defaults.dictionary(forKey: Self.datesKey) as? [String: Double] ?? [:]
        let earnedKeys = badges.filter { $0.isEarned }.map(\.seenKey)
        let stamp = now.timeIntervalSinceReferenceDate

        let baselined = defaults.bool(forKey: Self.baselinedKey)
        var changed = false
        for key in earnedKeys where raw[key] == nil {
            raw[key] = stamp
            changed = true
        }
        if changed { defaults.set(raw, forKey: Self.datesKey) }
        if !baselined { defaults.set(true, forKey: Self.baselinedKey) }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/BadgeTests"`
Expected: PASS (all BadgeTests green, including the 3 new earn-log tests).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/BadgeEarnLog.swift" "Daily MusicTests/BadgeTests.swift"
git commit -m "feat: add BadgeEarnLog for recently-earned ordering"
```

---

## Task 2: BadgeCenter (app-level badge source of truth)

**Files:**
- Create: `Daily Music/ViewModels/BadgeCenter.swift`
- Test: `Daily MusicTests/BadgeTests.swift` (repoint 3 summary tests; add recency tests)

- [ ] **Step 1: Write the failing tests**

In `Daily MusicTests/BadgeTests.swift`, change the three existing summary tests to call `BadgeCenter.makeSummary` instead of `BadgesViewModel.makeSummary`:

- Line ~362: `let summary = BadgesViewModel.makeSummary(badges)` → `let summary = BadgeCenter.makeSummary(badges)`
- Line ~373: `let summary = BadgesViewModel.makeSummary(badges)` → `let summary = BadgeCenter.makeSummary(badges)`
- Line ~386: `let peek = BadgesViewModel.makeSummary(badges).peek` → `let peek = BadgeCenter.makeSummary(badges).peek`

Then append this section just before the final closing `}` of `struct BadgeTests`:

```swift
    // MARK: - Recency ordering

    @Test func recencyOrdersNewestFirstWithCatalogTieBreak() {
        let mint = Self.earned("mint", tier: 1)
        let crate = Self.earned("crate", tier: 1)
        let saved = Self.earned("saved", tier: 1)
        let day = { (d: Int) in Self.cal.date(from: DateComponents(year: 2026, month: 6, day: d))! }
        let dates = [mint.seenKey: day(1), crate.seenKey: day(1), saved.seenKey: day(9)]
        // Input is in catalog order (mint, crate, saved); saved is newest, mint/crate tie.
        let ordered = BadgeCenter.sortedByRecency([mint, crate, saved], dates: dates)
        #expect(ordered.map(\.id) == ["saved", "mint", "crate"])
    }

    @Test func recencyExcludesUnearned() {
        let mint = Self.earned("mint", tier: 1)
        let lockedCrate = Self.tieredFixture("crate", value: 0, thresholds: [10]) // not earned
        let ordered = BadgeCenter.sortedByRecency([mint, lockedCrate], dates: [mint.seenKey: Date()])
        #expect(ordered.map(\.id) == ["mint"])
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/BadgeTests"`
Expected: FAIL — compile error "cannot find 'BadgeCenter' in scope".

- [ ] **Step 3: Write the implementation**

Create `Daily Music/ViewModels/BadgeCenter.swift`. The `makeSummary` body is copied verbatim from the current `BadgesViewModel.makeSummary` (do not change its logic — the summary tests pin it).

```swift
//
//  BadgeCenter.swift
//  Daily Music
//
//  The app-wide source of badge truth. Promoted out of the Insights tab so the
//  earn celebration can fire over any screen the instant a badge is earned, and so
//  the Insights shelf and the full Badges page read one consistent list. Assembles
//  a BadgeInputs snapshot from the live stores, runs it through a BadgeService,
//  records earn timestamps (BadgeEarnLog) for recency, and diffs against
//  BadgeSeenStore to surface newly-earned badges to celebrate.
//

import Foundation

@MainActor
@Observable
final class BadgeCenter {

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
    /// Earned badges, newest-earned first — drives the Insights shelf.
    private(set) var recent: [EarnedBadge] = []
    /// The live daily-ritual streak (current run), for the Badges page hero.
    private(set) var currentStreak: Int = 0
    private(set) var newlyEarned: [EarnedBadge] = []

    /// Head of the celebration queue; nil when nothing is waiting to be celebrated.
    var celebrating: EarnedBadge? { newlyEarned.first }

    private let entries: EntryService
    private let listensStore: ListensStore
    private let favoritesStore: FavoritesStore
    private let ratingsStore: RatingsStore
    private let checkIns: CheckInService
    private let snapshotStore: ArchetypeSnapshotStore
    private let seenStore: BadgeSeenStore
    private let earnLog: BadgeEarnLog

    init(
        entries: EntryService,
        listensStore: ListensStore,
        favoritesStore: FavoritesStore,
        ratingsStore: RatingsStore,
        checkIns: CheckInService,
        snapshotStore: ArchetypeSnapshotStore = ArchetypeSnapshotStore(),
        seenStore: BadgeSeenStore = BadgeSeenStore(),
        earnLog: BadgeEarnLog = BadgeEarnLog()
    ) {
        self.entries = entries
        self.listensStore = listensStore
        self.favoritesStore = favoritesStore
        self.ratingsStore = ratingsStore
        self.checkIns = checkIns
        self.snapshotStore = snapshotStore
        self.seenStore = seenStore
        self.earnLog = earnLog
    }

    /// Re-derive badges from the live stores and recompute the shelf + celebration
    /// queue. Cheap and idempotent — safe to call after any badge-earning action.
    func refresh() async {
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

        earnLog.record(all)
        badges = all
        summary = Self.makeSummary(all)
        recent = Self.sortedByRecency(all, dates: earnLog.dates())
        currentStreak = Streak.compute(from: checkInDays).current
        newlyEarned = seenStore.newlyEarned(in: all)
    }

    /// Dismiss the currently-shown celebration: mark just that badge seen and drop
    /// it, so the next newly-earned badge (if any) surfaces next.
    func acknowledgeCelebration() {
        guard let shown = newlyEarned.first else { return }
        seenStore.markSeen([shown.seenKey])
        newlyEarned.removeFirst()
    }

    // MARK: - Pure builders

    nonisolated static func makeSummary(_ badges: [EarnedBadge]) -> Summary {
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

    /// Earned badges ordered newest-first by their earn timestamp; ties (e.g. the
    /// first-run baseline) fall back to catalog order via the input ordering.
    nonisolated static func sortedByRecency(_ badges: [EarnedBadge], dates: [String: Date]) -> [EarnedBadge] {
        badges
            .enumerated()
            .filter { $0.element.isEarned }
            .sorted { a, b in
                let da = dates[a.element.seenKey]
                let db = dates[b.element.seenKey]
                switch (da, db) {
                case let (x?, y?): return x == y ? a.offset < b.offset : x > y
                case (_?, nil):    return true
                case (nil, _?):    return false
                case (nil, nil):   return a.offset < b.offset
                }
            }
            .map(\.element)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/BadgeTests"`
Expected: PASS — all BadgeTests green (summary tests now via `BadgeCenter`, 2 new recency tests pass). `BadgesViewModel` still exists and compiles; it's just no longer referenced by tests.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/ViewModels/BadgeCenter.swift" "Daily MusicTests/BadgeTests.swift"
git commit -m "feat: add BadgeCenter as app-level badge source of truth"
```

---

## Task 3: Wire BadgeCenter into AppEnvironment

**Files:**
- Modify: `Daily Music/App/AppEnvironment.swift`

- [ ] **Step 1: Add the stored property**

In `Daily Music/App/AppEnvironment.swift`, after the `friendNudgeStore` stored property (around line 47), add:

```swift
    let badgeCenter: BadgeCenter
```

- [ ] **Step 2: Construct it in init**

In `init(...)`, after the line `self.friendNudgeStore = FriendNudgeStore(service: friendNudges)` (around line 125, the last assignment), add:

```swift
        // App-wide badge truth: built from the stores above so the earn celebration
        // can fire over any screen, not just the Insights tab.
        self.badgeCenter = BadgeCenter(
            entries: entries,
            listensStore: self.listensStore,
            favoritesStore: self.favoritesStore,
            ratingsStore: self.ratingsStore,
            checkIns: checkIns
        )
```

(Both `mock()` and `live()` route through this `init`, so no factory changes are needed.)

- [ ] **Step 3: Build to verify it compiles**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`
Expected: BUILD SUCCEEDED (the new property is unused for now — fine).

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/App/AppEnvironment.swift"
git commit -m "feat: hold BadgeCenter on AppEnvironment"
```

---

## Task 4: Refactor BadgesView + InsightsView; delete BadgesViewModel

These three changes are coupled by the `BadgesView` signature and the removal of `BadgesViewModel`, so they land in one commit to keep the project compiling. The app-wide celebration host is added next (Task 5); between this commit and that one, the earn popup is briefly absent — harmless and intentional.

**Files:**
- Modify: `Daily Music/Views/BadgesView.swift`
- Modify: `Daily Music/Views/InsightsView.swift`
- Delete: `Daily Music/ViewModels/BadgesViewModel.swift`

- [ ] **Step 1: Rewrite BadgesView**

Replace the entire contents of `Daily Music/Views/BadgesView.swift` with:

```swift
//
//  BadgesView.swift
//  Daily Music
//
//  The full Badges page, opened from the Insights "recently earned" shelf. A hero
//  (earned count + current streak), the tiered badges as an "In Progress" grid with
//  progress, and an earned-only "Moments" grid. Unearned moments are not shown at
//  all — they stay a surprise. Tinted to the active accent.
//

import SwiftUI

struct BadgesView: View {
    let badges: [EarnedBadge]
    let accent: Color
    let currentStreak: Int

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    private var tiered: [EarnedBadge] { badges.filter { $0.tier != nil } }
    private var earnedMoments: [EarnedBadge] { badges.filter { $0.tier == nil && $0.isEarned } }
    private var earnedCount: Int { badges.filter { $0.isEarned }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                hero
                section(title: "In Progress", items: tiered) { BadgeTile(badge: $0, accent: accent) }
                if !earnedMoments.isEmpty {
                    section(title: "Moments · Unlocked", items: earnedMoments) { MomentTile(badge: $0, accent: accent) }
                }
                Text("✨ Some badges stay secret until you earn them")
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Spacing.sm)
            }
            .padding()
        }
        .navigationTitle("Badges")
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var hero: some View {
        HStack(spacing: Theme.Spacing.xl) {
            heroStat(value: "\(earnedCount)", label: "earned")
            heroStat(value: "🔥 \(currentStreak)", label: "day streak")
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(
            LinearGradient(colors: [accent.opacity(0.35), accent.opacity(0.12)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.weight(.heavy)).foregroundStyle(.primary)
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
        }
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
            BadgeDisc(symbol: badge.definition.symbol, tint: badge.definition.tint)
            Text(badge.definition.title)
                .font(.caption.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(badge.definition.subtitle)
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineLimit(2)
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
        }, accent: .purple, currentStreak: 14)
    }
}
```

- [ ] **Step 2: Update InsightsView — remove the badges view model**

In `Daily Music/Views/InsightsView.swift`:

Delete the state property (line ~17):
```swift
    @State private var badges: BadgesViewModel?
```

In the `.task(id: env.favoritesStore.ids)` modifier (lines ~72-87), delete the badges block so only the model load and a badge refresh remain:

```swift
        .task(id: env.favoritesStore.ids) {
            if model == nil {
                model = InsightsViewModel(entries: env.entries, ratings: env.ratings)
            }
            await model?.load(favoriteIDs: env.favoritesStore.ids, startingRead: startingRead)
            await env.badgeCenter.refresh()
        }
```

- [ ] **Step 3: Update InsightsView — remove the tab-local celebration**

Delete the `.overlay { ... }` celebration block (lines ~47-59) and the celebration `.animation` line (line ~60):

```swift
            .overlay {
                if let badge = celebrating {
                    Color.black.opacity(0.45).ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { dismissCelebration() }
                    BadgeCelebrationCard(
                        badge: badge,
                        accent: badge.definition.tint,
                        onDismiss: { dismissCelebration() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: celebrating)
```

Delete the `celebrating` computed property (line ~112):
```swift
    private var celebrating: EarnedBadge? { badges?.newlyEarned.first }
```

Delete the `dismissCelebration()` method (lines ~418-421):
```swift
    private func dismissCelebration() {
        badges?.acknowledgeCelebration()
        Haptics.success()
    }
```

(Keep `@Environment(\.accessibilityReduceMotion) private var reduceMotion` — it's still used by `wash`.)

- [ ] **Step 4: Update InsightsView — swap the badges card for the recent shelf**

In `content(_:)` (lines ~129-145), replace `badgesSummaryCard(accent: accent)` with `recentBadgesShelf(accent: accent)` and replace `tasteArcCard(accent: accent)` with `tasteArcRow(accent: accent)`. The VStack becomes:

```swift
            VStack(spacing: Theme.Spacing.lg) {
                recapMomentBanner
                TasteMirrorBoard(
                    mirror: mirror,
                    displayArchetype: mirror.archetype,
                    onRatingChanged: { Task { await model?.load(favoriteIDs: env.favoritesStore.ids, startingRead: startingRead) } },
                    onReplay: mirror.isArchetypeUnlocked ? { model?.replayReveal() } : nil,
                    revealCountdownText: countdownText(for: mirror)
                )
                recentBadgesShelf(accent: accent)
                historySummaryCard(accent: accent)
                tasteArcRow(accent: accent)
                wrappedButton(accent)
            }
            .padding()
```

Delete the entire `badgesSummaryCard(accent:)` method (lines ~204-251).

Replace the entire `tasteArcCard(accent:)` method (lines ~268-303) and its `arcCapsule`/`arcDots` helpers (lines ~305-333) with a single compact row. Add this `tasteArcRow` and **keep nothing** of the old capsule/dots helpers:

```swift
    @ViewBuilder
    private func recentBadgesShelf(accent: Color) -> some View {
        let recent = env.badgeCenter.recent
        let earnedCount = env.badgeCenter.summary?.earnedCount ?? 0
        NavigationLink {
            BadgesView(badges: env.badgeCenter.badges, accent: accent,
                       currentStreak: env.badgeCenter.currentStreak)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text("RECENTLY EARNED")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(earnedCount > 0 ? "View all \(earnedCount) ›" : "View all ›")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(accent)
                }
                if recent.isEmpty {
                    Text("Earn your first badge by catching a drop on its release day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(recent.prefix(4)) { badge in
                            VStack(spacing: 6) {
                                ShelfDisc(symbol: badge.definition.symbol, tint: badge.definition.tint)
                                Text(badge.definition.title)
                                    .font(.system(size: 10).weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    @ViewBuilder
    private func tasteArcRow(accent: Color) -> some View {
        if let summary = model?.tasteArcSummary,
           let eras = model?.tasteEras,
           eras.count >= 2 {
            NavigationLink {
                TasteArcTimelineView(eras: eras, accent: accent)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(accent)
                        .frame(width: 42, height: 42)
                        .glassEffect(.regular.tint(accent.opacity(0.14)), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("YOUR TASTE ARC")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.secondary)
                        Text(summary.current)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(summary.feedback)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.Spacing.md)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
            }
            .buttonStyle(PressableCardButtonStyle())
        }
    }
```

In `historySummaryCard(accent:)` (line ~199), change the row background from `.regularMaterial` to `.ultraThinMaterial` so History sits at the same lighter "quiet link" weight as the Taste Arc row:

```swift
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
```

- [ ] **Step 5: Add the ShelfDisc helper to InsightsView**

At the bottom of `Daily Music/Views/InsightsView.swift`, just above the closing `private extension String { ... }` block (line ~588), add a small disc used by the shelf:

```swift
/// A compact earned-badge disc for the Insights "recently earned" shelf.
private struct ShelfDisc: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Text(symbol)
            .font(.system(size: 24))
            .frame(width: 52, height: 52)
            .background(
                RadialGradient(colors: [tint.opacity(0.55), tint.opacity(0.12)],
                               center: .topLeading, startRadius: 2, endRadius: 50),
                in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
    }
}
```

- [ ] **Step 6: Delete BadgesViewModel**

```bash
git rm "Daily Music/ViewModels/BadgesViewModel.swift"
```

- [ ] **Step 7: Build to verify it compiles**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`
Expected: BUILD SUCCEEDED. If the compiler reports an unused `reduceMotion` or a leftover reference to `badgesSummaryCard`/`tasteArcCard`/`arcCapsule`/`arcDots`/`celebrating`/`dismissCelebration`, remove that stray reference — none should remain.

- [ ] **Step 8: Run tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/BadgeTests"`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add "Daily Music/Views/BadgesView.swift" "Daily Music/Views/InsightsView.swift"
git commit -m "feat: recent-badges shelf + dedicated Badges page; declutter Insights"
```

---

## Task 5: App-wide earn celebration host in MainTabView

**Files:**
- Modify: `Daily Music/Views/MainTabView.swift`

- [ ] **Step 1: Add environment + signal plumbing**

In `Daily Music/Views/MainTabView.swift`, add two environment properties after `@Environment(AppEnvironment.self) private var env` (line ~12):

```swift
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Add a `BadgeSignal` type and computed value inside `struct MainTabView`, just above the existing `private enum MainTab` (line ~114):

```swift
    /// The synchronously-observable store state that can flip a badge to earned.
    /// `.task(id:)` re-runs `BadgeCenter.refresh()` whenever any of it changes, so
    /// saving / catching a drop / rating surfaces the badge moments later, over
    /// whatever tab is showing. Check-in- and reveal-driven badges are caught on the
    /// next foreground (the scenePhase refresh below) or the next store change.
    private struct BadgeSignal: Equatable {
        let listens: [UUID: Date]
        let favorites: Set<UUID>
        let ratings: [UUID: Int]
    }

    private var badgeSignal: BadgeSignal {
        BadgeSignal(
            listens: env.listensStore.heardAt,
            favorites: env.favoritesStore.ids,
            ratings: env.ratingsStore.ratings
        )
    }

    private func dismissCelebration() {
        env.badgeCenter.acknowledgeCelebration()
        Haptics.success()
    }
```

- [ ] **Step 2: Attach the host modifiers to the TabView**

On the `TabView { ... }` in `body`, add these modifiers after the existing `.onChange(of: pendingWrappedRoute)` line (line ~50), before the closing of `body`:

```swift
        .task(id: badgeSignal) { await env.badgeCenter.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await env.badgeCenter.refresh() } }
        }
        .overlay {
            if let badge = env.badgeCenter.celebrating {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismissCelebration() }
                BadgeCelebrationCard(
                    badge: badge,
                    accent: badge.definition.tint,
                    onDismiss: { dismissCelebration() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85),
                   value: env.badgeCenter.celebrating)
```

- [ ] **Step 3: Build to verify it compiles**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual smoke test (simulator)**

Launch the app in the simulator (mock environment shows sample data). Verify:
1. Insights tab shows a "RECENTLY EARNED" shelf with discs and a "View all N ›" link.
2. Tapping the shelf opens the Badges page: hero (earned + 🔥 streak), "In Progress" grid with progress bars, "Moments · Unlocked" showing only earned moments (no "?" tiles), and the secret-hint footer.
3. History and Taste Arc render as compact lighter rows below the shelf.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/MainTabView.swift"
git commit -m "feat: app-wide badge earn celebration host"
```

---

## Task 6: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Full build**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Full test suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: All tests pass. Confirm there are no remaining references to `BadgesViewModel` anywhere:

Run: `grep -rn --include="*.swift" "BadgesViewModel" "Daily Music" "Daily MusicTests"`
Expected: no output.

- [ ] **Step 3: Update the architecture map**

Per the repo convention, reflect the change in `docs/ARCHITECTURE.md`: note that the badge engine now lives in `BadgeCenter` on `AppEnvironment` (replacing the Insights-local `BadgesViewModel`), that `BadgeEarnLog` backs recency ordering, and that the earn celebration is hosted app-wide in `MainTabView`. Commit:

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs: update architecture map for app-wide badge center"
```

---

## Self-Review Notes

- **Spec coverage:** BadgeCenter at app shell (Task 2–3) ✓; app-wide immediate celebration via `.task(id:)` + scenePhase + TabView overlay (Task 5) ✓; earn timestamps / recently-earned ordering (Task 1–2) ✓; recent shelf on Insights (Task 4) ✓; History + Taste Arc demoted to lighter rows (Task 4) ✓; full Badges page with hero/In Progress/earned-only Moments/secret hint (Task 4) ✓; moments fully hidden until earned (Task 4, `MomentTile` no longer has a mystery branch and `earnedMoments` filters to earned) ✓; tests for earn-log ordering, baseline, moments-hidden-by-construction, summary, celebration queue (existing `BadgeSeenStore` tests cover the queue) ✓.
- **Known scope boundary (matches spec):** the immediate refresh keys on the synchronously-observable store trio (listens/favorites/ratings). Check-in- and archetype-reveal-driven badges surface on the next foreground (`scenePhase == .active`) or the next store change, not necessarily the same instant. This is called out in the `BadgeSignal` doc comment.
- **Type consistency:** `BadgeCenter.makeSummary` / `BadgeCenter.sortedByRecency` / `BadgeCenter.Summary` used identically in impl and tests; `BadgesView(badges:accent:currentStreak:)` signature matches its only call site (`recentBadgesShelf`) and the `#Preview`; `BadgeEarnLog.record(_:now:)` / `.dates()` consistent across tasks.
