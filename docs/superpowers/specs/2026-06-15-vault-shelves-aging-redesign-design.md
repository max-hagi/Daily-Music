# Vault redesign — Month Shelves, sleeve aging, art-mosaic calendar

Date: 2026-06-15
Status: Approved (design), pending implementation plan
Supersedes the Crate/coverflow portions of `COLLECTION_REDESIGN_SPEC.md` §3 and the
calendar markers in §3's "Calendar view". The pressing-state mechanic (§1) is unchanged.

## 0. Goal (keep in view)

The Vault gives every published entry a useful second life: browse and rediscover your
collection, feel rewarded for collecting, and get pulled back to reclaim what you missed.
This redesign fixes four problems the current build has:

1. **Worn records don't read as worn** — caught-up-late ("secondhand") sleeves look almost
   identical to mint at a glance.
2. **Missed records are blank** — an empty sleeve is no reward, so nobody looks at them and
   there's no reason to come back for them.
3. **Browse is hard to navigate** — a single horizontal coverflow makes "go far back" mean
   flicking sideways forever.
4. **The calendar is barren and the heading is boring** — dot markers carry no reward, the
   header is a flat label, and the per-month count is redundant (one song a day → the count
   is just the date).

## 1. Browse: Month Shelves (replaces the single coverflow)

Replace the full-screen horizontal `CrateView` coverflow with a **vertical scroll of month
"shelves"**, like flipping through dividers in a record shop.

- Each shelf = a shop-style divider header (e.g. `June 2026`) + a **horizontally
  scrollable row** of that month's sleeves.
- Order: months newest-first down the page; within a month, sleeves newest-first left→right.
- **Vertical scroll travels back through time; horizontal scroll digs a month.** This is the
  whole navigation fix — years back is a vertical fling, not an endless sideways scroll.
- Tapping a sleeve preserves the existing zoom-into-detail transition
  (`matchedTransitionSource` → `.zoom` `fullScreenCover`, unchanged).
- Sleeve size: moderate (~120–140pt) so 2–3 peek per row, inviting the sideways dig.
- Each sleeve carries a small 1-line caption (title) beneath it; no per-record "now showing"
  info panel (that belonged to the single-centered coverflow).

### What goes away
- The single full-screen coverflow stage, its ambient blurred backdrop, the centered
  "now showing" info panel, and the center-grow/tilt emphasis.
- `CrateFeel` (§11.3 variant: flatScroll / centerTilt / snapPaging) collapses — shelves use a
  plain horizontal scroll per row. Remove `CrateFeel` from `VariantConfig` and the debug
  gallery, or reduce it to a no-op; the implementation plan decides which is least disruptive.

### Data
No backend change. `VaultViewModel` already returns `publishedHistory()` newest-first; group
it by month for the shelves (a pure helper in `CrateLayout`, unit-tested — see §6).

## 2. Sleeve aging system (`SleeveView` / `SleeveTreatment`)

State stays encoded by **treatment, not hue** (album art is already every color). The four
treatments, with the two changes this redesign makes:

- **mint** (heard same day) — crisp clean sleeve, disc peeking. Unchanged. The reward state.
- **secondhand** (caught up late) — **now clearly worn.** Must read as a used copy at
  thumbnail size without effort:
  - a **ring-wear circle** (the vinyl's ghost worn into the cardboard),
  - light desaturation + slight darkening (keep current muting, tuned to stay attractive),
  - faint diagonal scuff lines,
  - the existing dog-ear corner + "2nd" stamp.
- **missing → dusty + rescuable** — **no longer blank.** Show the real album art, heavily
  desaturated under a **dust haze** (low-opacity neutral overlay + a few light dust specks),
  so there is always something to look at. Add a small **Rescue** affordance (a pill/badge on
  the sleeve). The art being visible-but-aged is the reward; the Rescue prompt is the pull.
- **pending** (today's drop, or still-rescuable within window) — unchanged (accent border +
  play badge + disc).

### The rescue loop (already supported by the mechanic)
Opening any Vault entry calls `markHeard`; `ListenStatus.of` then derives `caughtUp` for a
late listen. So **listening to a dusty (missed) record converts it to secondhand** — nothing
is ever permanently lost. The dusty look + Rescue affordance simply make that comeback legible
and inviting. No change to listen-tracking semantics.

### Variant change
`MissingSleeveVariant` default flips from `.blank` to the new dusty treatment. Either repurpose
the enum (`.blank` / `.ghost` → `.dusty` becomes the shipping default) or replace it; the plan
decides. Update `defaultsMatchLockedPicks` and related variant tests accordingly.

## 3. Calendar → "Month" lens: album-art mosaic

Replace the dot/emoji markers in `CalendarMonthView` with the **album cover in-state**:

- Each entry day renders a **small `SleeveView`** (compact treatment) instead of a colored dot
  — the month becomes a mosaic of covers wearing their states (mint crisp, worn ring-marked,
  dusty faded).
- **Today** = gold ring around the cell.
- **Reactions** = small emoji corner badge overlaid on the cover (replaces the
  emoji-instead-of-dot rule; the cover always shows, the emoji rides the corner).
- **Missed** days show the dusty mini sleeve and stay **tappable to rescue**.
- **Future / empty** days = faint day-number placeholder (no cover).
- Month nav chevrons + paging unchanged.

### Performance
~30 covers per visible month. Lazy-load and rely on `AlbumArtView`'s existing caching; the grid
already lazily builds cells. Watch the same downsample concern noted for the widget — reuse
whatever downsampling `AlbumArtView` provides; do not load full-res covers into 40–56pt cells.

## 4. Header redesign

Replace the flat title + count line with record-shop signage:

- Eyebrow: `THE CRATE` (small, tracked, secondary).
- Title: `Your collection`.
- **Drop the redundant "· N this month"** entirely.
- Secondary line = a **dynamic nudge** chosen by a pure, priority-ordered, unit-tested picker
  (`VaultNudge`). Priority order (tunable; finalize in the plan):
  1. Rescuable records exist → "{n} waiting to be rescued"
  2. Collected today / milestone close → "{run}-day run · {k} to your next pressing"
  3. Default → "{total} records · started {Month YYYY}"
  The picker takes counts/dates in, returns a string out — no view state, fully testable like
  `CrateLayout.collectionCountLabel` (which it effectively replaces/extends).
- Lens toggle: a labeled **Shelf / Month** pill (replaces the bare icon segmented control).

### Share button
A **share action in the header** exports a **collection share card**: a mosaic of recent covers
+ the collection count + the current nudge line, rendered high-res. Reuse the existing
`ShareCard` / `WrappedShareCard` infrastructure; this is the acquisition hook from
`COLLECTION_REDESIGN_SPEC.md` §4/§7 — people screenshot identity, not numbers. **Free in v1.**
The card must be genuinely beautiful (it is the organic growth loop), not a stat line.

## 5. Catch-up strip — removed

The standalone `CatchUpStrip` ("the Curator held these for you") is **removed**. Its job is now
covered by:
- the header nudge ("{n} waiting to be rescued"), and
- the dusty in-grid sleeves with their Rescue affordance.

This removes a redundant module and a full-width card, reducing clutter. The underlying
`CatchUp.missedEntries` / rescuable logic stays (the header nudge and tab badge use it); only
the strip view is deleted. The Vault tab badge behaviour is unchanged.

## 6. Pure helpers (testable, no UI)

Keep layout/derivation logic in pure functions next to `CrateLayout`, fully unit-tested:

- `monthSections(_ entries:)` — group newest-first entries into ordered month buckets for the
  shelves.
- `VaultNudge.line(total:rescuable:collectedToday:run:nextMilestoneIn:startedMonth:)` — the
  priority-ordered nudge string. Replaces/extends `collectionCountLabel`.

## 7. Out of scope for v1 (designed-for, not built)

The dusty/rescue loop creates clean monetization hooks; **design for them, ship the loop free
first, validate, then charge** (matches `COLLECTION_REDESIGN_SPEC.md` §7):

- Rescue passes / paid **bulk restore** of a whole dusty shelf at once.
- Rescuing past the catch-up window (free users limited to in-window rescues).
- **Restoration cosmetics** — a nicer "restored" finish on rescue (ties to streak/variant
  pressings: colored / gold / foil / splatter).
- Curator-framed paywall ("the Curator held this dusty find for you").

None of these ship in v1. The visuals (dusty state, Rescue affordance, share card) are built so
the hooks can attach later without rework.

## 8. Acceptance

- Browse scrolls vertically by month, horizontally within a month; traveling a year back is a
  vertical fling, not a sideways marathon.
- Secondhand sleeves read as worn at thumbnail size without inspection.
- Missed sleeves show dusty real art (never blank) + a Rescue affordance; listening one
  converts it to secondhand (verified via `ListenStatus`), nothing is destroyed.
- Calendar days show in-state covers; today ringed, reactions badged, missed tappable, empty
  days faint.
- Header shows `THE CRATE` / `Your collection` + a context-appropriate nudge; no "this month"
  count; Shelf/Month toggle; a working high-res collection share card.
- Catch-up strip removed; nudge + dusty sleeves cover its job; tab badge unchanged.
- State styling driven solely by `PressingState`/`ListenStatus`; new logic lives in pure,
  unit-tested helpers.
