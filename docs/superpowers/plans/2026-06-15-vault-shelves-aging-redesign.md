# Vault Redesign Implementation Plan — Month Shelves, Sleeve Aging, Art-Mosaic Calendar

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Vault so browse is navigable by month, worn/missed records read at a glance, the calendar shows covers instead of dots, and the header carries a dynamic nudge plus a collection share card.

**Architecture:** Pure layout/derivation helpers (month grouping, nudge copy) live next to `CrateLayout` and are unit-tested. The single full-screen coverflow (`CrateView`) is replaced by a vertical scroll of horizontally-scrollable month "shelves" (`MonthShelvesView`). `SleeveView` gains a clearly-worn secondhand treatment and a dusty-but-visible missed treatment. `CalendarMonthView` day cells render small `SleeveView`s. `VaultView`'s header is rebuilt and gains a share button backed by a new `CollectionShareCardView` (mirroring `ShareCardView`).

**Tech Stack:** SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`), `ImageRenderer` + `ShareLink` for share cards.

**Conventions for every task:**
- **Build command** (CLI; `xcode-select` points at CommandLineTools, so override `DEVELOPER_DIR`):
  ```bash
  cd "/Users/maximesavehilaghi/Developer/Daily Music"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    xcodebuild -scheme "Daily Music" \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build
  ```
- **Test command** (same `DEVELOPER_DIR` prefix, `test` instead of `build`):
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    xcodebuild -scheme "Daily Music" \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug test
  ```
- **The app target auto-compiles new files** under `Daily Music/` (Xcode-16 synchronized group). **The test target does NOT** — a brand-new test file needs manual Xcode registration. To avoid that, **all new tests in this plan are added to the existing, already-registered `Daily MusicTests/CatchUpTests.swift`.**
- New source files under `Daily Music/...` compile automatically; no pbxproj edit needed for them.

---

## Task 1: Month-grouping helper for the shelves

Group the newest-first entries into ordered month buckets the shelves render.

**Files:**
- Modify: `Daily Music/Models/CrateLayout.swift`
- Test: `Daily MusicTests/CatchUpTests.swift` (add a new `struct` at the end)

- [ ] **Step 1: Write the failing test**

Add to the end of `Daily MusicTests/CatchUpTests.swift`:

```swift
struct CrateMonthSectionTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func entry(_ y: Int, _ m: Int, _ d: Int) -> DailyEntry {
        let date = calendar.date(from: DateComponents(year: y, month: m, day: d))!
        return DailyEntry(id: UUID(), date: date, title: "S", artist: "A",
                          albumArtURL: nil, journalMarkdown: "", appleMusicID: "1",
                          spotifyURI: "spotify:track:1")
    }

    @Test func groupsEntriesByMonthNewestFirst() {
        let jun2 = entry(2026, 6, 2)
        let jun20 = entry(2026, 6, 20)
        let may = entry(2026, 5, 9)
        let sections = CrateLayout.monthSections(
            for: [jun20, jun2, may], calendar: calendar   // already newest-first
        )
        #expect(sections.count == 2)
        #expect(sections[0].entries.map(\.id) == [jun20.id, jun2.id])  // June, newest-first
        #expect(sections[1].entries.map(\.id) == [may.id])             // then May
    }

    @Test func monthSectionTitleIsMonthAndYear() {
        let sections = CrateLayout.monthSections(for: [entry(2026, 6, 2)], calendar: calendar)
        #expect(sections[0].title == "June 2026")
    }

    @Test func emptyInputYieldsNoSections() {
        #expect(CrateLayout.monthSections(for: [], calendar: calendar).isEmpty)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run the test command above (optionally `-only-testing:"Daily MusicTests/CrateMonthSectionTests"`).
Expected: FAIL to compile — `monthSections` and `MonthSection` are not defined.

- [ ] **Step 3: Write the minimal implementation**

Add to `Daily Music/Models/CrateLayout.swift` inside `enum CrateLayout` (after `collectionCountLabel`):

```swift
    /// One month's worth of entries for the Crate shelves.
    struct MonthSection: Identifiable {
        let id: Date          // first-of-month, used as stable identity
        let title: String     // e.g. "June 2026"
        let entries: [DailyEntry]
    }

    /// Group newest-first entries into ordered month buckets (months newest-first,
    /// entries kept in their incoming newest-first order within each month).
    static func monthSections(
        for entries: [DailyEntry],
        calendar: Calendar = .current
    ) -> [MonthSection] {
        var order: [Date] = []
        var buckets: [Date: [DailyEntry]] = [:]
        for entry in entries {
            let monthStart = calendar.dateInterval(of: .month, for: entry.date)?.start
                ?? calendar.startOfDay(for: entry.date)
            if buckets[monthStart] == nil { order.append(monthStart) }
            buckets[monthStart, default: []].append(entry)
        }
        return order.map { start in
            MonthSection(
                id: start,
                title: start.formatted(.dateTime.month(.wide).year()),
                entries: buckets[start] ?? []
            )
        }
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run the test command. Expected: PASS for `CrateMonthSectionTests` (3 tests).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/CrateLayout.swift" "Daily MusicTests/CatchUpTests.swift"
git commit -m "feat(vault): month-grouping helper for the Crate shelves"
```

---

## Task 2: Dynamic header nudge (`VaultNudge`)

A pure, priority-ordered picker for the header's secondary line. Replaces the always-on count label.

**Files:**
- Modify: `Daily Music/Models/CrateLayout.swift` (add the `VaultNudge` enum in the same file — it is small, layout-adjacent copy)
- Test: `Daily MusicTests/CatchUpTests.swift` (add a new `struct` at the end)

- [ ] **Step 1: Write the failing test**

Add to the end of `Daily MusicTests/CatchUpTests.swift`:

```swift
struct VaultNudgeTests {
    private let calendar = Calendar(identifier: .gregorian)
    private func month(_ y: Int, _ m: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: 1))!
    }

    @Test func rescuableTakesTopPriority() {
        let line = VaultNudge.line(
            total: 47, rescuable: 2, collectedToday: true,
            daysToNextMilestone: 1, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "2 waiting to be rescued")
    }

    @Test func rescuableSingularGrammar() {
        let line = VaultNudge.line(
            total: 47, rescuable: 1, collectedToday: false,
            daysToNextMilestone: nil, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "1 waiting to be rescued")
    }

    @Test func milestoneProximityWhenNothingRescuable() {
        let line = VaultNudge.line(
            total: 47, rescuable: 0, collectedToday: true,
            daysToNextMilestone: 2, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "2 days to your next pressing")
    }

    @Test func milestoneProximitySingularDay() {
        let line = VaultNudge.line(
            total: 47, rescuable: 0, collectedToday: true,
            daysToNextMilestone: 1, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "1 day to your next pressing")
    }

    @Test func defaultIsCountAndProvenance() {
        let line = VaultNudge.line(
            total: 47, rescuable: 0, collectedToday: false,
            daysToNextMilestone: nil, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "47 records · started April 2026")
    }

    @Test func defaultSingularRecordNoProvenanceWhenStartUnknown() {
        let line = VaultNudge.line(
            total: 1, rescuable: 0, collectedToday: false,
            daysToNextMilestone: nil, startedMonth: nil, calendar: calendar
        )
        #expect(line == "1 record")
    }

    @Test func milestoneProximityIgnoredWhenNotCollectedToday() {
        // Only nudge toward the next pressing on a day you've collected — otherwise
        // fall through to the default count line.
        let line = VaultNudge.line(
            total: 47, rescuable: 0, collectedToday: false,
            daysToNextMilestone: 2, startedMonth: month(2026, 4), calendar: calendar
        )
        #expect(line == "47 records · started April 2026")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run the test command. Expected: FAIL to compile — `VaultNudge` is not defined.

- [ ] **Step 3: Write the minimal implementation**

Add to `Daily Music/Models/CrateLayout.swift` (top-level, below the `CrateLayout` enum):

```swift
/// The Vault header's secondary line — a context-aware nudge chosen by priority.
/// Pure and unit-tested; the view passes in counts/dates and renders the string.
enum VaultNudge {
    static func line(
        total: Int,
        rescuable: Int,
        collectedToday: Bool,
        daysToNextMilestone: Int?,
        startedMonth: Date?,
        calendar: Calendar = .current
    ) -> String {
        // 1. Something to reclaim wins — it's the strongest pull back in.
        if rescuable > 0 {
            return "\(rescuable) waiting to be rescued"
        }
        // 2. On a day you've collected, nudge toward the next streak pressing.
        if collectedToday, let days = daysToNextMilestone, days > 0 {
            let noun = days == 1 ? "day" : "days"
            return "\(days) \(noun) to your next pressing"
        }
        // 3. Default: the hero count, with provenance when we know the start month.
        let recordNoun = total == 1 ? "record" : "records"
        guard let startedMonth else { return "\(total) \(recordNoun)" }
        let month = startedMonth.formatted(.dateTime.month(.wide).year())
        return "\(total) \(recordNoun) · started \(month)"
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run the test command. Expected: PASS for `VaultNudgeTests` (7 tests).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/CrateLayout.swift" "Daily MusicTests/CatchUpTests.swift"
git commit -m "feat(vault): dynamic header nudge picker (VaultNudge)"
```

---

## Task 3: "Clearly worn" secondhand sleeve treatment

Make a caught-up-late record read as used at a glance: add ring-wear + scuffs on top of the existing dog-ear/stamp/desaturation.

**Files:**
- Modify: `Daily Music/Views/Components/SleeveView.swift` (the `secondhandSleeve` computed property and add two private helper views)

- [ ] **Step 1: Replace the `secondhandSleeve` implementation**

In `Daily Music/Views/Components/SleeveView.swift`, replace the existing `secondhandSleeve` property with:

```swift
    private var secondhandSleeve: some View {
        let muted = secondhandVariant == .mutingOnly
        return artCover
            .saturation(muted ? 0.4 : 0.55)
            .brightness(muted ? -0.05 : -0.04)
            .overlay { ringWear }            // the vinyl's ghost worn into the card
            .overlay { scuffs }              // faint diagonal shelf-wear
            .overlay(alignment: .topTrailing) {
                if secondhandVariant == .wornCornerStamp { dogEar }
            }
            .overlay(alignment: .bottomTrailing) {
                if secondhandVariant == .wornCornerStamp { stamp }
            }
            .overlay(alignment: .leading) {
                if secondhandVariant == .edgeLabel { edgeLabel }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .offset(y: coverDrop)
    }

    /// A circular wear mark — the pressed record's outline ghosted into the sleeve.
    private var ringWear: some View {
        let d = coverSide * 0.74
        return ZStack {
            Circle().stroke(Color.black.opacity(0.14), lineWidth: coverSide * 0.045)
            Circle().stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .frame(width: d, height: d)
    }

    /// A couple of faint diagonal scuffs so the surface reads as handled.
    private var scuffs: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.07))
                .frame(width: coverSide * 0.5, height: 1)
                .rotationEffect(.degrees(-32))
                .offset(x: -coverSide * 0.1, y: -coverSide * 0.18)
            Capsule()
                .fill(Color.black.opacity(0.08))
                .frame(width: coverSide * 0.42, height: 1)
                .rotationEffect(.degrees(-32))
                .offset(x: coverSide * 0.12, y: coverSide * 0.16)
        }
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Visually verify (preview)**

Open `SleeveView.swift` in Xcode and run the `#Preview("Sleeve states")` and `#Preview("Secondhand variants")` canvases. Confirm the secondhand sleeve now shows an obvious ring-wear circle + scuffs and reads as clearly worn next to mint.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/Components/SleeveView.swift"
git commit -m "feat(vault): clearly-worn secondhand sleeve (ring-wear + scuffs)"
```

---

## Task 4: Dusty-but-visible missed sleeve + Rescue affordance

Missed records stop being blank: show the real art heavily aged with a dust haze and a small "Rescue" badge. Flip the shipping default.

**Files:**
- Modify: `Daily Music/Models/VariantConfig.swift` (add `.dusty` case to `MissingSleeveVariant`, make it the default)
- Modify: `Daily Music/Views/Components/SleeveView.swift` (`missingSleeve` renders dusty when variant is `.dusty`, add a Rescue badge)
- Test: `Daily MusicTests/CatchUpTests.swift` (update `VariantConfigTests.defaultsMatchLockedPicks`)

- [ ] **Step 1: Update the variant default test (will fail)**

In `Daily MusicTests/CatchUpTests.swift`, change the `missingSleeve` assertion inside `VariantConfigTests.defaultsMatchLockedPicks` from:

```swift
        #expect(c.missingSleeve == .blank)
```

to:

```swift
        #expect(c.missingSleeve == .dusty)
```

- [ ] **Step 2: Run the test to verify it fails**

Run the test command (`-only-testing:"Daily MusicTests/VariantConfigTests"`).
Expected: FAIL to compile — `.dusty` is not a case yet.

- [ ] **Step 3: Add the `.dusty` case and make it the default**

In `Daily Music/Models/VariantConfig.swift`, replace the `MissingSleeveVariant` enum with:

```swift
/// §11.1 — how a permanently-missed day looks in the crate.
enum MissingSleeveVariant: String, VariantOption {
    case dusty   // real art, heavily aged under a dust haze (default — a reward to look at, and rescuable)
    case blank   // empty sleeve, faint outline
    case ghost   // the real art at very low opacity
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dusty: "Dusty"
        case .blank: "Blank"
        case .ghost: "Ghost"
        }
    }
}
```

Then change the `VariantConfig.init` default for `missingSleeve` from `.blank` to `.dusty`:

```swift
    init(missingSleeve: MissingSleeveVariant = .dusty,
         secondhand: SecondhandVariant = .wornCornerStamp,
         crateFeel: CrateFeel = .centerTilt,
         momentTiming: MomentTiming = .playful) {
```

- [ ] **Step 4: Render the dusty treatment + Rescue badge**

In `Daily Music/Views/Components/SleeveView.swift`, replace the `missingSleeve` property with:

```swift
    private var missingSleeve: some View {
        ZStack {
            switch missingVariant {
            case .dusty:
                dustyArt
            case .ghost:
                AlbumArtView(url: entry.albumArtURL, cornerRadius: radius)
                    .frame(width: coverSide, height: coverSide)
                    .opacity(0.16)
                missingOutline
            case .blank:
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: coverSide, height: coverSide)
                missingOutline
            }
        }
        .offset(y: coverDrop)
    }

    /// The real art, aged: desaturated, dimmed, under a neutral dust haze with a few
    /// specks — visible enough to be worth a look, clearly "left in the crate".
    private var dustyArt: some View {
        AlbumArtView(url: entry.albumArtURL, cornerRadius: radius)
            .frame(width: coverSide, height: coverSide)
            .saturation(0.18)
            .brightness(-0.06)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(.systemGray).opacity(0.28))
            }
            .overlay { dustSpecks }
            .overlay(alignment: .bottom) { rescueBadge }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// The faint outline + sleeve "mouth" + dashed border used by blank/ghost.
    private var missingOutline: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(width: coverSide, height: coverSide)
            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(width: coverSide * 0.8, height: 1)
                .offset(y: -coverSide * 0.32)
            Image(systemName: "circle.dashed")
                .font(.system(size: coverSide * 0.3, weight: .regular))
                .foregroundStyle(.tertiary)
        }
    }

    private var dustSpecks: some View {
        ZStack {
            Circle().fill(.white.opacity(0.35)).frame(width: 2, height: 2)
                .offset(x: -coverSide * 0.28, y: -coverSide * 0.22)
            Circle().fill(.white.opacity(0.28)).frame(width: 1.5, height: 1.5)
                .offset(x: coverSide * 0.3, y: coverSide * 0.1)
            Circle().fill(.white.opacity(0.3)).frame(width: 1.5, height: 1.5)
                .offset(x: coverSide * 0.05, y: coverSide * 0.3)
        }
    }

    /// "Rescue" pill on a missed sleeve — listening it later reclaims it.
    private var rescueBadge: some View {
        Text("Rescue")
            .font(.system(size: max(9, coverSide * 0.12), weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.black.opacity(0.5), in: Capsule())
            .padding(.bottom, coverSide * 0.08)
    }
```

- [ ] **Step 5: Run the test to verify it passes**

Run the test command. Expected: PASS for `VariantConfigTests`.

- [ ] **Step 6: Build + visually verify**

Run the build command (Expected: BUILD SUCCEEDED). Then in Xcode run `#Preview("Missing variants")` and confirm the `.dusty` sleeve shows aged real art + a "Rescue" pill, and is the leftmost/default in the gallery.

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Models/VariantConfig.swift" "Daily Music/Views/Components/SleeveView.swift" "Daily MusicTests/CatchUpTests.swift"
git commit -m "feat(vault): dusty-but-visible missed sleeve with Rescue affordance"
```

---

## Task 5: Month Shelves browse (replace the coverflow)

Replace the full-screen `CrateView` with a vertical scroll of per-month shelves.

**Files:**
- Create: `Daily Music/Views/Components/MonthShelvesView.swift`
- Modify: `Daily Music/Views/VaultView.swift` (`crateSection` uses `MonthShelvesView`; the `.crate` lens case scrolls)
- Delete: `Daily Music/Views/Components/CrateView.swift` (only referenced by `VaultView`)

- [ ] **Step 1: Create `MonthShelvesView`**

Create `Daily Music/Views/Components/MonthShelvesView.swift`:

```swift
//
//  MonthShelvesView.swift
//  Daily Music
//
//  The Crate browse (Vault redesign): a vertical scroll of month "shelves". Each
//  month is a shop-style divider header + a horizontally scrollable row of that
//  month's sleeves (newest-first). Vertical scroll travels back through time;
//  horizontal scroll digs a month — so going far back is a fling, not a marathon.
//  State is encoded entirely by each sleeve's treatment (SleeveView).
//

import SwiftUI

struct MonthShelvesView: View {
    let entries: [DailyEntry]            // newest first
    let missingVariant: MissingSleeveVariant
    let secondhandVariant: SecondhandVariant
    let status: (DailyEntry) -> ListenStatus
    let onSelect: (DailyEntry) -> Void
    let namespace: Namespace.ID

    private var sections: [CrateLayout.MonthSection] {
        CrateLayout.monthSections(for: entries)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl, pinnedViews: []) {
            ForEach(sections) { section in
                shelf(section)
            }
        }
    }

    private func shelf(_ section: CrateLayout.MonthSection) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Rectangle()
                    .fill(.secondary.opacity(0.25))
                    .frame(height: 1)
            }
            .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    ForEach(section.entries) { entry in
                        sleeve(entry)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func sleeve(_ entry: DailyEntry) -> some View {
        Button { onSelect(entry) } label: {
            VStack(spacing: 6) {
                SleeveView(entry: entry,
                           status: status(entry),
                           size: 132,
                           missingVariant: missingVariant,
                           secondhandVariant: secondhandVariant)
                Text(entry.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 132)
            }
        }
        .buttonStyle(PressableCardButtonStyle())
        .matchedTransitionSource(id: entry.id, in: namespace)
    }
}
```

- [ ] **Step 2: Point `VaultView.crateSection` at the new view and make the crate lens scroll**

In `Daily Music/Views/VaultView.swift`, replace the `crateSection` function with:

```swift
    /// The Crate: a vertical scroll of month shelves (Vault redesign §1).
    private func crateSection(_ entries: [DailyEntry]) -> some View {
        MonthShelvesView(
            entries: entries,
            missingVariant: env.variants.missingSleeve,
            secondhandVariant: env.variants.secondhand,
            status: { env.listensStore.status(for: $0) },
            onSelect: { openVaultEntry($0) },
            namespace: zoomNamespace
        )
    }
```

Then, in the `content(_:)` function, change the `.crate` switch case so the shelves scroll vertically. Replace the existing `case .crate:` block:

```swift
            case .crate:
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    vaultHeader(entries)
                    crateSection(entries)
                }
                .padding()
```

with:

```swift
            case .crate:
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        vaultHeader(entries)
                            .padding(.horizontal)
                        crateSection(entries)
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await model?.load()
                    reactions = (try? await env.reactions.myReactions()) ?? [:]
                    Haptics.tap()
                }
```

- [ ] **Step 3: Delete the obsolete coverflow**

```bash
git rm "Daily Music/Views/Components/CrateView.swift"
```

(`CrateFeel` stays in `VariantConfig.swift`; it is still used by the debug `VariantGalleryView`. The production Vault simply no longer consumes it.)

- [ ] **Step 4: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED. If the compiler reports `crateSection`'s old `.padding(.horizontal, -Theme.Spacing.md)` bleed or `lensHeader` references that no longer fit, none should remain — the only `crateSection` caller is the `.crate` case edited above.

- [ ] **Step 5: Visually verify in the simulator**

Launch the app (build command already installs to the iPhone 17 simulator; open the Vault tab). Confirm: months stack vertically with divider headers, each month's sleeves scroll horizontally, scrolling down reaches older months, and tapping a sleeve still zooms into the detail.

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Views/Components/MonthShelvesView.swift" "Daily Music/Views/VaultView.swift"
git commit -m "feat(vault): Month Shelves browse replaces the coverflow"
```

---

## Task 6: Calendar art-mosaic day cells

Replace the calendar's dot markers with the album cover in-state; today ringed, reactions badged, missed tappable.

**Files:**
- Modify: `Daily Music/Views/Components/CalendarMonthView.swift` (the `dayCell` entry branch, plus pass `missing`/`secondhand` variants through)
- Modify: `Daily Music/Views/VaultView.swift` (`calendarCard` passes the variants)

- [ ] **Step 1: Thread the sleeve variants into `CalendarMonthView`**

In `Daily Music/Views/Components/CalendarMonthView.swift`, add two stored properties and init params. Add after `private let statusForEntry: ((DailyEntry) -> ListenStatus)?`:

```swift
    private let missingVariant: MissingSleeveVariant
    private let secondhandVariant: SecondhandVariant
```

Update the `init` signature and body to accept and store them. Change the signature from:

```swift
    init(entries: [DailyEntry], reactions: [UUID: String] = [:],
         status: ((DailyEntry) -> ListenStatus)? = nil,
         onSelect: ((DailyEntry) -> Void)? = nil) {
```

to:

```swift
    init(entries: [DailyEntry], reactions: [UUID: String] = [:],
         status: ((DailyEntry) -> ListenStatus)? = nil,
         missingVariant: MissingSleeveVariant = .dusty,
         secondhandVariant: SecondhandVariant = .wornCornerStamp,
         onSelect: ((DailyEntry) -> Void)? = nil) {
```

and inside the init body, after `self.statusForEntry = status`, add:

```swift
        self.missingVariant = missingVariant
        self.secondhandVariant = secondhandVariant
```

- [ ] **Step 2: Render covers in the entry day cell**

In `CalendarMonthView.swift`, replace the entry branch of `dayCell(_:)` (the `if let entry = entriesByDay[...]` Button block) with:

```swift
        if let entry = entriesByDay[calendar.startOfDay(for: day)] {
            Button {
                onSelect?(entry)
            } label: {
                VStack(spacing: 2) {
                    SleeveView(
                        entry: entry,
                        status: statusForEntry?(entry) ?? .heardSameDay,
                        size: 40,
                        missingVariant: missingVariant,
                        secondhandVariant: secondhandVariant
                    )
                    .overlay(alignment: .topTrailing) {
                        if let emoji = reactionsByEntry[entry.id] {
                            Text(emoji)
                                .font(.system(size: 11))
                                .padding(1)
                                .background(Color(.systemBackground).opacity(0.85), in: Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                    .overlay {
                        if isToday(day) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 2)
                                .frame(width: 46, height: 46)
                        }
                    }
                    Text("\(number)")
                        .font(.caption2)
                        .foregroundStyle(isToday(day) ? Color.primary : Color.secondary)
                }
                .frame(width: 46, height: 60)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        } else {
```

(Leave the trailing `else { ... }` empty-day branch unchanged.)

- [ ] **Step 3: Update the grid row height for the taller cells**

In `CalendarMonthView.swift`, in `gridHeight(for:)`, change the per-row height from `40` to `60` and keep the `8` spacing:

```swift
    private func gridHeight(for visibleMonth: Date) -> CGFloat {
        let rowCount = ceil(Double(days(for: visibleMonth).count) / 7.0)
        return CGFloat(rowCount) * 60 + CGFloat(max(rowCount - 1, 0)) * 8
    }
```

Also bump the empty-cell spacer in `grid(for:)` from `height: 44` to `height: 60` so blank leading cells match:

```swift
                    Color.clear.frame(height: 60)   // leading blank to align the 1st
```

- [ ] **Step 4: Pass the variants from `VaultView.calendarCard`**

In `Daily Music/Views/VaultView.swift`, replace `calendarCard` with:

```swift
    // Vault redesign §3 — the calendar as an art mosaic (covers in-state).
    private func calendarCard(_ entries: [DailyEntry]) -> some View {
        CalendarMonthView(entries: entries, reactions: reactions,
                          status: { env.listensStore.status(for: $0) },
                          missingVariant: env.variants.missingSleeve,
                          secondhandVariant: env.variants.secondhand) { entry in
            openVaultEntry(entry)
        }
        .padding(Theme.Spacing.md)
        .glassCardStyle(tint: .teal.opacity(0.08))
    }
```

- [ ] **Step 5: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Visually verify in the simulator**

Open the Vault → Month lens. Confirm each entry day shows its cover in-state (mint crisp, worn ring-marked, dusty faded), today has an accent ring, a reacted day shows its emoji in the corner, and empty/future days show just the dimmed number.

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Views/Components/CalendarMonthView.swift" "Daily Music/Views/VaultView.swift"
git commit -m "feat(vault): calendar art-mosaic day cells"
```

---

## Task 7: Header redesign + nudge wiring

Rebuild the header as record-shop signage with the dynamic nudge and a Shelf/Month toggle.

**Files:**
- Modify: `Daily Music/Views/VaultView.swift` (`vaultHeader`, `collectionCountLine` → nudge, `lensHeader`, load the streak for the milestone nudge)

- [ ] **Step 1: Load the streak for the nudge**

The streak is not on `AppEnvironment`; it is computed from check-in dates (as `MainTabView` does at line 94: `Streak.compute(from: (try? await env.checkIns.checkInDates()) ?? [])`). Add a `@State` to hold it, near the other `@State` properties in `VaultView`:

```swift
    @State private var streak: Streak?
```

Then load it inside the existing `.task { ... }` block in `body`, after the `reactions = ...` line:

```swift
            streak = Streak.compute(from: (try? await env.checkIns.checkInDates()) ?? [])
```

- [ ] **Step 2: Replace the header builders**

In `Daily Music/Views/VaultView.swift`, replace `vaultHeader`, `collectionCountLine`, and `lensHeader` with:

```swift
    @ViewBuilder
    private func vaultHeader(_ entries: [DailyEntry]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("THE CRATE")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text("Your collection")
                    .font(.largeTitle.weight(.semibold))
                Spacer()
                shareButton(entries)
            }
            Text(nudgeLine(entries))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        lensHeader
    }

    /// Vault redesign §4 — the context-aware nudge under the title.
    private func nudgeLine(_ entries: [DailyEntry]) -> String {
        let rescuable = missedRecentEntries(entries).count
        let collectedToday = env.listensStore.collectedThisMonth() > 0
            && Calendar.current.isDate(
                env.listensStore.heardAt.values.max() ?? .distantPast,
                inSameDayAs: Date()
            )
        let started = env.listensStore.heardAt.values.min()
            .map { Calendar.current.dateInterval(of: .month, for: $0)?.start ?? $0 }
        return VaultNudge.line(
            total: env.listensStore.collectionCount,
            rescuable: rescuable,
            collectedToday: collectedToday,
            daysToNextMilestone: streak?.daysToNextMilestone,
            startedMonth: started
        )
    }

    /// Vault redesign §4 — the Shelf / Month lens toggle.
    private var lensHeader: some View {
        Picker("Lens", selection: $lens) {
            Text("Shelf").tag(VaultLens.crate)
            Text("Month").tag(VaultLens.calendar)
        }
        .pickerStyle(.segmented)
        .padding(.top, Theme.Spacing.xs)
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Visually verify**

Open the Vault. Confirm the header reads `THE CRATE` / `Your collection` with a nudge line beneath (no "this month" count), and the Shelf/Month segmented toggle switches lenses.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/VaultView.swift"
git commit -m "feat(vault): record-shop header with dynamic nudge and Shelf/Month toggle"
```

---

## Task 8: Collection share card

A high-res, shareable card showing a mosaic of recent covers + the collection count + the nudge line. Add a `shareButton` that presents it.

**Files:**
- Create: `Daily Music/Views/CollectionShareCard.swift`
- Modify: `Daily Music/Views/VaultView.swift` (add the `shareButton(_:)` builder + presenting state)

- [ ] **Step 1: Create the share card + sheet**

Create `Daily Music/Views/CollectionShareCard.swift` (mirrors `ShareCard.swift`'s `ImageRenderer` + `ShareLink` pattern — covers are pre-loaded `UIImage`s because `ImageRenderer` can't await downloads):

```swift
//
//  CollectionShareCard.swift
//  Daily Music
//
//  A shareable, story-shaped (9:16) card for the whole collection: a mosaic of
//  recent covers, the collection count, and the current nudge line. People
//  screenshot identity, not numbers — this is the organic acquisition loop
//  (Collection Redesign §4/§7). Mirrors ShareCard's ImageRenderer + ShareLink flow.
//

import SwiftUI

struct CollectionShareCardView: View {
    let count: Int
    let subtitle: String
    let covers: [UIImage]   // newest-first, pre-loaded; up to 9 used

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            mosaic
                .frame(width: 240, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)

            VStack(spacing: 6) {
                Text("\(count)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .opacity(0.85)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()

            VStack(spacing: 3) {
                Text("DAILY MUSIC")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(2)
                Text("my collection")
                    .font(.system(size: 12))
                    .opacity(0.8)
            }
            .padding(.bottom, 28)
        }
        .foregroundStyle(.white)
        .frame(width: 320, height: 568)
        .background(
            LinearGradient(
                colors: [Color(red: 0.16, green: 0.13, blue: 0.11),
                         Color(red: 0.10, green: 0.09, blue: 0.08),
                         .black],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private var mosaic: some View {
        let cells = Array(covers.prefix(9))
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(78), spacing: 3), count: 3),
                         spacing: 3) {
            ForEach(0..<9, id: \.self) { i in
                Group {
                    if i < cells.count {
                        Image(uiImage: cells[i]).resizable().scaledToFill()
                    } else {
                        Rectangle().fill(.white.opacity(0.08))
                    }
                }
                .frame(width: 78, height: 78)
                .clipped()
            }
        }
    }
}

/// Sheet that previews the collection card and offers the share action.
struct CollectionShareSheet: View {
    let count: Int
    let subtitle: String
    let covers: [UIImage]

    @Environment(\.dismiss) private var dismiss
    @State private var rendered: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                cardView
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .scaleEffect(0.82)
                    .frame(maxHeight: .infinity)

                if let rendered {
                    ShareLink(item: rendered,
                              preview: SharePreview("My collection", image: rendered)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    ProgressView().frame(height: 52)
                }
            }
            .padding()
            .navigationTitle("Share collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { render() }
    }

    private var cardView: CollectionShareCardView {
        CollectionShareCardView(count: count, subtitle: subtitle, covers: covers)
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3
        if let ui = renderer.uiImage { rendered = Image(uiImage: ui) }
    }
}
```

- [ ] **Step 2: Add the share button + state to `VaultView`**

In `Daily Music/Views/VaultView.swift`, add state near the other `@State` properties:

```swift
    @State private var showingCollectionShare = false
    @State private var shareCovers: [UIImage] = []
```

Add the builder (used by `vaultHeader` in Task 7):

```swift
    private func shareButton(_ entries: [DailyEntry]) -> some View {
        Button {
            Task { await prepareAndShowShare(entries) }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.title3)
        }
        .accessibilityLabel("Share your collection")
    }

    /// Pre-load up to 9 recent collected covers, then present the share sheet.
    private func prepareAndShowShare(_ entries: [DailyEntry]) async {
        let collected = entries.filter { env.listensStore.isHeard($0) }
        let urls = collected.prefix(9).compactMap(\.albumArtURL)
        var images: [UIImage] = []
        for url in urls {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        shareCovers = images
        showingCollectionShare = true
    }
```

Add the sheet presentation. Attach it alongside the existing `.fullScreenCover(item: $selectedVaultEntry)` in `content(_:)`:

```swift
        .sheet(isPresented: $showingCollectionShare) {
            CollectionShareSheet(
                count: env.listensStore.collectionCount,
                subtitle: nudgeLine(entries),
                covers: shareCovers
            )
        }
```

- [ ] **Step 3: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Visually verify**

Open the Vault, tap the share button in the header. Confirm a 9:16 card renders with a cover mosaic, the collection count, the nudge subtitle, and a working system Share sheet.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/CollectionShareCard.swift" "Daily Music/Views/VaultView.swift"
git commit -m "feat(vault): collection share card + header share button"
```

---

## Task 9: Remove the catch-up strip

Its job is now covered by the header nudge and the dusty in-grid sleeves. Delete the strip view and its call site; keep the underlying rescuable logic (the nudge + tab badge use it).

**Files:**
- Modify: `Daily Music/Views/VaultView.swift` (delete `CatchUpStrip` struct, `catchUpStrip(_:)`, and its call in `vaultHeader`)

- [ ] **Step 1: Remove the call site**

In `Daily Music/Views/VaultView.swift`, the `vaultHeader` from Task 7 already omits any `catchUpStrip(entries)` call — confirm there is no remaining `catchUpStrip(` invocation:

```bash
grep -n "catchUpStrip\|CatchUpStrip" "Daily Music/Views/VaultView.swift"
```

- [ ] **Step 2: Delete the strip code**

Delete the `private func catchUpStrip(_ entries:)` function and the entire `private struct CatchUpStrip: View { ... }` definition (including its `curatorSlot`, `title`, `subtitle`, `warmAccent` members) from `VaultView.swift`. Leave `missedRecentEntries(_:)` and `CatchUp.missedEntries` intact — the nudge (Task 7) and the tab badge depend on them.

- [ ] **Step 3: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED, with no "unused"/"unresolved" references to `CatchUpStrip` or `catchUpStrip`. Re-run the grep from Step 1 and expect no matches.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/VaultView.swift"
git commit -m "refactor(vault): remove catch-up strip (nudge + dusty sleeves cover it)"
```

---

## Task 10: Full regression — build, test, manual pass

- [ ] **Step 1: Run the full test suite**

Run the test command (no `-only-testing`). Expected: all tests PASS, including the existing `ListenStatusTests`, `SleeveTreatmentTests`, `CatchUpTests`, `VariantConfigTests`, `CrateLayoutTests`, and the new `CrateMonthSectionTests` + `VaultNudgeTests`.

- [ ] **Step 2: Confirm the legacy count-label test still holds**

`CrateLayoutTests` still covers `collectionCountLabel` (untouched — `VaultNudge` is additive, not a replacement of that function's tests). Confirm it passed in Step 1. No action unless it failed.

- [ ] **Step 3: Manual acceptance pass (simulator)**

Walk the spec's acceptance list in the running app:
- Browse scrolls vertically by month, horizontally within a month; older months reachable by a vertical fling.
- Secondhand sleeves read as worn at thumbnail size; missed sleeves show dusty real art + "Rescue" (never blank).
- Open a dusty (missed) record, tap the headphones to listen, return to the Vault, and confirm it now renders as secondhand (rescued).
- Calendar shows in-state covers, today ringed, reactions badged, empty days faint.
- Header shows `THE CRATE` / `Your collection` + a context nudge; no "this month" count; Shelf/Month toggle works; share card renders and shares.
- No catch-up strip; Vault tab badge still reflects rescuable drops.

- [ ] **Step 4: Final commit (if any manual-pass tweaks were needed)**

```bash
git add -A
git commit -m "test(vault): redesign regression pass"
```

(Skip if Steps 1–3 required no code changes.)

---

## Notes / out of scope

Monetization hooks (rescue passes, bulk restore, restoration cosmetics, Curator-framed paywall) are intentionally **not** built — see the design doc §7. The dusty state, Rescue affordance, and share card are built so those hooks can attach later without rework.
