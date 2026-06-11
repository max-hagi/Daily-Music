# Archetype Driver Highlights — Design

**Date:** 2026-06-10
**Problem:** Insights shows the archetype hero, then a 2×2 grid of standout tiles
(Mood/Era/Theme/Energy) plus Genre/Language rows — all at equal visual weight.
The categories that actually *decided* the archetype (already computed as
`ArchetypeEvidence`, top 3 facts by contribution) appear only as a faint caption
in the hero. The grid implies the wrong causality: Era and Language aren't even
scorer inputs.

**Goal:** Make the stats that determined the archetype visually dominant over
the ones that didn't, without restructuring the screen.

## Approach (chosen)

Highlight driver tiles in place. Rejected alternatives: a dedicated "what made
you X" section (duplicates the grid's content) and a contribution-ordered grid
restructure (bigger change, breaks the familiar layout for friend mirrors too).

## Data flow

- No changes to `ArchetypeScorer` or `TasteMirror`. The board consumes
  `mirror.evidence` (up to 3 `ArchetypeEvidence.Fact`s, descending by
  contribution).
- New pure helper (own file, e.g. `Models/DriverHighlights.swift`):
  builds `[dimensionID: DriverHighlight]` from evidence, where
  `DriverHighlight` carries the rank (1–3) and the fact. Unit-testable
  without SwiftUI.
- Evidence is only meaningful for the *live* winning archetype. When the
  displayed archetype (weekly-stable `displayArchetype`) differs from
  `mirror.archetype`, suppress highlights — same guard the hero receipts
  caption already uses (`profile.id == mirror.archetype?.id`).

## Visual treatment

**Driver tiles** (Mood / Theme / Energy with a fact):
- Headline shows the **driving category** (may differ from the dimension's
  top standout — truthfulness wins).
- Badge pill, top-right of the tile: `★` + label. Rank 1 reads `★ #1`;
  ranks 2–3 read `★` + "SHAPED YOU". Accent-colored glass pill.
- Stronger presence: glass tint opacity ~0.16 → ~0.30, thin accent border ring.
- Tap opens the existing `StandoutDetailView` with the driver category
  featured (`makeDetail(dim:accent:featured:)` already supports this).

**Genre row:** genre can be a driver (e.g. The Pophead). When it is, the
secondary row gets the same inline badge + accent ring.

**Non-driver tiles** recede slightly: glass tint opacity drops 0.16 → 0.10
and the headline color drops to `.secondary`. Recede applies only when at
least one highlight is showing.

**Unchanged:** locked tiles, Language row, Era tile (never a driver), and the
forming/Shapeshifter state (empty evidence → no badges, no recede; the board
looks exactly like today).

**Friend mirrors:** identical treatment driven by the friend's
`mirror.evidence`; `isCurrentUser` continues to govern copy and tappability only.

## Edge cases

- Empty evidence (Shapeshifter, below threshold): no highlights, no recede.
- Driver dimension whose tile is locked (`!dim.isUnlocked`): keep the locked
  tile; no badge on locked tiles.
- Driver category absent from `dim.categories` (shouldn't happen — evidence is
  built from the same rated data — but guard anyway): fall back to top standout
  headline with badge, no crash.
- Stable archetype ≠ live winner: no highlights (see Data flow).

## Testing

TDD the helper: rank ordering, dimension→fact mapping, genre-as-driver,
empty evidence, suppression when displayed archetype ≠ live winner.
View styling itself is verified manually in the simulator.
