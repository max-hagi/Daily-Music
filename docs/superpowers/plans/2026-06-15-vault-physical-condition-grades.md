# Vault Physical Condition Grades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Vault sleeves read as physical record-condition grades: mint pristine, secondhand proudly used with a worn protruding disc, salvaged rougher with more exposed worn vinyl, and Rescue unchanged.

**Architecture:** Keep all status derivation untouched. The visual change lives in `SleeveView`, which already centralizes sleeve treatment for shelves and the calendar mosaic. Add small private visual helpers inside `SleeveView` so the rest of the Vault continues passing `ListenStatus` and variants the same way.

**Tech Stack:** SwiftUI, Swift Testing, existing `Daily Music` Xcode project.

---

## File Structure

- Modify: `Daily Music/Views/Components/SleeveView.swift`
  - Add a private `VinylCondition` enum scoped to this file.
  - Replace the single `disc` helper with condition-aware vinyl helpers.
  - Update `mintSleeve`, `secondhandSleeve`, and `salvagedSleeve`.
  - Leave `missingSleeve` / `dustyArt` / `rescueBadge` unchanged except for previews.
- Modify: `Daily MusicTests/CatchUpTests.swift`
  - Add one regression assertion proving collected/missed treatment mapping remains unchanged. This is intentionally semantic, not visual.
- No changes: `VaultView`, `MonthShelvesView`, `CalendarMonthView`
  - They already render `SleeveView`; the new visuals flow through automatically.

## Scope Check

This plan implements one visual subsystem: sleeve condition language. It does not change navigation, tracking semantics, collection counts, share cards, tab badges, or Vault layout.

---

### Task 1: Add a semantic regression test for treatment mapping

**Files:**
- Modify: `Daily MusicTests/CatchUpTests.swift`

- [ ] **Step 1: Add the failing/guarding test**

In `Daily MusicTests/CatchUpTests.swift`, inside `struct SleeveTreatmentTests`, after `missedIsMissing()`, add:

```swift
    @Test func physicalConditionGradesKeepCollectedStatesSeparateFromRescue() {
        // The physical condition redesign is visual-only. These mappings must stay
        // stable so Rescue remains an invitation and collected states stay collected.
        #expect(SleeveTreatment(.heardSameDay) == .mint)
        #expect(SleeveTreatment(.caughtUp) == .secondhand)
        #expect(SleeveTreatment(.rescued) == .salvaged)
        #expect(SleeveTreatment(.missed) == .missing)
        #expect(SleeveTreatment(.rescuable) == .pending)
    }
```

- [ ] **Step 2: Run the focused tests**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:Daily_MusicTests/CatchUpTests
```

Expected: PASS. This test should pass before visual implementation because the logic is already correct. If the simulator name is unavailable locally, run the same command with an installed iPhone simulator from `xcrun simctl list devices available`.

- [ ] **Step 3: Commit**

```bash
git add "Daily MusicTests/CatchUpTests.swift"
git commit -m "test(vault): guard physical condition tier semantics"
```

---

### Task 2: Add condition-aware vinyl helpers

**Files:**
- Modify: `Daily Music/Views/Components/SleeveView.swift`

- [ ] **Step 1: Add the local condition enum**

In `Daily Music/Views/Components/SleeveView.swift`, directly below the `import SwiftUI` line, add:

```swift
private enum VinylCondition {
    case mint
    case secondhand
    case salvaged
}
```

- [ ] **Step 2: Replace `disc` with condition-aware helpers**

In `Daily Music/Views/Components/SleeveView.swift`, replace the existing `disc` computed property with this block:

```swift
    /// A vinyl disc that peeks above the sleeve. Mint is clean; late-collected
    /// records use the same physical object with increasing wear.
    private func disc(_ condition: VinylCondition = .mint) -> some View {
        let d = discDiameter(for: condition)
        return ZStack {
            Circle().fill(discBase(for: condition))
            grooveRings(for: condition)
            scratchMarks(for: condition)
            Circle()
                .fill(centerLabelFill(for: condition))
                .frame(width: d * 0.34, height: d * 0.34)
            Circle()
                .fill(Color.black.opacity(condition == .mint ? 1 : 0.82))
                .frame(width: d * 0.08, height: d * 0.08)
        }
        .frame(width: d, height: d)
        .overlay(Circle().strokeBorder(.white.opacity(borderOpacity(for: condition)), lineWidth: 0.5))
        .offset(x: discOffset(for: condition).x, y: discOffset(for: condition).y)
        .rotationEffect(.degrees(rotation(for: condition)))
    }

    private func discDiameter(for condition: VinylCondition) -> CGFloat {
        switch condition {
        case .mint: coverSide * 0.86
        case .secondhand: coverSide * 0.9
        case .salvaged: coverSide * 0.98
        }
    }

    private func discOffset(for condition: VinylCondition) -> CGSize {
        let d = discDiameter(for: condition)
        switch condition {
        case .mint:
            return CGSize(width: 0, height: -(size - d) / 2)
        case .secondhand:
            return CGSize(width: coverSide * 0.08, height: -(size - d) / 2 + coverSide * 0.08)
        case .salvaged:
            return CGSize(width: coverSide * 0.14, height: -(size - d) / 2 + coverSide * 0.14)
        }
    }

    private func discBase(for condition: VinylCondition) -> Color {
        switch condition {
        case .mint: Color.black.opacity(0.85)
        case .secondhand: Color(red: 0.07, green: 0.07, blue: 0.065).opacity(0.9)
        case .salvaged: Color(red: 0.09, green: 0.08, blue: 0.07).opacity(0.94)
        }
    }

    private func centerLabelFill(for condition: VinylCondition) -> Color {
        switch condition {
        case .mint: Color(.systemGray3)
        case .secondhand: Color(red: 0.68, green: 0.64, blue: 0.55).opacity(0.82)
        case .salvaged: Color(red: 0.62, green: 0.55, blue: 0.42).opacity(0.78)
        }
    }

    private func borderOpacity(for condition: VinylCondition) -> CGFloat {
        switch condition {
        case .mint: 0.07
        case .secondhand: 0.1
        case .salvaged: 0.14
        }
    }

    private func rotation(for condition: VinylCondition) -> Double {
        switch condition {
        case .mint: 0
        case .secondhand: -3
        case .salvaged: 5
        }
    }

    @ViewBuilder
    private func grooveRings(for condition: VinylCondition) -> some View {
        let d = discDiameter(for: condition)
        ZStack {
            Circle().stroke(.white.opacity(condition == .mint ? 0.04 : 0.08), lineWidth: 0.5)
                .frame(width: d * 0.72, height: d * 0.72)
            Circle().stroke(.white.opacity(condition == .salvaged ? 0.08 : 0.05), lineWidth: 0.5)
                .frame(width: d * 0.56, height: d * 0.56)
            if condition != .mint {
                Circle().stroke(.black.opacity(0.18), lineWidth: 1)
                    .frame(width: d * 0.82, height: d * 0.82)
            }
        }
    }

    @ViewBuilder
    private func scratchMarks(for condition: VinylCondition) -> some View {
        let d = discDiameter(for: condition)
        if condition != .mint {
            ZStack {
                Capsule()
                    .fill(.white.opacity(condition == .salvaged ? 0.18 : 0.1))
                    .frame(width: d * 0.42, height: 1)
                    .rotationEffect(.degrees(-24))
                    .offset(x: d * 0.08, y: -d * 0.18)
                Capsule()
                    .fill(.black.opacity(condition == .salvaged ? 0.22 : 0.12))
                    .frame(width: d * 0.38, height: 1)
                    .rotationEffect(.degrees(18))
                    .offset(x: -d * 0.12, y: d * 0.16)
                if condition == .salvaged {
                    Capsule()
                        .fill(.white.opacity(0.14))
                        .frame(width: d * 0.52, height: 1)
                        .rotationEffect(.degrees(42))
                        .offset(x: d * 0.02, y: d * 0.04)
                }
            }
        }
    }
```

- [ ] **Step 3: Build to catch SwiftUI type errors**

Run:

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS. If it fails because the simulator name is unavailable, choose an installed iPhone simulator with `xcrun simctl list devices available` and rerun.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/Components/SleeveView.swift"
git commit -m "feat(vault): add condition-aware vinyl discs"
```

---

### Task 3: Give secondhand a worn protruding record

**Files:**
- Modify: `Daily Music/Views/Components/SleeveView.swift`

- [ ] **Step 1: Update mint to call the new helper**

In `mintSleeve`, replace:

```swift
            disc
```

with:

```swift
            disc(.mint)
```

- [ ] **Step 2: Replace `secondhandSleeve`**

In `Daily Music/Views/Components/SleeveView.swift`, replace the entire `secondhandSleeve` computed property with:

```swift
    private var secondhandSleeve: some View {
        let muted = secondhandVariant == .mutingOnly
        return ZStack {
            disc(.secondhand)
            artCover
                .saturation(muted ? 0.4 : 0.58)
                .brightness(muted ? -0.05 : -0.035)
                .overlay { ringWear }
                .overlay { scuffs }
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
    }
```

- [ ] **Step 3: Build**

Run:

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 4: Visual check in Xcode previews or simulator**

Open the `#Preview("Sleeve states")` canvas or run the app and view the Vault shelf. Confirm:

- Mint has the clean protruding disc.
- Secondhand now also has a protruding disc.
- Secondhand disc is lower/side-shifted and visibly less pristine than mint.
- Rescue/missed still has no protruding disc.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/Components/SleeveView.swift"
git commit -m "feat(vault): make secondhand records visibly used"
```

---

### Task 4: Make salvaged the roughest collected condition

**Files:**
- Modify: `Daily Music/Views/Components/SleeveView.swift`

- [ ] **Step 1: Replace `salvagedSleeve`**

In `Daily Music/Views/Components/SleeveView.swift`, replace the entire `salvagedSleeve` computed property with:

```swift
    private var salvagedSleeve: some View {
        ZStack {
            disc(.salvaged)
            artCover
                .saturation(0.34)
                .brightness(-0.08)
                .overlay { ringWear }
                .overlay { creases }
                .overlay(alignment: .topLeading) { tape }
                .overlay(alignment: .topTrailing) { dogEar }
                .overlay(alignment: .bottom) { salvagedLabel }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .rotationEffect(.degrees(-1.5))
                .offset(y: coverDrop)
        }
    }
```

- [ ] **Step 2: Strengthen salvage-only surface wear**

Replace the existing `creases` computed property with:

```swift
    /// Sharper, more numerous fold lines than secondhand's faint scuffs.
    private var creases: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.18))
                .frame(width: coverSide, height: 1)
                .rotationEffect(.degrees(-24))
                .offset(y: -coverSide * 0.12)
            Rectangle().fill(.white.opacity(0.13))
                .frame(width: coverSide, height: 1)
                .rotationEffect(.degrees(-24))
                .offset(y: -coverSide * 0.1)
            Rectangle().fill(.black.opacity(0.16))
                .frame(width: coverSide, height: 1)
                .rotationEffect(.degrees(18))
                .offset(x: coverSide * 0.05, y: coverSide * 0.2)
            Rectangle().fill(.black.opacity(0.12))
                .frame(width: coverSide * 0.8, height: 1)
                .rotationEffect(.degrees(42))
                .offset(x: -coverSide * 0.08, y: coverSide * 0.02)
        }
    }
```

- [ ] **Step 3: Build**

Run:

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 4: Visual check in Xcode previews or simulator**

Confirm:

- Salvaged shows more vinyl than secondhand.
- Salvaged disc has stronger scratches/grooves.
- Salvaged is rougher than secondhand but album art remains identifiable.
- Rescue/missed still reads as dusty invitation, not salvaged.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/Components/SleeveView.swift"
git commit -m "feat(vault): expose rough salvaged vinyl"
```

---

### Task 5: Update previews so the states can be reviewed quickly

**Files:**
- Modify: `Daily Music/Views/Components/SleeveView.swift`

- [ ] **Step 1: Replace the debug previews**

Replace the `#Preview("Sleeve states")`, `#Preview("Missing variants")`, and `#Preview("Secondhand variants")` blocks with:

```swift
#Preview("Sleeve states") {
    HStack(spacing: 18) {
        VStack { SleeveView(entry: .preview(1), status: .unheard, size: 84); Text("pending").font(.caption2) }
        VStack { SleeveView(entry: .preview(2), status: .heardSameDay, size: 84); Text("mint").font(.caption2) }
        VStack { SleeveView(entry: .preview(3), status: .caughtUp, size: 84); Text("secondhand").font(.caption2) }
        VStack { SleeveView(entry: .preview(4), status: .rescued, size: 84); Text("salvaged").font(.caption2) }
        VStack { SleeveView(entry: .preview(5), status: .missed, size: 84); Text("rescue").font(.caption2) }
    }
    .padding()
}

#Preview("Shelf size condition grades") {
    HStack(spacing: 18) {
        SleeveView(entry: .preview(1), status: .heardSameDay, size: 132)
        SleeveView(entry: .preview(2), status: .caughtUp, size: 132)
        SleeveView(entry: .preview(3), status: .rescued, size: 132)
        SleeveView(entry: .preview(4), status: .missed, size: 132)
    }
    .padding()
}

#Preview("Missing variants") {
    HStack(spacing: 18) {
        SleeveView(entry: .preview(1), status: .missed, size: 90, missingVariant: .dusty)
        SleeveView(entry: .preview(2), status: .missed, size: 90, missingVariant: .blank)
        SleeveView(entry: .preview(3), status: .missed, size: 90, missingVariant: .ghost)
    }
    .padding()
}

#Preview("Secondhand variants") {
    HStack(spacing: 18) {
        SleeveView(entry: .preview(1), status: .caughtUp, size: 90, secondhandVariant: .wornCornerStamp)
        SleeveView(entry: .preview(2), status: .caughtUp, size: 90, secondhandVariant: .mutingOnly)
        SleeveView(entry: .preview(3), status: .caughtUp, size: 90, secondhandVariant: .edgeLabel)
    }
    .padding()
}
```

- [ ] **Step 2: Build**

Run:

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Components/SleeveView.swift"
git commit -m "chore(vault): preview physical condition grades"
```

---

### Task 6: Final verification

**Files:**
- Verify: `Daily Music/Views/Components/SleeveView.swift`
- Verify: `Daily Music/Views/Components/CalendarMonthView.swift`
- Verify: `Daily Music/Views/Components/MonthShelvesView.swift`
- Verify: `Daily MusicTests/CatchUpTests.swift`

- [ ] **Step 1: Run focused semantic tests**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:Daily_MusicTests/CatchUpTests
```

Expected: PASS.

- [ ] **Step 2: Run a build**

Run:

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 3: Manual visual QA**

Open the app or Xcode previews and inspect both shelf and calendar sizes:

- Mint: clean protruding record, crisp art.
- Secondhand: protruding worn record, ring wear, dog-ear/stamp when `wornCornerStamp`.
- Salvaged: more exposed rough record, repair tape, creases, label, still identifiable art.
- Rescue/missed: dusty art with Rescue badge, no protruding disc.
- Calendar: compact sleeves remain legible and do not overlap day numbers or emoji reaction badges.

- [ ] **Step 4: Commit any final polish**

If manual QA required spacing/opacity tweaks, commit them:

```bash
git add "Daily Music/Views/Components/SleeveView.swift" "Daily MusicTests/CatchUpTests.swift"
git commit -m "polish(vault): tune physical condition grade sleeves"
```

If no final polish was needed, do not create an empty commit.
