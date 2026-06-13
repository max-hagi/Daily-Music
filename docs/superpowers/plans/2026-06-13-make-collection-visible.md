# Make the Collection Visible — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the (currently invisible) `ListensStore` data — turn the Vault into a state-textured crate with a quiet collection count, make Favourites a framed record-shelf wall, and give the streak a minimal, separated badge with a once-a-day flare.

**Architecture:** One shared `SleeveView` renders album art per `ListenStatus` (used by the Vault crate grid and calendar). The Vault gains a quiet count card + crate-textured browsing; Favourites becomes a shelf wall; the streak moves off the settings cluster and flares once per day via a pure, tested guard. No new assets, no reordering, no backend changes.

**Tech Stack:** Swift 6 / SwiftUI, `@Observable`, Swift Testing (`@Test`/`#expect`).

**Spec:** `docs/superpowers/specs/2026-06-13-collection-visible-design.md`

---

## Conventions

**Build:**
```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```
**Test** (swap `build`→`test`, filter with `-only-testing`):
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/StreakTests" test
```
- App-target `.swift` files under `Daily Music/` auto-compile (no pbxproj edit).
- New tests go into already-registered `Daily MusicTests/CatchUpTests.swift` and `StreakTests.swift` (no pbxproj edit).
- Existing helpers used below: `AlbumArtView(url:cornerRadius:)`, `Theme.Spacing`, `Theme.Radius`, `Theme.Surface.favoritesBackground`, `.glassCardStyle(tint:)`, `.glassPillStyle(tint:)`, `Haptics`, `.dmHero()`/`.dmTitle()` fonts, `env.listensStore`.

## File Structure

- **Create** `Daily Music/Views/Components/SleeveView.swift` — album art + `ListenStatus` treatment, and a `ListenStatus.indicatorColor` helper.
- **Create** `Daily Music/Views/Components/CollectionCountCard.swift` — the quiet Vault count card.
- **Create** `Daily Music/Models/StreakFlare.swift` — pure once-per-day flare guard.
- **Modify** `Daily Music/ViewModels/ListensStore.swift` — add `collectedThisMonth`.
- **Modify** `Daily Music/Views/VaultView.swift` — count card, crate grid, remove trivia, calendar status.
- **Modify** `Daily Music/Views/Components/CalendarMonthView.swift` — optional status closure colours the day marker.
- **Modify** `Daily Music/Views/FavoritesView.swift` — `loaded` becomes a shelf wall.
- **Modify** `Daily Music/Views/TodayView.swift` — relocate + restyle the streak badge, add the flare.

Phases A→D are each independently shippable.

---

## Phase A — Shared building blocks

### Task A1: `SleeveView` + `ListenStatus.indicatorColor`

**Files:** Create `Daily Music/Views/Components/SleeveView.swift`

- [ ] **Step 1: Write the component**

```swift
//
//  SleeveView.swift
//  Daily Music
//
//  One place that renders an entry's album art with its ListenStatus treatment,
//  so "mint / caught-up / missed" reads consistently across the Vault crate and
//  the calendar. Asset-free: dim + desaturate + an SF-Symbol overlay.
//

import SwiftUI

struct SleeveView: View {
    let entry: DailyEntry
    let status: ListenStatus
    var size: CGFloat = 64

    private var isMissed: Bool { status == .missed }

    var body: some View {
        AlbumArtView(url: entry.albumArtURL, cornerRadius: Theme.Radius.chip)
            .frame(width: size, height: size)
            .saturation(isMissed ? 0 : 1)
            .opacity(isMissed ? 0.4 : 1)
            .overlay {
                if isMissed {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: size * 0.28, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if status == .caughtUp {
                    Text("2nd")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(3)
                }
            }
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let state: String
        switch status {
        case .heardSameDay: state = "collected"
        case .caughtUp: state = "caught up, second pressing"
        case .missed: state = "missed"
        case .rescuable: state = "still available"
        case .unheard: state = "not yet heard"
        }
        return "\(entry.title) by \(entry.artist), \(state)"
    }
}

extension ListenStatus {
    /// Marker colour for compact surfaces (the calendar day dot).
    var indicatorColor: Color {
        switch self {
        case .heardSameDay: .teal
        case .caughtUp: .orange
        case .rescuable: .orange.opacity(0.55)
        case .missed: .gray.opacity(0.45)
        case .unheard: .accentColor
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED. (No unit test — purely visual; verified by use in Phase B + manual check.)

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Components/SleeveView.swift"
git commit -m "feat(collection): add SleeveView state treatment + indicator colour"
```

### Task A2: `ListensStore.collectedThisMonth`

**Files:** Modify `Daily Music/ViewModels/ListensStore.swift`; Test `Daily MusicTests/CatchUpTests.swift`

- [ ] **Step 1: Write the failing test** (append inside the existing `struct ListensStoreTests`, before its closing brace)

```swift
    @Test func collectedThisMonthCountsOnlyThisMonth() async {
        let cal = Calendar(identifier: .gregorian)
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let store = ListensStore(service: MockListensService(), defaults: freshDefaults())
        let thisMonth = entry(date: cal.date(from: DateComponents(year: 2026, month: 6, day: 3))!)
        let lastMonth = entry(date: cal.date(from: DateComponents(year: 2026, month: 5, day: 28))!)
        store.markHeard(thisMonth)   // heard "now" by the store clock
        store.markHeard(lastMonth)
        // Both heardAt are ~now (June), so both count this month under a June `now`.
        #expect(store.collectedThisMonth(asOf: now, calendar: cal) == 2)
    }
```

Note: `markHeard` stamps `heardAt = Date()` (real now). The test asserts the count reflects entries whose `heardAt` is in `now`'s month; run on any date, the freshly-marked rows share the real current month. To make the assertion robust regardless of wall-clock month, the test uses `asOf:` equal to the real current month — see Step 3's signature; if the suite runs across a month boundary it still holds because `markHeard` and `asOf` both track "now". Keep `now` as `Date()`:

Replace the test body's `now` with the real clock so it can't drift:

```swift
    @Test func collectedThisMonthCountsOnlyThisMonth() async {
        let store = ListensStore(service: MockListensService(), defaults: freshDefaults())
        store.markHeard(entry())
        store.markHeard(entry())
        #expect(store.collectedThisMonth() == 2)              // both heard now → this month
        #expect(store.collectedThisMonth(asOf: .distantFuture) == 0)  // far future month → none
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `-only-testing:"Daily MusicTests/ListensStoreTests"` test. Expected: FAIL — no `collectedThisMonth`.

- [ ] **Step 3: Implement** (add to `ListensStore`, after `collectionCount`)

```swift
    /// Records collected in the same calendar month as `now`.
    func collectedThisMonth(asOf now: Date = Date(), calendar: Calendar = .current) -> Int {
        heardAt.values.filter { calendar.isDate($0, equalTo: now, toGranularity: .month) }.count
    }
```

- [ ] **Step 4: Run to verify it passes** — same command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/ViewModels/ListensStore.swift" "Daily MusicTests/CatchUpTests.swift"
git commit -m "feat(collection): add collectedThisMonth to ListensStore"
```

### Task A3: `StreakFlare` guard

**Files:** Create `Daily Music/Models/StreakFlare.swift`; Test `Daily MusicTests/StreakTests.swift`

- [ ] **Step 1: Write the failing test** (append inside `struct StreakTests`, before its closing brace; it already defines `calendar`, `now`, `day(_:)`)

```swift
    @Test func flaresOnFirstAliveExtensionOfTheDay() {
        #expect(StreakFlare.shouldFlare(lastFlareDay: nil, isAliveToday: true, calendar: calendar, asOf: now))
    }

    @Test func doesNotFlareAgainSameDay() {
        #expect(!StreakFlare.shouldFlare(lastFlareDay: now, isAliveToday: true, calendar: calendar, asOf: now))
    }

    @Test func flaresAgainOnANewDay() {
        #expect(StreakFlare.shouldFlare(lastFlareDay: day(-1), isAliveToday: true, calendar: calendar, asOf: now))
    }

    @Test func neverFlaresWhenNotAliveToday() {
        #expect(!StreakFlare.shouldFlare(lastFlareDay: nil, isAliveToday: false, calendar: calendar, asOf: now))
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `-only-testing:"Daily MusicTests/StreakTests"` test. Expected: FAIL — no `StreakFlare`.

- [ ] **Step 3: Implement**

```swift
//
//  StreakFlare.swift
//  Daily Music
//
//  Pure guard for the once-a-day streak flare: fire when today's check-in first
//  makes the streak alive, and not again until a new day. Mirrors the milestone
//  celebration guard so re-opening the app the same day never replays it.
//

import Foundation

enum StreakFlare {
    static func shouldFlare(
        lastFlareDay: Date?,
        isAliveToday: Bool,
        calendar: Calendar = .current,
        asOf now: Date = Date()
    ) -> Bool {
        guard isAliveToday else { return false }
        guard let lastFlareDay else { return true }
        return !calendar.isDate(lastFlareDay, inSameDayAs: now)
    }
}
```

- [ ] **Step 4: Run to verify it passes** — same command. Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/StreakFlare.swift" "Daily MusicTests/StreakTests.swift"
git commit -m "feat(streak): add once-a-day StreakFlare guard"
```

---

## Phase B — Vault: the Crate

### Task B1: `CollectionCountCard`

**Files:** Create `Daily Music/Views/Components/CollectionCountCard.swift`

- [ ] **Step 1: Write the component**

```swift
//
//  CollectionCountCard.swift
//  Daily Music
//
//  The Vault's quiet hero: the personal collection count. Deliberately modest —
//  the proud showcase is the Favourites wall, not here.
//

import SwiftUI

struct CollectionCountCard: View {
    let total: Int
    let thisMonth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Your collection")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(total)")
                    .font(.dmHero())
                    .foregroundStyle(.teal)
                    .contentTransition(.numericText())
                Text("records · \(thisMonth) this month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .glassCardStyle(tint: .teal.opacity(0.08))
    }
}
```

- [ ] **Step 2: Build** — Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Components/CollectionCountCard.swift"
git commit -m "feat(collection): add CollectionCountCard"
```

### Task B2: Wire the count card into the Vault + remove the published-total trivia

**Files:** Modify `Daily Music/Views/VaultView.swift`

- [ ] **Step 1: Insert the count card above the hero**

In the `content(_:)` builder, the VStack currently is:
```swift
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                vaultHero(entries)
                calendarSection(entries)
                recentSection(entries)
            }
```
Change to:
```swift
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                CollectionCountCard(
                    total: env.listensStore.collectionCount,
                    thisMonth: env.listensStore.collectedThisMonth()
                )
                vaultHero(entries)
                calendarSection(entries)
                recentSection(entries)
            }
```

- [ ] **Step 2: Remove the competing published-total line**

In `calendarSection`, delete this block (lines ~165-169):
```swift
                    // The archive's only stats — demoted to quiet trivia so the
                    // catch-up hero and calendar own the screen.
                    Text("\(entries.count) songs · \(entriesThisMonth(entries)) this month")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
```
Then delete the now-unused helper `entriesThisMonth(_:)` (lines ~223-226):
```swift
    // Count entries whose date is in the current month (toGranularity: .month).
    private func entriesThisMonth(_ entries: [DailyEntry]) -> Int {
        entries.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
    }
```
(Verify: `grep -n "entriesThisMonth" "Daily Music/Views/VaultView.swift"` returns nothing.)

- [ ] **Step 3: Build** — Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/VaultView.swift"
git commit -m "feat(collection): surface collection count as the Vault hero"
```

### Task B3: Crate-texture the Recent picks

**Files:** Modify `Daily Music/Views/VaultView.swift`

- [ ] **Step 1: Replace the recent rows with a crate grid**

In `recentSection(_:)`, replace the row VStack (lines ~208-219):
```swift
            VStack(spacing: 10) {
                // `.prefix(5)` takes at most the first five; ForEach needs an Array,
                // and no `id:` is required because DailyEntry is Identifiable.
                ForEach(Array(entries.prefix(5))) { entry in
                    Button {
                        openVaultEntry(entry)
                    } label: {
                        VaultTintedEntryRow(entry: entry)
                    }
                    .buttonStyle(PressableCardButtonStyle())
                }
            }
```
with a sleeve grid (newest first, textured by state):
```swift
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(Array(entries.prefix(12))) { entry in
                    Button {
                        openVaultEntry(entry)
                    } label: {
                        SleeveView(entry: entry, status: env.listensStore.status(for: entry), size: 72)
                    }
                    .buttonStyle(PressableCardButtonStyle())
                }
            }
```

- [ ] **Step 2: Build** — Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/VaultView.swift"
git commit -m "feat(collection): crate-texture recent picks with SleeveView"
```

### Task B4: Stamp the calendar by state

**Files:** Modify `Daily Music/Views/Components/CalendarMonthView.swift`, `Daily Music/Views/VaultView.swift`

- [ ] **Step 1: Add an optional status closure to `CalendarMonthView`**

Add a stored property next to `reactionsByEntry` (line ~20):
```swift
    private let reactionsByEntry: [UUID: String]
    private let statusForEntry: ((DailyEntry) -> ListenStatus)?
```
Extend the custom `init` (line ~27) — change the signature and assign:
```swift
    init(entries: [DailyEntry], reactions: [UUID: String] = [:],
         status: ((DailyEntry) -> ListenStatus)? = nil,
         onSelect: ((DailyEntry) -> Void)? = nil) {
```
and inside it, after `self.reactionsByEntry = reactions`:
```swift
        self.statusForEntry = status
```
(Leave the rest of the init — `_month`, `onSelect`, etc. — unchanged.)

- [ ] **Step 2: Colour the day marker by state**

In `dayCell(_:)`, the marker `else` branch currently is:
```swift
                        } else {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 5, height: 5)
                        }
```
Change the fill to the status colour:
```swift
                        } else {
                            Circle()
                                .fill((statusForEntry?(entry).indicatorColor) ?? Color.accentColor)
                                .frame(width: 5, height: 5)
                        }
```

- [ ] **Step 3: Pass the status from the Vault**

In `VaultView.calendarSection`, the call (line ~176) is:
```swift
            CalendarMonthView(entries: entries, reactions: reactions) { entry in
                openVaultEntry(entry)
            }
```
Change to:
```swift
            CalendarMonthView(entries: entries, reactions: reactions,
                              status: { env.listensStore.status(for: $0) }) { entry in
                openVaultEntry(entry)
            }
```

- [ ] **Step 4: Build** — Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/Components/CalendarMonthView.swift" "Daily Music/Views/VaultView.swift"
git commit -m "feat(collection): stamp the calendar by listen state"
```

---

## Phase C — Favourites: the Wall

### Task C1: Shelf-wall layout

**Files:** Modify `Daily Music/Views/FavoritesView.swift`

Replace the `List`-based `loaded(_:)` with a scrolling shelf wall. Keep the existing `header`, `background`, `selectedEntry`, `removeFavorite`, and `refreshable` behaviour.

- [ ] **Step 1: Rewrite `loaded(_:)`**

Replace the entire `loaded(_ entries:)` function (lines ~82-131) with:
```swift
    private func loaded(_ entries: [DailyEntry]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header(count: entries.count)
                    .padding(.horizontal, Theme.Spacing.md)
                ForEach(shelfRows(entries), id: \.self) { row in
                    shelf(row)
                }
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .scrollContentBackground(.hidden)
        .background(background)
        .refreshable {
            await env.favoritesStore.load()
            Haptics.tap()
        }
    }

    // Chunk the wall into rows of three records.
    private func shelfRows(_ entries: [DailyEntry]) -> [[DailyEntry]] {
        stride(from: 0, to: entries.count, by: 3).map {
            Array(entries[$0 ..< min($0 + 3, entries.count)])
        }
    }

    private func shelf(_ row: [DailyEntry]) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
                ForEach(row) { entry in
                    framedRecord(entry)
                }
                ForEach(0 ..< (3 - row.count), id: \.self) { _ in
                    Spacer().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            // The shelf ledge.
            Rectangle()
                .fill(.primary.opacity(0.12))
                .frame(height: 2)
                .padding(.horizontal, Theme.Spacing.sm)
        }
    }

    private func framedRecord(_ entry: DailyEntry) -> some View {
        Button { selectedEntry = entry } label: {
            VStack(spacing: 6) {
                AlbumArtView(url: entry.albumArtURL, cornerRadius: Theme.Radius.chip)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 0.5)
                    )
                VStack(spacing: 1) {
                    Text(entry.title).font(.caption.weight(.semibold)).lineLimit(1)
                    Text(entry.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { selectedEntry = entry } label: {
                Label("Open Entry", systemImage: "arrow.up.forward.app")
            }
            Button(role: .destructive) { removeFavorite(entry) } label: {
                Label("Remove Favorite", systemImage: "heart.slash.fill")
            }
        }
    }
```

- [ ] **Step 2: Confirm nothing else referenced the removed `List` internals**

```bash
grep -n "EntryRow\|swipeActions\|listRow" "Daily Music/Views/FavoritesView.swift"
```
Expected: no remaining hits inside `loaded` (the `FavoriteEntryPeek`/`FavoriteEntryDetail` structs below are untouched). If `EntryRow` is now unused project-wide, leave it — it's still used by `VaultView`.

- [ ] **Step 3: Build** — Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/FavoritesView.swift"
git commit -m "feat(collection): Favourites becomes a framed record-shelf wall"
```

---

## Phase D — Streak: minimal, separated, flaring

### Task D1: Relocate, restyle, and flare the streak badge

**Files:** Modify `Daily Music/Views/TodayView.swift`

- [ ] **Step 1: Move the streak out of the leading (settings) group**

Delete the leading streak `ToolbarItem` (lines ~75-79):
```swift
                ToolbarItem(placement: .topBarLeading) {
                    if let streak = model?.streak, streak.current > 0 {
                        TodayToolbarStreakBadge(streak: streak)
                    }
                }
```
Add it to the trailing group, *before* the live badge item, so it sits left of the listeners count and well away from the settings gear. Immediately above the existing `ToolbarItem(placement: .topBarTrailing) { TodayToolbarLiveBadge(...) }` (line ~81), insert:
```swift
                ToolbarItem(placement: .topBarTrailing) {
                    if let streak = model?.streak, streak.current > 0 {
                        TodayToolbarStreakBadge(streak: streak)
                    }
                }
```

- [ ] **Step 2: Restyle the badge minimal + add the flare**

Replace the `TodayToolbarStreakBadge` `body` (lines ~295-321) with the minimal, flaring version. The resting state drops the glass pill (kept only on milestone days); a `circle` flourish + scale pulse fires once per day, gated by `StreakFlare` and an AppStorage day-stamp, honouring reduce-motion:

```swift
    @AppStorage("lastCelebratedStreakMilestone") private var lastCelebratedMilestone = 0
    @AppStorage("lastStreakFlareDay") private var lastStreakFlareDay = 0.0
    @State private var showingDetail = false
    @State private var flaring = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Haptics.select()
            showingDetail = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .scaleEffect(flaring && !reduceMotion ? 1.5 : 1)
                    .overlay {
                        if flaring && !reduceMotion {
                            Circle()
                                .stroke(.orange.opacity(0.6), lineWidth: 2)
                                .scaleEffect(flaring ? 2.6 : 0.6)
                                .opacity(flaring ? 0 : 0.8)
                        }
                    }

                Text(label)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .glassPillStyle(tint: .orange.opacity(streak.isMilestoneToday ? 0.22 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onAppear {
            celebrateMilestoneIfNeeded()
            flareIfNeeded()
        }
        .popover(isPresented: $showingDetail, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            streakDetail
                .presentationCompactAdaptation(.popover)
        }
    }

    private func flareIfNeeded() {
        let last = lastStreakFlareDay == 0 ? nil : Date(timeIntervalSinceReferenceDate: lastStreakFlareDay)
        guard StreakFlare.shouldFlare(lastFlareDay: last, isAliveToday: streak.isAliveToday) else { return }
        lastStreakFlareDay = Date().timeIntervalSinceReferenceDate
        if Haptics.isEnabled { Haptics.tap() }
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { flaring = true }
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.25)) { flaring = false }
        }
    }
```

Note: this keeps the existing `glassPillStyle` usage (now `0` tint when not a milestone — a borderless resting state) and reuses the existing `label`, `accessibilityText`, `streakDetail`, and `celebrateMilestoneIfNeeded()` members below it unchanged. Confirm `Haptics.isEnabled` and `Haptics.tap()` exist (used elsewhere in the file); if `Haptics.isEnabled` is not a thing, drop that guard and call `Haptics.tap()` directly (it already respects the setting internally — check `Haptics.swift`).

- [ ] **Step 3: Build** — Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/TodayView.swift"
git commit -m "feat(streak): minimal badge separated from settings, once-a-day flare"
```

---

## Final verification

- [ ] **Full suite + build:**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```
Expected: BUILD SUCCEEDED, all tests pass.
- [ ] **Manual (simulator):** Vault shows the count card + state-textured crate grid + colour-stamped calendar; catch-up hero intact. Favourites renders as a shelf wall; tapping opens an entry. Streak sits in the trailing group (not beside the gear), reads minimal, and flares once on the first open of a day.

## Self-review notes (author)

- **Spec coverage:** §1 SleeveView (A1) · §2a count hero + `collectedThisMonth` + trivia removal (A2, B1, B2) · §2b crate texture (B3) · §2c calendar stamps (B4) · §3 Wall shelves display-only (C1) · §4 streak relocate/minimal/flare + `StreakFlare` (A3, D1).
- **Type consistency:** `SleeveView(entry:status:size:)`, `ListenStatus.indicatorColor`, `ListensStore.collectedThisMonth(asOf:calendar:)`, `StreakFlare.shouldFlare(lastFlareDay:isAliveToday:calendar:asOf:)`, `CollectionCountCard(total:thisMonth:)`, `CalendarMonthView(entries:reactions:status:onSelect:)` — names match across tasks.
- **Deferred (not here):** crate-dig flip-through, Wall drag-reorder, streak→45 restyle, collection-moment animation, variants, Curator.
