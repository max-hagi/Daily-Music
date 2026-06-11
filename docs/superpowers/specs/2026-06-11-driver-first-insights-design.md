# Driver-First Insights Layout — Design

**Date:** 2026-06-11
**Supersedes:** the visual treatment in `2026-06-10-archetype-driver-highlights-design.md`
(the `DriverHighlights` model and its tests carry over unchanged; the badge/dim
tile styling is replaced wholesale).

**Problem:** After the badge/dim pass, all six stat surfaces still share one
size, so hierarchy rests on decoration alone, and the dimmed tiles make the
page feel washed out. The screen also stacks ~11 competing elements (banner,
started-here card, hero, 4 tiles, 2 rows, replay button, countdown, history,
wrapped button) — classic choice overload. Hierarchy should come from **size
and position**; non-essential elements should be demoted, not dimmed.

## Layout (option A — driver spotlight)

### InsightsView page order

1. Recap moment banner (unchanged; appears ~6 days/month)
2. `TasteMirrorBoard` (hero + drivers + quiet rows)
3. History section (unchanged)
4. "You started here" card (moved from top to here — nostalgia, not news)
5. "See your month" button (unchanged)

The standalone replay button and "Next reveal in N days" text are **removed
from the page**; the hero absorbs both (below).

### TasteMirrorBoard structure

The 2×2 marquee grid, `marqueeTile`, `energyTile`, `tile`, `tileVisual`,
`driverBadge`, and the receded/dimming logic are **deleted**. New structure:

1. **Hero** — current card, with three changes:
   - New optional inputs: `onReplay: (() -> Void)?` renders a small
     `arrow.counterclockwise` icon button in the hero's top-right corner area
     (next to the "YOUR ARCHETYPE" label); `revealCountdownText: String?`
     renders as one quiet caption line at the bottom of the hero copy stack.
     InsightsView passes both; FriendInsightsView passes nil (default).
   - The faint receipts caption (`archetypeReceiptsCopy`) is removed — the
     driver cards replace it.
2. **Driver section** — only when `DriverHighlights.compute(...)` is
   non-empty. Section label: "WHAT MADE YOU \<TITLE\>" /
   "WHAT MADE THEM \<TITLE\>" (uppercased, same style as current labels).
   - **#1 driver: full-width card.** Lead line `★ #1 DRIVER · <DIMENSION>`,
     big headline (the driving category, e.g. "Dark"), and a receipt line
     with real numbers from the fact (see Receipt copy). Archetype-tinted
     glass (`accent.opacity(0.30)`) + thin accent ring, like the old driver
     tiles but full width and taller (~minHeight 110).
   - **#2/#3 drivers: half-width pair** in an HStack, smaller (~minHeight 84):
     lead `#2 · <DIMENSION>` + headline only. Same tint, no ring. A lone #2
     (two facts total) renders as one half-width card, leading-aligned.
   - All driver cards open the existing `StandoutDetailView` featured on the
     driving category (`makeDetail(dim:accent:featured:)`; energy uses
     `makeEnergyDetail`). Friend mirrors render them inert (no button,
     non-interactive glass), as tiles do today.
   - Driver dimension that is locked (`!dim.isUnlocked`) or whose category is
     missing from `dim.categories` (heart-only): the card still renders from
     the fact's own data (category name + receipt); only the tap-through
     falls back (featured = topStandout) or is disabled if the dimension is
     locked.
3. **Quiet rows** — section label "MORE ABOUT YOUR TASTE" (or "YOUR TASTE"
   when the driver section is absent). One compact `secondaryRow`-style row
   per dimension **not shown as a driver**, in fixed order: Mood, Theme,
   Genre, Energy (skipping any that are driver cards), then Era and Language
   always. Row value = `topStandout.name` (energy: `leanLabel`). Locked
   dimensions render a lock icon + "Rate more" value, non-tappable. Unlocked
   rows keep tap-through to detail sheets (current-user only).

### No-driver states

Forming, Shapeshifter, or stable archetype ≠ live winner → driver section
omitted; all six dimensions render as quiet rows under "YOUR TASTE". No
badges, no dimming anywhere in any state.

## Receipt copy

New pure helper `driverReceiptCopy(fact:isCurrentUser:) -> String` in
`ArchetypeCopy.swift` (next to `archetypeReceiptsCopy`, covered by
`ArchetypeCopyTests`):

- Thumbed: "You liked 8 of 10 Dark picks" / "They liked …"
- With hearts: append " — 3 hearted" (1 → "1 hearted")
- Heart-only (`total == 0`, `hearts > 0`): "3 hearts on Dark picks"
- Degenerate (`total == 0 && hearts == 0`): fall back to
  "Dark picks shaped this" (shouldn't occur; guard anyway)

Category names render as given (they're proper nouns in the taxonomy).
Energy facts phrase the band: "High energy picks".

## Entrance choreography v2

Full choreography plays only when **earned**: first board appearance this app
session, or when `currentArchetypeID` changes. Otherwise the existing simple
entrance (hero spring + fades) runs. Tracked with a `@State` flag plus a
`static var` session memo keyed by archetype ID (no persistence).

1. **Hero bloom:** existing entrance spring, then the hero's shadow swells
   once (`shadow` radius/opacity animated up and back, in
   `profile.colors[0]`), flavor from the archetype's
   `ArchetypeRevealFlare.lightStyle` — mapped to bloom duration/intensity by a
   small pure function (e.g. `shadowPulse` → slow + dark, `softBloom` → quick
   + warm; unknown styles get the default medium bloom).
2. **#1 driver reward beat:** overshooting spring
   (`response 0.45, damping 0.55`), then a single shimmer sweep — a
   `LinearGradient` highlight masked to the card, animated across once — in
   the accent color, synced with
   `Haptics.playArchetypeReveal`'s `crispReward` schedule for the archetype's
   `hapticPattern`. Haptic fires only for the current user
   (`isCurrentUser == true`), never for friend mirrors.
3. **#2/#3 cards:** staggered springs with rotation settle
   (`rotationEffect` ±2° → 0).
4. **Quiet rows:** cascade `FadeInModifier`s, deliberately plain.

**Reduce Motion:** all of the above renders statically and immediately
(existing `reduceMotion` handling); the haptic call already takes
`reduceMotion` and degrades per its existing behavior.

## Out of scope

- The app-wide UI/UX consistency pass (separate follow-up project).
- Any change to `DriverHighlights`, `ArchetypeScorer`, `TasteMirror`, or the
  reveal flow.
- WrappedView / share cards.

## Testing

- TDD the receipt-copy helper: thumbed, hearts suffix, heart-only, degenerate
  fallback, they-variant, energy phrasing.
- TDD the lightStyle → bloom-parameters mapping (total function over
  `LightStyle`, default for unmapped cases).
- `DriverHighlights` tests carry over unchanged.
- Layout + choreography verified manually in the simulator (both color
  schemes, Reduce Motion on/off, friend mirror, forming state).
