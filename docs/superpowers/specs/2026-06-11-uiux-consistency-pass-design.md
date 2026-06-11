# UI/UX Consistency Pass — Design

**Date:** 2026-06-11
**Source:** `docs/audits/2026-06-11-uiux-audit.md` (read it first — it has the
evidence and file references for every decision below).
**Execution note:** written to be implemented in a fresh session. Project
quirks that bite: builds need
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17'`;
the test target (`Daily MusicTests/`) is NOT file-system-synced — never create
new test files, append to existing ones; an open Xcode keeps deleting
`Package.resolved` from the working copy — ignore it, never commit its deletion.

Four batches, each independently shippable, in order. Batches 1–2 are the
visible payoff; 3–4 are hygiene. Commit per batch (or finer). The full suite
(152 tests) must stay green after every batch; none of this work adds unit
tests — it's visual/structural, verified by build + simulator.

---

## Batch 1 — Tokens (no intended visual change)

All in `Daily Music/DesignSystem/Theme.swift` and `Styles.swift`, then a
mechanical migration sweep across `Views/`.

### 1a. Type ramp

Add to the `Font` extension:

```swift
/// Screen-defining hero titles (gradient hero cards).
static func dmHero() -> Font { .system(size: 36, weight: .heavy, design: .rounded) }
/// Big stat numbers (counts, metrics).
static func dmStat() -> Font { .system(size: 32, weight: .heavy, design: .rounded) }
/// Card-level titles (driver cards, tiles).
static func dmCardTitle() -> Font { .system(size: 20, weight: .heavy, design: .rounded) }
```

Migrate the obvious call sites (the audit's grep found them): 36-pt heavies in
`VaultView.vaultHero` / `FavoritesView.hero` → `dmHero()`; 32-pt in
`VaultView.vaultMetric` → `dmStat()`; 34-pt heavies stay `dmDisplay()`.
One-off sizes inside bespoke art (reveal flare, hero watermark 168 pt,
onboarding) are exempt — this is about repeated text scales, not every number.
Do not chase all 30 values in one pass; convert the ones that map cleanly to a
ramp entry and leave genuinely bespoke sizes alone.

### 1b. Radius scale

Replace `Theme.Radius` contents:

```swift
enum Radius {
    static let chip: CGFloat = 8      // album-art thumbs, small chips
    static let control: CGFloat = 13  // icon-badge squares inside cards
    static let row: CGFloat = 18      // list rows, quiet rows, pills' kin
    static let card: CGFloat = 22     // standard cards (existing)
    static let hero: CGFloat = 28     // gradient hero cards
    static let small: CGFloat = 12    // legacy alias, keep until migrated
}
```

Migration mapping for existing literals: 8/10 → `.chip`, 13/14 → `.control`,
16/18/20 → `.row` (16 and 20 normalize to 18 — intended), 22/24 → `.card`,
26/28 → `.hero`. The 2-pt accent bar in `VaultTintedEntryRow` stays a literal.
Snapshot-check in the simulator after: rows get marginally rounder/flatter;
that's the point.

### 1c. Shadows

Add to `Theme`:

```swift
enum Shadow {
    /// Soft resting shadow for floating cards. More blur, less opacity.
    static let cardRadius: CGFloat = 14
    static let cardY: CGFloat = 6
    static let cardOpacity: Double = 0.10
    /// Accent glow under gradient heroes.
    static let glowRadius: CGFloat = 18
    static let glowY: CGFloat = 10
    static let glowOpacity: Double = 0.25
}
```

And a `View` helper in `Styles.swift`:

```swift
func heroGlow(_ tint: Color) -> some View {
    shadow(color: tint.opacity(Theme.Shadow.glowOpacity),
           radius: Theme.Shadow.glowRadius, y: Theme.Shadow.glowY)
}
```

Migrate the hero shadows in Vault/Favorites/TasteMirrorBoard (the board's
bloom animation keeps its own animated values — only its REST state adopts
the token: rest radius stays 20 there if changing it perturbs the bloom; use
judgment, the bloom contrast is what matters).

### 1d. Hero gradients into Theme

Move the inline `Color(red:…)` Vault hero gradient to `Theme.Surface`:

```swift
static let vaultHero = [
    Color(red: 0.11, green: 0.33, blue: 0.42),
    Color(red: 0.9, green: 0.38, blue: 0.26),
    Color(red: 0.98, green: 0.66, blue: 0.22)
]
```

Call sites reference `Theme.Surface.vaultHero[1]` for the glow tint instead
of re-typing the RGB. Do NOT tokenize the Favorites hero gradient — batch 2b
deletes that hero entirely, so moving it first is wasted work.

### 1e. Pill insets into the modifier

`GlassPillModifier` absorbs the universal insets so call sites stop repeating
`.padding(.horizontal, 11).padding(.vertical, 7)`:

```swift
struct GlassPillModifier: ViewModifier {
    var tint: Color?
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .glassEffect(.regular.tint(tint), in: .capsule)
            .overlay { Capsule().stroke(.white.opacity(0.2), lineWidth: 1) }
    }
}
```

Remove the now-duplicated paddings at the three call sites
(`TodayToolbarStreakBadge`, `TodayToolbarLiveBadge`,
`VaultToolbarListenedBadge`) — check for any other `glassPillStyle` callers
first (`grep -rn "glassPillStyle" "Daily Music"`); any caller relying on
different insets keeps its own padding and this change must not double-pad it.

---

## Batch 2 — Hierarchy pass (the visible change)

### 2a. `HeroCard` component

New file `Daily Music/Views/Components/HeroCard.swift`: the gradient-stage
hero scaffold (icon badge top-left, eyebrow top-right, `dmHero()` title,
subtitle, optional trailing content slot below):

```swift
struct HeroCard<Content: View>: View {
    let icon: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
                Spacer()
                Text(eyebrow)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.72))
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(.dmHero())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(Theme.Spacing.lg)
        .background(
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
        )
        .heroGlow(gradient[gradient.count > 1 ? 1 : 0])
    }
}
```

Adopt it in `VaultView.vaultHero` (the featured-entry row goes in the content
slot). The archetype hero in `TasteMirrorBoard` stays bespoke (flare
background, bloom shadow, replay button) — do NOT force it into `HeroCard`.

### 2b. Favorites hero shrinks

Delete `FavoritesView.hero`. Replace with a compact header row at the top of
the list (glass row, not a gradient stage):

```swift
private func header(count: Int) -> some View {
    HStack(spacing: Theme.Spacing.md) {
        Image(systemName: "heart.fill")
            .font(.headline.weight(.bold))
            .foregroundStyle(.pink)
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count) \(count == 1 ? "favorite" : "favorites")")
                .font(.dmTitle())
            Text("The songs that stopped you in your tracks.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        Spacer()
    }
    .padding(Theme.Spacing.md)
    .glassCardStyle(tint: .pink.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
}
```

Same list-section placement the hero had. The screen's content (the songs)
becomes the visual lead.

### 2c. Vault stats demote

Delete `archiveStats` and `vaultMetric`. Fold the numbers into the calendar
card as a second subtitle line under "Dots mark days with a published pick.":
`Text("\(entries.count) songs · \(entriesThisMonth(entries)) this month")`
in `.footnote` + `.foregroundStyle(.secondary)`. No cards, no `dmStat()`
numbers for trivia.

### 2d. Friends request-row font fix

In `FriendsView.requestsSection`, remove the row-level `.font(.title3)`;
apply `.font(.title3)` to the two icon buttons only, so the name stays
`.headline` and icons keep their touch size.

---

## Batch 3 — Interaction vocabulary

- **Primary buttons:** anything that is the screen's main action uses
  `PrimaryActionButtonStyle(tint:)` — migrate `NewDropIncomingView`'s
  "Check again" (currently `.borderedProminent`).
- **Secondary/retry buttons:** `.bordered` with a tint — migrate
  `TodayErrorView` "Retry" and `FavoritesView.failedState` "Retry" from
  `.borderedProminent` to `.bordered`. (Retry after an error is not the
  screen's celebration moment.)
- **Row chevrons:** `.foregroundStyle(.secondary)` everywhere except
  artwork-tinted rows (`VaultTintedEntryRow` keeps its palette accent —
  that's deliberate per-song color). Migrate `EntryRow`'s `.tertiary`.

## Batch 4 — `EntryDetailView` split (mechanical, no behavior change)

706 lines → three files, types/access unchanged where possible:

- `Views/EntryDetailView.swift` — the public view, standard layout, shared
  backdrop + headers (MARKs "Standard layout" and "Backdrop + headers").
- `Views/EntryDetailImmersive.swift` — the immersive two-zone snap layout
  (MARK "Immersive layout").
- `Views/EntryActionCluster.swift` — the favorite + rating + info cluster
  (MARK "Action cluster").

Internal helpers move with their layout; anything shared stays in the main
file. The app target is file-system-synced, so new files compile
automatically. Build must pass with zero functional diff — this batch is a
pure cut-and-paste refactor and a good candidate for a separate commit per
file extraction.

## Out of scope

- Insights/TasteMirrorBoard (just redesigned — leave it alone beyond the
  shadow-token note in 1c).
- Onboarding visuals, reveal flare, share cards (bespoke art).
- Any behavior, copy, or navigation change not listed above.

## Verification per batch

1. Build succeeds; full test suite green (152 tests).
2. Simulator pass of touched screens in light + dark mode.
3. Batch 1 specifically: screens should look the SAME (±2 pt corner rounding);
   if something visibly moved, a migration mapping was wrong.
4. Update `docs/ARCHITECTURE.md` if file structure changed (batch 4) — the
   user keeps this map current.
