# Driver-First Insights Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the taste mirror so the archetype's actual drivers dominate by size (one big card + up to two half-cards), everything else demotes to quiet rows, the page declutters, and the entrance choreography is archetype-flavored with a one-shot reward beat.

**Architecture:** Two new pure helpers — `driverReceiptCopy` (fact → receipt sentence, in `ArchetypeCopy.swift`) and `BoardEntranceFlavor` (flare `LightStyle` → bloom parameters, new file) — plus a one-beat `Haptics.driverReward`. `TasteMirrorBoard` is rewritten wholesale (grid/tiles/badges/dimming deleted); `InsightsView` reorders the page and feeds replay/countdown into the hero. `DriverHighlights` from the previous feature is reused unchanged.

**Tech Stack:** SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`), xcodebuild via CLI.

**Spec:** `docs/superpowers/specs/2026-06-11-driver-first-insights-design.md`

---

## Project quirks (read first)

- `xcode-select` points at CommandLineTools. Every `xcodebuild` invocation MUST be prefixed with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- The **app target** (`Daily Music/`) is file-system-synchronized — new files auto-compile. The **test target** (`Daily MusicTests/`) is NOT — never create new test files; append test structs to existing files as instructed below.
- If Xcode is open it keeps deleting `Package.resolved`; ignore it in `git status`, never commit its deletion.
- Animation timings in Task 4 are starting values — the user tunes them in the simulator afterwards; don't bikeshed them.

Build command (repo root):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | grep -E "error|BUILD" | head -5
```

Test command template (swap the `-only-testing` suite name):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/DriverReceiptCopyTests" 2>&1 \
  | grep -E "Suite|Test run|TEST (SUCCEEDED|FAILED)|✘|error" | head -15
```

---

### Task 1: `driverReceiptCopy` (TDD)

**Files:**
- Modify: `Daily Music/Views/Components/ArchetypeCopy.swift` (append at end)
- Test: `Daily MusicTests/ArchetypeCopyTests.swift` (append at end)

- [ ] **Step 1: Write the failing tests**

Append at the END of `Daily MusicTests/ArchetypeCopyTests.swift`:

```swift
// MARK: - Driver receipt copy

struct DriverReceiptCopyTests {

    private func fact(dim: String = "mood", cat: String = "Dark",
                      likes: Int, total: Int, hearts: Int) -> ArchetypeEvidence.Fact {
        .init(dimensionID: dim, category: cat, likes: likes, total: total,
              hearts: hearts, contribution: 0.2)
    }

    @Test func thumbedCounts() {
        #expect(driverReceiptCopy(fact: fact(likes: 8, total: 10, hearts: 0), isCurrentUser: true)
                == "You liked 8 of 10 Dark picks")
    }

    @Test func heartsSuffix() {
        #expect(driverReceiptCopy(fact: fact(likes: 8, total: 10, hearts: 3), isCurrentUser: true)
                == "You liked 8 of 10 Dark picks — 3 hearted")
    }

    @Test func heartOnly() {
        #expect(driverReceiptCopy(fact: fact(likes: 0, total: 0, hearts: 3), isCurrentUser: true)
                == "3 hearts on Dark picks")
    }

    @Test func singleHeartOnly() {
        #expect(driverReceiptCopy(fact: fact(likes: 0, total: 0, hearts: 1), isCurrentUser: true)
                == "1 heart on Dark picks")
    }

    @Test func degenerateFallback() {
        #expect(driverReceiptCopy(fact: fact(likes: 0, total: 0, hearts: 0), isCurrentUser: true)
                == "Dark picks shaped this")
    }

    @Test func friendVariant() {
        #expect(driverReceiptCopy(fact: fact(likes: 8, total: 10, hearts: 0), isCurrentUser: false)
                == "They liked 8 of 10 Dark picks")
    }

    @Test func themePhrasing() {
        #expect(driverReceiptCopy(fact: fact(dim: "theme", cat: "Loneliness", likes: 5, total: 6, hearts: 0), isCurrentUser: true)
                == "You liked 5 of 6 songs about loneliness")
    }

    @Test func energyPhrasing() {
        #expect(driverReceiptCopy(fact: fact(dim: "energy", cat: "High", likes: 5, total: 6, hearts: 0), isCurrentUser: true)
                == "You liked 5 of 6 High energy picks")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the test command with `-only-testing:"Daily MusicTests/DriverReceiptCopyTests"`.
Expected: BUILD FAILS with "cannot find 'driverReceiptCopy' in scope".

- [ ] **Step 3: Write the implementation**

Append at the END of `Daily Music/Views/Components/ArchetypeCopy.swift`:

```swift
/// One driver card's receipt line: real counts for the category that pushed
/// the archetype. Unlike `archetypeReceiptsCopy`, this is per-fact and never
/// nil — driver cards always have something honest to say.
func driverReceiptCopy(fact: ArchetypeEvidence.Fact, isCurrentUser: Bool) -> String {
    let You = isCurrentUser ? "You" : "They"
    let noun: String
    switch fact.dimensionID {
    case "theme":  noun = "songs about \(fact.category.lowercased())"
    case "energy": noun = "\(fact.category) energy picks"
    default:       noun = "\(fact.category) picks"
    }
    if fact.total > 0 {
        var line = "\(You) liked \(fact.likes) of \(fact.total) \(noun)"
        if fact.hearts > 0 { line += " — \(fact.hearts) hearted" }
        return line
    }
    if fact.hearts > 0 {
        return "\(fact.hearts) heart\(fact.hearts == 1 ? "" : "s") on \(noun)"
    }
    return "\(fact.category) picks shaped this"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: `Suite DriverReceiptCopyTests passed`, 8 tests, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/Components/ArchetypeCopy.swift" "Daily MusicTests/ArchetypeCopyTests.swift"
git commit -m "feat(insights): driverReceiptCopy — per-fact receipt line for driver cards"
```

---

### Task 2: `BoardEntranceFlavor` (TDD)

**Files:**
- Create: `Daily Music/Models/BoardEntranceFlavor.swift`
- Test: `Daily MusicTests/TasteMirrorTests.swift` (append at end)

- [ ] **Step 1: Write the failing tests**

Append at the END of `Daily MusicTests/TasteMirrorTests.swift`:

```swift
// MARK: - BoardEntranceFlavor

struct BoardEntranceFlavorTests {

    @Test func moodyLightStylesBloomSlowAndDim() {
        let f = BoardEntranceFlavor.flavor(for: .halfMoon)   // The Outsider
        #expect(f.bloomDuration > BoardEntranceFlavor.standard.bloomDuration)
        #expect(f.bloomOpacity < BoardEntranceFlavor.standard.bloomOpacity)
    }

    @Test func popLightStylesBloomFastAndBright() {
        let f = BoardEntranceFlavor.flavor(for: .glossyPop)  // The Pophead
        #expect(f.bloomDuration < BoardEntranceFlavor.standard.bloomDuration)
        #expect(f.bloomRadius > BoardEntranceFlavor.standard.bloomRadius)
    }

    @Test func warmLightStylesGetWarmBloom() {
        let f = BoardEntranceFlavor.flavor(for: .softBloom)  // Hopeless Romantic
        #expect(f.bloomDuration >= BoardEntranceFlavor.standard.bloomDuration)
        #expect(f.bloomRadius >= BoardEntranceFlavor.standard.bloomRadius)
    }

    @Test func unmappedStylesGetStandard() {
        #expect(BoardEntranceFlavor.flavor(for: .colorRibbons) == .standard)
        #expect(BoardEntranceFlavor.flavor(for: .none) == .standard)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Test command with `-only-testing:"Daily MusicTests/BoardEntranceFlavorTests"`.
Expected: BUILD FAILS with "cannot find 'BoardEntranceFlavor' in scope".

- [ ] **Step 3: Write the implementation**

Create `Daily Music/Models/BoardEntranceFlavor.swift`:

```swift
//
//  BoardEntranceFlavor.swift
//  Daily Music
//
//  Maps an archetype's reveal LightStyle to the taste-mirror board's hero
//  bloom parameters, so the entrance inherits the archetype's personality:
//  moody archetypes breathe slow and dark, pop archetypes flash quick and
//  bright. Pure data — the board animates with these numbers.
//

import Foundation

struct BoardEntranceFlavor: Equatable {
    /// Seconds for the full swell-and-settle of the hero shadow.
    let bloomDuration: Double
    /// Peak shadow radius (rest state is 20).
    let bloomRadius: Double
    /// Peak shadow opacity (rest state is 0.35).
    let bloomOpacity: Double

    static let standard = BoardEntranceFlavor(bloomDuration: 0.9, bloomRadius: 34, bloomOpacity: 0.55)

    static func flavor(for lightStyle: ArchetypeRevealFlare.LightStyle) -> BoardEntranceFlavor {
        switch lightStyle {
        // Slow, heavy glow — moody archetypes (Outsider, Melancholic, Stargazer…).
        case .halfMoon, .cloudMoon, .moonlit, .moonHaze, .darkWave, .gothMoon,
             .noirPurple, .burgundyNoir, .vignette, .lavenderHaze:
            return BoardEntranceFlavor(bloomDuration: 1.4, bloomRadius: 30, bloomOpacity: 0.45)
        // Quick, bright pop — party/pop/electric archetypes.
        case .partyBeams, .glossyPop, .stageFlash, .discoSweep, .neonScan,
             .arenaBeams, .goldArena, .electric, .crimsonBolt, .synthBars, .stencilFlash:
            return BoardEntranceFlavor(bloomDuration: 0.6, bloomRadius: 42, bloomOpacity: 0.7)
        // Warm drift — soft archetypes (Romantic, Flower Child, Hippie…).
        case .softBloom, .gardenGlow, .warmGlow, .roseBloom, .breeze,
             .sunHaze, .sunburst, .canyonGlow:
            return BoardEntranceFlavor(bloomDuration: 1.0, bloomRadius: 38, bloomOpacity: 0.6)
        default:
            return .standard
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: `Suite BoardEntranceFlavorTests passed`, 4 tests, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/BoardEntranceFlavor.swift" "Daily MusicTests/TasteMirrorTests.swift"
git commit -m "feat(insights): BoardEntranceFlavor — LightStyle → hero bloom parameters"
```

---

### Task 3: `Haptics.driverReward`

**Files:**
- Modify: `Daily Music/DesignSystem/Haptics.swift`

No unit test — UIKit feedback generators are side-effect-only, matching the rest of this file.

- [ ] **Step 1: Add the one-beat reward**

In `Daily Music/DesignSystem/Haptics.swift`, add below `playArchetypeReveal` (after its closing brace, before `playArchetypeBeat`):

```swift
    /// One immediate, archetype-flavored beat for the driver card landing.
    /// `crispReward`'s schedule is built for the reveal's multi-second arc;
    /// the board entrance needs its hit right when the #1 card settles.
    @MainActor static func driverReward(pattern: ArchetypeRevealFlare.HapticPattern) {
        switch pattern {
        case .none:          break
        case .sparkle:       impact(.light)
        case .softBloom:     impact(.soft)
        case .electric:      impact(.rigid)
        case .stageHit:      impact(.heavy)
        case .shadowPulse:   impact(.medium)
        case .triumph:       success()
        case .textureRumble: impact(.heavy)
        }
    }
```

- [ ] **Step 2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/DesignSystem/Haptics.swift"
git commit -m "feat(insights): Haptics.driverReward — one-beat archetype-flavored hit"
```

---

### Task 4: Rewrite `TasteMirrorBoard`

**Files:**
- Modify: `Daily Music/Views/Components/TasteMirrorBoard.swift` (full file replacement)

The grid, `marqueeTile`, `energyTile`, `tile`, `tileVisual`, `driverBadge`, `lockedTile`, `secondaryRow`, and all receded/dimming logic are deleted. `makeDetail`, `makeEnergyDetail`, `dimIcon`, `categorySymbol`, and the two entrance modifiers survive (the latter gain a sibling). `featuredLineString` is defined elsewhere in the app target and keeps working.

- [ ] **Step 1: Replace the entire file content**

Replace `Daily Music/Views/Components/TasteMirrorBoard.swift` with:

```swift
//
//  TasteMirrorBoard.swift
//  Daily Music
//
//  The reusable taste-mirror visualization, driver-first: archetype hero +
//  "what made you" driver cards (the categories that actually decided the
//  archetype, sized by importance) + quiet one-line rows for everything else.
//  Owns its own standout-detail sheet, so any screen that shows a mirror —
//  yours in InsightsView, a friend's in FriendInsightsView — gets tappable,
//  read-only breakdowns for free. Surrounding chrome (color wash, Wrapped
//  button, friend header) belongs to the host screen.
//

import SwiftUI

struct TasteMirrorBoard: View {
    let mirror: TasteMirror
    /// false when showing a friend's mirror → copy switches from "you" to "they".
    var isCurrentUser: Bool = true
    /// Insights passes the weekly-stable archetype here; friend mirrors leave it nil.
    var displayArchetype: TasteProfile? = nil
    var onRatingChanged: (() -> Void)? = nil
    /// Insights wires the hero's replay icon; friend mirrors leave it nil.
    var onReplay: (() -> Void)? = nil
    /// "Next reveal in N days" line inside the hero; nil hides it.
    var revealCountdownText: String? = nil
    @State private var detail: StandoutDetail?

    // MARK: entrance animation state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    /// True while the one-shot full choreography (bloom + shimmer + haptic) runs.
    @State private var rewardPlaying = false
    @State private var bloom = false
    @State private var shimmer = false

    /// Archetype IDs that already played the full choreography this app session —
    /// the hit stays special; re-visits get the quick entrance.
    @MainActor private static var rewardedIDs = Set<String>()

    private var displayProfile: TasteProfile { displayArchetype ?? mirror.archetype ?? .theShapeshifter }

    /// Accent = the archetype's lead color (neutral default while still forming).
    private var accent: Color { displayProfile.colors[0] }

    /// The archetype ID being displayed — changing it re-triggers the entrance.
    private var currentArchetypeID: String? { (displayArchetype ?? mirror.archetype)?.id }

    /// Driver map for the displayed archetype; empty while forming, for the
    /// Shapeshifter, or when the stable archetype lags the live winner.
    private var highlights: [String: DriverHighlight] {
        DriverHighlights.compute(
            evidence: mirror.evidence,
            displayedArchetypeID: currentArchetypeID,
            liveArchetypeID: mirror.archetype?.id
        )
    }

    private var flare: ArchetypeRevealFlare { .flare(for: displayProfile) }

    var body: some View {
        let highlights = self.highlights
        VStack(spacing: Theme.Spacing.lg) {
            // ── Act 1: Hero ── punches in first, big spring, then blooms once
            hero(mirror)
                .modifier(EntranceModifier(
                    appeared: appeared, reduceMotion: reduceMotion,
                    scale: 0.88, offsetY: 28, delay: 0,
                    response: 0.50, damping: 0.60
                ))

            // ── Act 2: The drivers — what actually decided the archetype ──
            if !highlights.isEmpty {
                driverSection(highlights)
            }

            // ── Act 3: Everything else recedes into quiet rows ──
            quietRows(highlights)
        }
        .sheet(item: $detail) { StandoutDetailView(detail: $0, onRatingChanged: onRatingChanged) }
        .onAppear {
            guard !appeared else { return }
            appeared = true
            playRewardIfEarned()
        }
        .onChange(of: currentArchetypeID) { _, _ in
            guard !reduceMotion else { return }
            appeared = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 40_000_000) // 40 ms gap
                appeared = true
                playRewardIfEarned()
            }
        }
    }

    // MARK: one-shot reward choreography

    /// Bloom + shimmer + haptic, only when earned (first time this session per
    /// archetype). Timings line up with the entrance springs below.
    @MainActor private func playRewardIfEarned() {
        guard let id = currentArchetypeID, !highlights.isEmpty,
              !Self.rewardedIDs.contains(id) else { return }
        Self.rewardedIDs.insert(id)
        let flavor = BoardEntranceFlavor.flavor(for: flare.lightStyle)
        let pattern = flare.hapticPattern
        rewardPlaying = true
        Task { @MainActor in
            // Hero has settled (~0.45 s) → bloom swells.
            try? await Task.sleep(for: .milliseconds(420))
            if !reduceMotion {
                withAnimation(.easeOut(duration: flavor.bloomDuration * 0.45)) { bloom = true }
            }
            // #1 driver card lands (~0.7 s) → reward beat + shimmer.
            try? await Task.sleep(for: .milliseconds(300))
            if isCurrentUser { Haptics.driverReward(pattern: pattern) }
            guard !reduceMotion else { rewardPlaying = false; return }
            shimmer = true
            try? await Task.sleep(for: .milliseconds(Int(flavor.bloomDuration * 450)))
            withAnimation(.easeInOut(duration: flavor.bloomDuration * 0.55)) { bloom = false }
            try? await Task.sleep(for: .milliseconds(1_200))
            rewardPlaying = false
            shimmer = false
        }
    }

    // MARK: hero

    private func hero(_ mirror: TasteMirror) -> some View {
        let profile = displayProfile
        let unlocked = displayArchetype != nil || mirror.archetype != nil
        let remaining = max(TasteMirror.Thresholds.minRatedArchetype - mirror.totalRated, 0)
        let flavor = BoardEntranceFlavor.flavor(for: flare.lightStyle)
        return ZStack(alignment: .bottomTrailing) {
            Image(systemName: profile.symbol)
                .font(.system(size: 168, weight: .bold))
                .foregroundStyle(.white.opacity(0.13))
                .offset(x: 28, y: 22)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Image(systemName: profile.symbol)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(profile.heroTopTint)
                        .frame(width: 52, height: 52)
                        .background(profile.heroTopTint.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Spacer()
                    Text(unlocked ? (isCurrentUser ? "YOUR ARCHETYPE" : "THEIR ARCHETYPE") : "FORMING")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.75))
                    if unlocked, let onReplay {
                        Button(action: onReplay) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 28, height: 28)
                                .background(.white.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Replay reveal")
                    }
                }
                Text(unlocked ? profile.title : "\(remaining) to go")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                if unlocked {
                    Text(profile.tagline)
                        .font(.callout.italic())
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(unlocked ? archetypeHeroCopy(profile: profile, winningModifier: mirror.winningModifier, isCurrentUser: isCurrentUser)
                              : "\(isCurrentUser ? "Your" : "Their") portrait takes shape at \(TasteMirror.Thresholds.minRatedArchetype) ratings.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                if unlocked, let revealCountdownText {
                    Text(revealCountdownText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.lg)
        .background(ArchetypeHeroBackground(profile: profile))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: profile.colors[0].opacity(bloom ? flavor.bloomOpacity : 0.35),
                radius: bloom ? flavor.bloomRadius : 20, y: 10)
    }

    // MARK: section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: driver section

    @ViewBuilder
    private func driverSection(_ highlights: [String: DriverHighlight]) -> some View {
        let ranked = highlights.values.sorted { $0.rank < $1.rank }
        let title = displayProfile.title.uppercased()

        sectionLabel(isCurrentUser ? "WHAT MADE YOU \(title)" : "WHAT MADE THEM \(title)")
            .modifier(FadeInModifier(appeared: appeared, reduceMotion: reduceMotion, delay: 0.08))

        if let first = ranked.first {
            primaryDriverCard(first)
                .modifier(EntranceModifier(
                    appeared: appeared, reduceMotion: reduceMotion,
                    scale: 0.82, offsetY: 18, delay: 0.12,
                    response: 0.45, damping: 0.55
                ))
        }

        if ranked.count > 1 {
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(ranked.dropFirst().prefix(2).enumerated()), id: \.element.rank) { index, h in
                    secondaryDriverCard(h)
                        .modifier(TiltEntranceModifier(
                            appeared: appeared, reduceMotion: reduceMotion,
                            angle: index == 0 ? 2 : -2,
                            delay: 0.22 + Double(index) * 0.06
                        ))
                }
                // A lone #2 stays half-width, leading-aligned.
                if ranked.count == 2 {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 1)
                }
            }
        }
    }

    private func primaryDriverCard(_ h: DriverHighlight) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let content = VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .black))
                Text("#1 DRIVER · \(dimensionLabel(h.fact.dimensionID).uppercased())")
                    .font(.caption2.weight(.heavy))
            }
            .foregroundStyle(accent)
            Text(headline(for: h))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(driverReceiptCopy(fact: h.fact, isCurrentUser: isCurrentUser))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .padding(Theme.Spacing.md)
        .overlay { shape.strokeBorder(accent.opacity(0.5), lineWidth: 1) }
        .overlay { shimmerOverlay(in: shape) }

        return Group {
            if let onTap = driverTap(h) {
                Button(action: onTap) { content }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(accent.opacity(0.30)).interactive(), in: shape)
            } else {
                content
                    .glassEffect(.regular.tint(accent.opacity(0.30)), in: shape)
            }
        }
    }

    private func secondaryDriverCard(_ h: DriverHighlight) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let content = VStack(alignment: .leading, spacing: 6) {
            Text("#\(h.rank) · \(dimensionLabel(h.fact.dimensionID).uppercased())")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(accent.opacity(0.85))
            Spacer(minLength: 0)
            Text(headline(for: h))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(Theme.Spacing.md)

        return Group {
            if let onTap = driverTap(h) {
                Button(action: onTap) { content }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(accent.opacity(0.30)).interactive(), in: shape)
            } else {
                content
                    .glassEffect(.regular.tint(accent.opacity(0.30)), in: shape)
            }
        }
    }

    /// A single shimmer sweep across the #1 card during the reward moment.
    @ViewBuilder
    private func shimmerOverlay(in shape: RoundedRectangle) -> some View {
        if rewardPlaying && !reduceMotion {
            GeometryReader { geo in
                LinearGradient(colors: [.clear, accent.opacity(0.35), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width / 2.5)
                    .offset(x: shimmer ? geo.size.width * 1.2 : -geo.size.width * 0.6)
                    .animation(.easeInOut(duration: 0.7), value: shimmer)
            }
            .clipShape(shape)
            .allowsHitTesting(false)
        }
    }

    /// The driving category as a headline; energy phrases the band itself.
    private func headline(for h: DriverHighlight) -> String {
        h.fact.dimensionID == "energy" ? "\(h.fact.category) energy" : h.fact.category
    }

    private func dimensionLabel(_ id: String) -> String {
        switch id {
        case "mood":   "Mood"
        case "theme":  "Theme"
        case "genre":  "Genre"
        case "energy": "Energy"
        default:       id.capitalized
        }
    }

    /// Tap-through for a driver card: detail sheet featured on the driving
    /// category; falls back to the dimension's standout when the category is
    /// heart-only (absent from tile data); nil when locked or a friend's mirror.
    private func driverTap(_ h: DriverHighlight) -> (() -> Void)? {
        guard isCurrentUser else { return nil }
        if h.fact.dimensionID == "energy" {
            guard mirror.energy.isUnlocked else { return nil }
            return { detail = makeEnergyDetail(mirror.energy, accent: accent) }
        }
        guard let dim = dimension(for: h.fact.dimensionID), dim.isUnlocked else { return nil }
        let featured = dim.categories.first { $0.name == h.fact.category }
        return { detail = makeDetail(dim: dim, accent: accent, featured: featured) }
    }

    private func dimension(for id: String) -> DimensionInsight? {
        switch id {
        case "mood":  mirror.mood
        case "theme": mirror.theme
        case "genre": mirror.genre
        default:      nil
        }
    }

    // MARK: quiet rows

    @ViewBuilder
    private func quietRows(_ highlights: [String: DriverHighlight]) -> some View {
        sectionLabel(highlights.isEmpty ? "YOUR TASTE" : "MORE ABOUT YOUR TASTE")
            .modifier(FadeInModifier(appeared: appeared, reduceMotion: reduceMotion, delay: 0.30))

        VStack(spacing: 10) {
            if highlights["mood"] == nil { dimensionRow(mirror.mood, lead: "Mood", delay: 0.32) }
            if highlights["theme"] == nil { dimensionRow(mirror.theme, lead: "Theme", delay: 0.35) }
            if highlights["genre"] == nil { dimensionRow(mirror.genre, lead: "Genre", delay: 0.38) }
            if highlights["energy"] == nil { energyRow(mirror.energy, delay: 0.41) }
            dimensionRow(mirror.decade, lead: "Era", delay: 0.44)
            dimensionRow(mirror.language, lead: "Language", delay: 0.47)
        }
    }

    @ViewBuilder
    private func dimensionRow(_ dim: DimensionInsight, lead: String, delay: Double) -> some View {
        Group {
            if dim.isUnlocked, let s = dim.topStandout {
                quietRow(lead: lead, icon: dimIcon(dim.id), value: s.name,
                         onTap: isCurrentUser ? { detail = makeDetail(dim: dim, accent: accent) } : nil)
            } else {
                lockedRow(lead: lead)
            }
        }
        .modifier(FadeInModifier(appeared: appeared, reduceMotion: reduceMotion, delay: delay))
    }

    @ViewBuilder
    private func energyRow(_ energy: EnergyInsight, delay: Double) -> some View {
        Group {
            if energy.isUnlocked, let lean = energy.leanLabel {
                quietRow(lead: "Energy", icon: "bolt.fill", value: lean,
                         onTap: isCurrentUser ? { detail = makeEnergyDetail(energy, accent: accent) } : nil)
            } else {
                lockedRow(lead: "Energy")
            }
        }
        .modifier(FadeInModifier(appeared: appeared, reduceMotion: reduceMotion, delay: delay))
    }

    /// One compact stat row. `onTap == nil` renders it inert (friend mirrors).
    @ViewBuilder
    private func quietRow(lead: String, icon: String, value: String,
                          onTap: (() -> Void)?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let row = HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(accent)
                .frame(width: 26)
            Text(lead)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            // Chevron only when it's actually tappable (your own mirror).
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 15)

        if let onTap {
            Button(action: onTap) { row }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            row.glassEffect(.regular, in: shape)
        }
    }

    private func lockedRow(lead: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "lock.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 26)
            Text(lead)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("Rate more")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 15)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(0.85)
    }

    // MARK: detail builders

    private func makeDetail(dim: DimensionInsight, accent: Color, featured: CategoryStat? = nil) -> StandoutDetail? {
        guard let featured = featured ?? dim.topStandout else { return nil }
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
            featuredLine: featuredLineString(likes: featured.likes, total: featured.total, likeRate: featured.likeRate),
            featuredSongs: mirror.songs(inDimension: dim, category: featured.name),
            rows: rows,
            standoutID: dim.overIndex?.id,
            skipID: dim.skip?.id
        )
    }

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
            featuredLine: "\(isCurrentUser ? "Your" : "Their") saved songs lean \(lean), averaging a \(String(format: "%.1f", mean)) out of 5 on energy.",
            featuredSongs: mirror.songs(forDimensionID: "energy", category: featuredBandID),
            rows: rows, standoutID: nil, skipID: nil
        )
    }

    // MARK: symbols

    private func dimIcon(_ dimID: String) -> String {
        switch dimID {
        case "mood":     "theatermasks.fill"
        case "decade":   "calendar"
        case "theme":    "text.quote"
        case "genre":    "guitars.fill"
        case "language": "globe"
        case "energy":   "bolt.fill"
        default:         "star.fill"
        }
    }

    /// Per-category SF Symbol from the taxonomy (mood/theme only); nil otherwise.
    private func categorySymbol(_ dimID: String, _ name: String) -> String? {
        switch dimID {
        case "mood":  Mood(rawValue: name)?.symbol
        case "theme": SongTheme(rawValue: name)?.symbol
        default:      nil
        }
    }
}

// MARK: - Entrance animation helpers

/// Punchy spring scale + lift + fade. Used for the hero card and driver cards.
private struct EntranceModifier: ViewModifier {
    let appeared: Bool
    let reduceMotion: Bool
    var scale: CGFloat = 0.88
    var offsetY: CGFloat = 20
    var delay: Double = 0
    var response: Double = 0.50
    var damping: Double = 0.62

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1 : scale)
            .offset(y: appeared ? 0 : offsetY)
            .opacity(appeared ? 1 : 0)
            .animation(
                reduceMotion
                    ? .none
                    : .spring(response: response, dampingFraction: damping).delay(delay),
                value: appeared
            )
    }
}

/// Spring pop with a slight rotation settle — the #2/#3 driver cards.
private struct TiltEntranceModifier: ViewModifier {
    let appeared: Bool
    let reduceMotion: Bool
    var angle: Double = 2
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(appeared ? 0 : angle))
            .scaleEffect(appeared ? 1 : 0.85)
            .offset(y: appeared ? 0 : 14)
            .opacity(appeared ? 1 : 0)
            .animation(
                reduceMotion
                    ? .none
                    : .spring(response: 0.45, dampingFraction: 0.6).delay(delay),
                value: appeared
            )
    }
}

/// Simple opacity drift. Used for labels and quiet rows.
private struct FadeInModifier: ViewModifier {
    let appeared: Bool
    let reduceMotion: Bool
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(
                reduceMotion
                    ? .none
                    : .easeOut(duration: 0.35).delay(delay),
                value: appeared
            )
    }
}
```

- [ ] **Step 2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`. (FriendInsightsView compiles unchanged — the new parameters default to nil.)

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Components/TasteMirrorBoard.swift"
git commit -m "feat(insights): driver-first board — sized driver cards, quiet rows, reward choreography"
```

---

### Task 5: Reorder `InsightsView`

**Files:**
- Modify: `Daily Music/Views/InsightsView.swift`

- [ ] **Step 1: Rewrite `content(_:)` and remove the absorbed elements**

In `Daily Music/Views/InsightsView.swift`, replace the `content(_:)` function with:

```swift
    private func content(_ mirror: TasteMirror) -> some View {
        let accent = (mirror.archetype ?? .theShapeshifter).colors[0]
        return ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                recapMomentBanner
                TasteMirrorBoard(
                    mirror: mirror,
                    displayArchetype: mirror.archetype,
                    onRatingChanged: { Task { await model?.load(favoriteIDs: env.favoritesStore.ids) } },
                    onReplay: mirror.isArchetypeUnlocked ? { model?.replayReveal() } : nil,
                    revealCountdownText: countdownText(for: mirror)
                )
                historySection(accent: accent)
                startedHereCard
                wrappedButton(accent)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .refreshable {
            await model?.load(favoriteIDs: env.favoritesStore.ids)
            Haptics.tap()
        }
    }
```

Delete the `replayButton(_:)` and `revealCountdown(for:)` functions entirely, and add in their place:

```swift
    /// The hero's quiet countdown line; nil while locked or when a reveal is due.
    private func countdownText(for mirror: TasteMirror) -> String? {
        guard mirror.isArchetypeUnlocked, let next = model?.nextRevealDate else { return nil }
        let days = max(0, Calendar.current.dateComponents([.day], from: .now, to: next).day ?? 0)
        guard days > 0 else { return nil }
        return "Next reveal in \(days) day\(days == 1 ? "" : "s")"
    }
```

(`startedHereCard` itself is unchanged — only its position in `content` moved.)

- [ ] **Step 2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run the full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 \
  | grep -E "Test run|TEST (SUCCEEDED|FAILED)|✘" | head -10
```

Expected: `** TEST SUCCEEDED **` (152 tests: 140 prior + 8 receipt + 4 flavor).

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/InsightsView.swift"
git commit -m "feat(insights): declutter — hero absorbs replay + countdown, started-here moves to bottom"
```

---

### Task 6: Manual verification + docs

**Files:**
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Manual simulator pass** (user runs from Xcode; verify together)

1. Unlocked archetype: hero, then "WHAT MADE YOU …" with one big #1 card (receipt line with real counts) and up to two half cards; quiet rows below for everything else. No dimming anywhere.
2. First open this session: hero glow swells once, #1 card shimmers, haptic fires (physical device only). Re-entering the tab: quick entrance, no shimmer.
3. Driver cards open detail sheets featured on the driving category.
4. Hero shows the replay icon (works) and the countdown caption when applicable; "you started here" sits below history.
5. Friend mirror: driver cards render inert, no replay icon, no haptic.
6. Forming (<10 ratings) and Shapeshifter: no driver section, six rows under "YOUR TASTE".
7. Reduce Motion on: everything renders statically, no shimmer/bloom.

- [ ] **Step 2: Update `docs/ARCHITECTURE.md`**

Replace the "Driver highlights" paragraph (added 2026-06-10, starts "**Driver highlights** ([DriverHighlights…") with:

```markdown
**Driver-first board** ([DriverHighlights](Daily%20Music/Models/DriverHighlights.swift) ·
[BoardEntranceFlavor](Daily%20Music/Models/BoardEntranceFlavor.swift)):
`DriverHighlights.compute` maps the evidence facts to `[dimensionID: DriverHighlight]`
(rank + fact), suppressed when the displayed (weekly-stable) archetype differs from the
live winner. `TasteMirrorBoard` renders hierarchy by size: a full-width #1 driver card
(receipt line via `driverReceiptCopy` in `ArchetypeCopy.swift`) + half-width #2/#3 cards,
with all non-driver dimensions demoted to quiet one-line rows. The entrance is
archetype-flavored: `BoardEntranceFlavor` maps the reveal `LightStyle` to a one-shot hero
bloom, the #1 card gets a shimmer sweep + `Haptics.driverReward` beat — played once per
archetype per app session. The hero absorbs Insights' replay button and reveal countdown.
```

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs: architecture map — driver-first insights board"
```
