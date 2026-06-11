# Archetype Driver Highlights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the taste mirror (Insights + friend mirrors), visually elevate the tiles/rows whose categories actually decided the archetype, using the already-computed `ArchetypeEvidence`.

**Architecture:** A new pure helper `DriverHighlights` maps `mirror.evidence` (top-3 facts by contribution) to `[dimensionID: DriverHighlight]`, suppressing highlights when the displayed (weekly-stable) archetype differs from the live winner. `TasteMirrorBoard` consumes that map: driver tiles get the driving category as headline, a badge, stronger tint and an accent ring; non-driver tiles recede; the genre secondary row gets the same treatment. No scorer changes.

**Tech Stack:** SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`), xcodebuild via CLI.

**Spec:** `docs/superpowers/specs/2026-06-10-archetype-driver-highlights-design.md`

---

## Project quirks (read first)

- `xcode-select` points at CommandLineTools. Every `xcodebuild` invocation MUST be prefixed with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- The **app target** (`Daily Music/`) is a file-system-synchronized group — new files auto-compile. The **test target** (`Daily MusicTests/`) is NOT — a new test *file* would require editing `project.pbxproj` in Xcode. Therefore the new tests go into the existing `Daily MusicTests/TasteMirrorTests.swift` as a second top-level struct. Do NOT create a new test file.
- If Xcode is open it keeps deleting `Package.resolved` from the working copy; ignore that file if it shows up in `git status` — never commit its deletion.

Build command (used throughout, run from the repo root):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Test command for just the new tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/DriverHighlightsTests" 2>&1 | tail -20
```

---

### Task 1: `DriverHighlights` pure helper (TDD)

**Files:**
- Create: `Daily Music/Models/DriverHighlights.swift`
- Modify (append): `Daily MusicTests/TasteMirrorTests.swift`

Background: `ArchetypeEvidence` (defined in `Daily Music/Models/ArchetypeAffinity.swift:84`) holds up to 3 `Fact`s, already sorted descending by `contribution`. Each fact has `dimensionID` ("mood" | "energy" | "theme" | "genre"), `category`, `likes`, `total`, `hearts`, `contribution`.

- [ ] **Step 1: Write the failing tests**

Append this struct at the END of `Daily MusicTests/TasteMirrorTests.swift` (after the closing brace of the file's last existing type):

```swift
// MARK: - DriverHighlights

struct DriverHighlightsTests {

    private func fact(_ dim: String, _ cat: String, contribution: Double) -> ArchetypeEvidence.Fact {
        .init(dimensionID: dim, category: cat, likes: 5, total: 6, hearts: 1, contribution: contribution)
    }

    @Test func mapsFactsToDimensionsWithContributionRanks() {
        let evidence = ArchetypeEvidence(facts: [
            fact("mood", "Dark", contribution: 0.30),
            fact("theme", "Loneliness", contribution: 0.20),
            fact("genre", "Rock", contribution: 0.10),
        ])
        let h = DriverHighlights.compute(
            evidence: evidence, displayedArchetypeID: "outsider", liveArchetypeID: "outsider")
        #expect(h.count == 3)
        #expect(h["mood"]?.rank == 1)
        #expect(h["mood"]?.fact.category == "Dark")
        #expect(h["theme"]?.rank == 2)
        #expect(h["genre"]?.rank == 3)
        #expect(h["energy"] == nil)
    }

    @Test func firstFactPerDimensionWins() {
        // Two moods in evidence: the higher-contribution one (sorted first) keeps the slot.
        let evidence = ArchetypeEvidence(facts: [
            fact("mood", "Dark", contribution: 0.30),
            fact("mood", "Melancholy", contribution: 0.20),
        ])
        let h = DriverHighlights.compute(
            evidence: evidence, displayedArchetypeID: "outsider", liveArchetypeID: "outsider")
        #expect(h.count == 1)
        #expect(h["mood"]?.fact.category == "Dark")
        #expect(h["mood"]?.rank == 1)
    }

    @Test func emptyOrNilEvidenceYieldsNoHighlights() {
        #expect(DriverHighlights.compute(
            evidence: nil, displayedArchetypeID: "outsider", liveArchetypeID: "outsider").isEmpty)
        #expect(DriverHighlights.compute(
            evidence: ArchetypeEvidence(facts: []),
            displayedArchetypeID: "outsider", liveArchetypeID: "outsider").isEmpty)
    }

    @Test func suppressedWhenDisplayedArchetypeDiffersFromLiveWinner() {
        // The weekly-stable archetype lags the live winner → badges would explain
        // an archetype the user isn't seeing. Suppress.
        let evidence = ArchetypeEvidence(facts: [fact("mood", "Dark", contribution: 0.30)])
        let h = DriverHighlights.compute(
            evidence: evidence, displayedArchetypeID: "pophead", liveArchetypeID: "outsider")
        #expect(h.isEmpty)
    }

    @Test func suppressedWhenNoDisplayedArchetype() {
        let evidence = ArchetypeEvidence(facts: [fact("mood", "Dark", contribution: 0.30)])
        #expect(DriverHighlights.compute(
            evidence: evidence, displayedArchetypeID: nil, liveArchetypeID: "outsider").isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the test command from "Project quirks".
Expected: BUILD FAILS with "cannot find 'DriverHighlights' in scope" (a compile failure is the failing state here).

- [ ] **Step 3: Write the implementation**

Create `Daily Music/Models/DriverHighlights.swift`:

```swift
//
//  DriverHighlights.swift
//  Daily Music
//
//  Maps archetype evidence onto the taste-mirror board: which dimensions drove
//  the displayed archetype, at what rank. Evidence only explains the LIVE
//  winning archetype — when the displayed (weekly-stable) archetype lags it,
//  highlights are suppressed rather than explaining something the user can't see.
//

import Foundation

/// One dimension's claim to having shaped the archetype.
struct DriverHighlight: Equatable {
    /// 1-based position among the evidence facts (1 = biggest contribution).
    let rank: Int
    let fact: ArchetypeEvidence.Fact
}

enum DriverHighlights {
    /// Facts arrive sorted descending by contribution; the first fact per
    /// dimension keeps the slot, ranked by overall position.
    static func compute(
        evidence: ArchetypeEvidence?,
        displayedArchetypeID: String?,
        liveArchetypeID: String?
    ) -> [String: DriverHighlight] {
        guard let evidence,
              let displayedArchetypeID,
              displayedArchetypeID == liveArchetypeID else { return [:] }
        var out: [String: DriverHighlight] = [:]
        for (index, fact) in evidence.facts.enumerated() where out[fact.dimensionID] == nil {
            out[fact.dimensionID] = DriverHighlight(rank: index + 1, fact: fact)
        }
        return out
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the test command again.
Expected: `Test Suite 'DriverHighlightsTests' passed` / `** TEST SUCCEEDED **` with 5 passing tests.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/DriverHighlights.swift" "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat(insights): DriverHighlights — evidence→dimension map with live-winner guard"
```

---

### Task 2: Driver styling for the 2×2 tile grid

**Files:**
- Modify: `Daily Music/Views/Components/TasteMirrorBoard.swift`

This is SwiftUI styling — no unit tests; verified by building + Task 4's manual pass. All edits below are in `TasteMirrorBoard.swift`. Line numbers reference the file as of commit `e0f189e`.

- [ ] **Step 1: Compute highlights once**

Below the `currentArchetypeID` property (~line 32), add:

```swift
    /// Driver map for the displayed archetype; empty while forming, for the
    /// Shapeshifter, or when the stable archetype lags the live winner.
    private var highlights: [String: DriverHighlight] {
        DriverHighlights.compute(
            evidence: mirror.evidence,
            displayedArchetypeID: currentArchetypeID,
            liveArchetypeID: mirror.archetype?.id
        )
    }
```

- [ ] **Step 2: Pass highlights into the grid**

In `body`, replace the `LazyVGrid` block (the four tile calls keep their existing `EntranceModifier`s — only the function-call lines change):

```swift
            let highlights = self.highlights
            let anyHighlights = !highlights.isEmpty

            // ── Act 2: Tile grid — staggered spring pop ──
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)], spacing: 14) {
                marqueeTile(mirror.mood,   lead: "Mood",   accent: accent,
                            highlight: highlights["mood"], anyHighlights: anyHighlights)
                    .modifier(EntranceModifier(
                        appeared: appeared, reduceMotion: reduceMotion,
                        scale: 0.80, offsetY: 16, delay: 0.10,
                        response: 0.44, damping: 0.56
                    ))
                marqueeTile(mirror.decade, lead: "Era",    accent: accent,
                            highlight: nil, anyHighlights: anyHighlights)
                    .modifier(EntranceModifier(
                        appeared: appeared, reduceMotion: reduceMotion,
                        scale: 0.80, offsetY: 16, delay: 0.16,
                        response: 0.44, damping: 0.56
                    ))
                marqueeTile(mirror.theme,  lead: "Theme",  accent: accent,
                            highlight: highlights["theme"], anyHighlights: anyHighlights)
                    .modifier(EntranceModifier(
                        appeared: appeared, reduceMotion: reduceMotion,
                        scale: 0.80, offsetY: 16, delay: 0.22,
                        response: 0.44, damping: 0.56
                    ))
                energyTile(mirror.energy, accent: accent,
                           highlight: highlights["energy"], anyHighlights: anyHighlights)
                    .modifier(EntranceModifier(
                        appeared: appeared, reduceMotion: reduceMotion,
                        scale: 0.80, offsetY: 16, delay: 0.28,
                        response: 0.44, damping: 0.56
                    ))
            }
```

(Era is hardwired `highlight: nil` — decade isn't a scorer input, but it still recedes via `anyHighlights` like other non-drivers.)

In the same `body`, update the genre row call (language stays as-is — it defaults to no highlight after Task 3 adds the parameter with a default):

```swift
            secondaryRow(mirror.genre,    lead: "Genre",    accent: accent,
                         highlight: highlights["genre"])
```

- [ ] **Step 3: Rewrite the tile builders**

Replace `marqueeTile`, `energyTile`, `tile`, and `tileVisual` (currently lines 173–231) with:

```swift
    @ViewBuilder
    private func marqueeTile(_ dim: DimensionInsight, lead: String, accent: Color,
                             highlight: DriverHighlight?, anyHighlights: Bool) -> some View {
        if dim.isUnlocked, let s = dim.topStandout {
            // A driver tile headlines the category that shaped the archetype,
            // which may differ from the dimension's own standout. Heart-only
            // driver categories can be absent from the tile data — fall back
            // to the standout name (badge stays).
            let driverStat = highlight.flatMap { h in dim.categories.first { $0.name == h.fact.category } }
            let headline = driverStat?.name ?? s.name
            tile(lead: lead,
                 headline: headline,
                 icon: categorySymbol(dim.id, headline) ?? dimIcon(dim.id),
                 accent: accent,
                 highlight: highlight,
                 receded: highlight == nil && anyHighlights,
                 onTap: isCurrentUser ? { detail = makeDetail(dim: dim, accent: accent, featured: driverStat) } : nil)
        } else {
            lockedTile(lead: lead, icon: dimIcon(dim.id))
        }
    }

    @ViewBuilder
    private func energyTile(_ energy: EnergyInsight, accent: Color,
                            highlight: DriverHighlight?, anyHighlights: Bool) -> some View {
        if energy.isUnlocked, let lean = energy.leanLabel {
            // When energy drove the archetype, headline the driving band itself
            // ("High energy"), not the mean-based lean label.
            let headline = highlight.map { "\($0.fact.category) energy" } ?? lean
            tile(lead: "Energy", headline: headline, icon: "bolt.fill", accent: accent,
                 highlight: highlight, receded: highlight == nil && anyHighlights,
                 onTap: isCurrentUser ? { detail = makeEnergyDetail(energy, accent: accent) } : nil)
        } else {
            lockedTile(lead: "Energy", icon: "bolt.fill")
        }
    }

    /// A standout tile. `onTap == nil` renders it inert (a friend's read-only mirror):
    /// no button, and non-interactive glass so it doesn't invite a tap.
    /// Drivers get a louder tint + accent ring; when any driver is showing,
    /// the rest recede so the hierarchy reads at a glance.
    @ViewBuilder
    private func tile(lead: String, headline: String, icon: String,
                      accent: Color, highlight: DriverHighlight?, receded: Bool,
                      onTap: (() -> Void)?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let tint = accent.opacity(highlight != nil ? 0.30 : (receded ? 0.10 : 0.16))
        let visual = tileVisual(lead: lead, headline: headline, icon: icon,
                                accent: accent, highlight: highlight, receded: receded)
            .overlay {
                if highlight != nil {
                    shape.strokeBorder(accent.opacity(0.5), lineWidth: 1)
                }
            }
        if let onTap {
            Button(action: onTap) { visual }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(tint).interactive(), in: shape)
        } else {
            visual
                .glassEffect(.regular.tint(tint), in: shape)
        }
    }

    private func tileVisual(lead: String, headline: String, icon: String, accent: Color,
                            highlight: DriverHighlight?, receded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 40, height: 40)
                    .background(accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Spacer(minLength: 0)
                if let highlight {
                    driverBadge(highlight, accent: accent)
                }
            }
            Spacer(minLength: 0)
            Text(lead.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(accent.opacity(0.85))
            Text(headline)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(receded ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(Theme.Spacing.md)
    }

    /// The "this shaped your archetype" pill: rank 1 gets the number, the rest
    /// just the claim (a leaderboard of #2/#3 would read as noise).
    private func driverBadge(_ highlight: DriverHighlight, accent: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 8, weight: .black))
            Text(highlight.rank == 1 ? "#1" : "SHAPED YOU")
                .font(.system(size: 9, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(accent, in: Capsule())
    }
```

Note: `lockedTile` is unchanged. `secondaryRow` doesn't compile yet against the new genre call — Task 3 fixes it; Tasks 2+3 build together (single build at the end of Task 3).

- [ ] **Step 4: Proceed to Task 3 before building** (the genre call site now passes a `highlight:` argument that `secondaryRow` doesn't accept yet).

---

### Task 3: Driver styling for the genre row + build + commit

**Files:**
- Modify: `Daily Music/Views/Components/TasteMirrorBoard.swift` (the `secondaryRow` function, currently lines 254–288)

- [ ] **Step 1: Rewrite `secondaryRow`**

```swift
    @ViewBuilder
    private func secondaryRow(_ dim: DimensionInsight, lead: String, accent: Color,
                              highlight: DriverHighlight? = nil) -> some View {
        if dim.isUnlocked, let s = dim.dominant {
            // Genre can drive the archetype (e.g. The Pophead): show the driving
            // category and the same badge the tiles use. Language never gets one.
            let driverStat = highlight.flatMap { h in dim.categories.first { $0.name == h.fact.category } }
            let shown = driverStat ?? s
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            let row = HStack(spacing: Theme.Spacing.md) {
                Image(systemName: dimIcon(dim.id))
                    .font(.headline)
                    .foregroundStyle(accent)
                    .frame(width: 26)
                Text(lead)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let highlight {
                    driverBadge(highlight, accent: accent)
                }
                Spacer()
                Text(shown.name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                // Chevron only when it's actually tappable (your own mirror).
                if isCurrentUser {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 15)
            .overlay {
                if highlight != nil {
                    shape.strokeBorder(accent.opacity(0.5), lineWidth: 1)
                }
            }

            if isCurrentUser {
                Button { detail = makeDetail(dim: dim, accent: accent, featured: shown) } label: { row }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: shape)
            } else {
                row.glassEffect(.regular, in: shape)
            }
        }
    }
```

- [ ] **Step 2: Build**

Run the build command from "Project quirks".
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run the full test suite** (board is shared with friend mirrors; make sure nothing else regressed)

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/Components/TasteMirrorBoard.swift"
git commit -m "feat(insights): driver tiles — badge, accent ring, headline swap; non-drivers recede"
```

---

### Task 4: Manual verification + docs

**Files:**
- Modify: `docs/ARCHITECTURE.md` (the user keeps this map current with code changes)

- [ ] **Step 1: Manual simulator pass**

Launch in the iPhone 17 simulator (or ask the user to run from Xcode) and check, on the Insights tab:
1. With an unlocked archetype: 1–3 tiles/rows carry the ★ badge; the #1 driver reads `★ #1`; badged tiles are visibly stronger (tint + ring) and the rest are dimmer.
2. Tapping a badged tile opens the detail sheet with the *driver* category featured.
3. Friends tab → a friend's mirror: badges render, tiles stay non-interactive.
4. Fresh/forming state (< 10 ratings) and Shapeshifter: board looks exactly like before — no badges, no recede.

- [ ] **Step 2: Update `docs/ARCHITECTURE.md`**

Add `DriverHighlights.swift` to the Models section: one line, e.g. "`DriverHighlights` — maps `ArchetypeEvidence` facts to per-dimension badge ranks for the taste-mirror board; suppressed when the stable archetype lags the live winner."

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs: architecture map — driver highlights"
```
