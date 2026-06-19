# Badges page & Insights declutter — design

**Date:** 2026-06-19
**Status:** Approved, ready for planning

## Problem

The Insights screen is crowded again. Everything below the taste mirror — the badges
summary card, the history card, the taste arc card, and the Wrapped button — renders
as identical full-width frosted cards with equal visual weight, so the eye has nothing
to lead it and nowhere to rest. The densest offender is the badges summary card
(earned count + close count + nearest-goal line + peek discs crammed together), which
also means the badge system Max loves is *buried* in that noise rather than celebrated.

Three things follow from that:

1. Badges deserve prominence — specifically the **recently earned** ones — with a path
   into the full collection.
2. One-time "moment" badges should be a **pleasant surprise**: hidden until earned,
   not pre-shown as "?" mystery tiles.
3. The earn celebration should be **app-wide and immediate** — it currently only fires
   while the user happens to be on the Insights tab.

## Goals

- Surface recently-earned badges prominently on Insights; tapping opens the full set.
- Hide unearned moment badges entirely until they're earned.
- Make the earn-celebration popup appear over any screen, the moment a badge is earned.
- Declutter Insights into a clear visual hierarchy without removing any feature.

## Non-goals (explicitly out of scope)

- No 6th tab. The tab bar (Today, Vault, Favorites, Friends, Insights) stays as-is.
- No merging of History and Taste Arc — they do genuinely different things.
- No folding the Wrapped button into the recap banner — Wrapped stays reachable
  year-round; the banner only shows near month boundaries.

## Architecture

### 1. `BadgeCenter` — promote the badge engine to the app shell

Today `BadgesViewModel` is instantiated *inside* `InsightsView`, so badge derivation
and the newly-earned diff only run on that tab. We promote this to a shared,
app-level object so it can drive an app-wide celebration and feed both the Insights
shelf and the full Badges page from one source of truth.

- Introduce `@Observable @MainActor final class BadgeCenter`, held by `AppEnvironment`
  alongside the other stores/services.
- It owns the same dependencies `BadgesViewModel` has today (`EntryService`,
  `ListensStore`, `FavoritesStore`, `RatingsStore`, `CheckInService`,
  `ArchetypeSnapshotStore`, `BadgeSeenStore`) plus the new earn-log (below).
- Public surface:
  - `badges: [EarnedBadge]` — the full derived list.
  - `summary: Summary` — for any compact display (earned count, nearest goal, etc.).
  - `recent: [EarnedBadge]` — earned badges sorted newest-first (for the shelf).
  - `celebrating: EarnedBadge?` — head of the newly-earned queue (drives the overlay).
  - `func refresh() async` — re-derives from the live stores and recomputes the
    newly-earned queue.
  - `func acknowledgeCelebration()` — marks the head seen and advances the queue
    (same semantics as today's `BadgesViewModel.acknowledgeCelebration`).
- The existing pure summary builder and `BadgeSeenStore` diff logic move into / are
  reused by `BadgeCenter`. `BadgesViewModel` is removed (its responsibilities are now
  the center's) unless a thin view-facing wrapper proves convenient during planning.

### 2. App-wide, immediate celebration

`MainTabView` becomes the celebration host:

- A `.task(id:)` keyed on a composite "badge signal" derived from the relevant store
  state — listens (`listensStore.heardAt`), favorites (`favoritesStore.ids`), ratings
  (`ratingsStore.ratings`), check-ins, and archetype-reveal state — calls
  `env.badgeCenter.refresh()` whenever any of them changes. Because those stores update
  optimistically the instant the user acts (saves a song, catches a drop, logs a
  listen, rates, reveals), the refresh runs right after the action and the new badge
  surfaces immediately. This mirrors the existing `.task(id:)` pattern already used in
  `InsightsView` and `MainTabView`.
- An `.overlay` on the `TabView` presents the dimmed scrim + `BadgeCelebrationCard`
  whenever `env.badgeCenter.celebrating != nil`, so it appears over whatever tab is
  showing. The card and its slide-up/scrim transition are reused unchanged from
  `BadgeCelebrationCard.swift`; only the host moves from `InsightsView` to `MainTabView`.
- Multiple simultaneous earns queue and show one at a time (this queue behavior already
  exists; it just lives in `BadgeCenter` now).
- `InsightsView` drops its own celebration overlay and its own `BadgesViewModel`
  instance, reading `env.badgeCenter` instead.

### 3. Earn timestamps → real "recently earned" ordering

`EarnedBadge` carries no earn date, and `BadgeSeenStore` only records *seen* keys, so
there is no basis for "recently acquired" ordering today.

- Add a small persisted **earn-log** (UserDefaults-backed, same pattern as
  `BadgeSeenStore`) mapping a badge **id** → the most recent earn `Date`. It is updated
  whenever a badge first becomes earned and on each subsequent tier-up.
- `BadgeCenter.recent` returns earned badges sorted by that date, newest first.
- **First-run baseline:** on the very first derivation, all already-earned badges are
  recorded with a single baseline timestamp (consistent with `BadgeSeenStore`'s silent
  baseline so the user isn't spammed). Ordering among those pre-existing earns is
  arbitrary (falls back to catalog order) — acceptable as a one-time condition.
- This log is independent of `BadgeSeenStore`: seen-state gates *celebration*, the
  earn-log drives *ordering*. Earned-ness itself still derives purely from inputs and
  depends on neither.

### 4. Insights, decluttered

`InsightsView` content order becomes:

1. Recap moment banner (unchanged; only shows near month boundaries).
2. `TasteMirrorBoard` — the hero, unchanged.
3. **Recent badges shelf** (new) — replaces `badgesSummaryCard`.
4. **History row** — demoted from a full hero card to a lighter, compact row.
5. **Taste Arc row** — demoted from a full hero card to a lighter, compact row.
6. "See your month" Wrapped button (unchanged).

This yields four clear tiers: **hero (mirror) → reward (badges) → quiet links
(history, arc) → action (Wrapped)**.

**Recent badges shelf:**

- A single card with a header row: `RECENTLY EARNED` label on the left, `View all N ›`
  on the right (N = total earned), tinted to the active archetype accent.
- A horizontal row of the latest 3–4 earned badges from `badgeCenter.recent`, each a
  radial-gradient disc with the badge glyph and a short label underneath
  (e.g. "Streak ×14", "Mint ×25"). A trailing "more ›" affordance when there are more.
- The whole card is a `NavigationLink` into the full Badges page.
- Empty state (no badges earned yet): a quiet prompt rather than an empty row
  (e.g. "Earn your first badge by catching a drop").

**History & Taste Arc demotion:**

- Keep both as `NavigationLink`s to their existing destinations (`HistoryView`,
  `TasteArcTimelineView`) — only the *label* styling changes from the current full
  hero-card treatment to a lighter, shorter row (smaller icon, single-line summary,
  chevron), visually subordinate to the taste mirror and badges shelf.

### 5. Full Badges page

The destination pushed from the shelf's "View all" (a refactor of today's
`BadgesView`). Sections top to bottom:

1. **Hero** — earned count + current streak, as two clean stats. (No "close to next" —
   it tested as too vague.)
2. **In Progress** — the tiered badges grid, each tile with its progress bar and the
   concrete `value · next threshold` (or `MAX`). This is where the "× to go" detail
   lives, moved off Insights.
3. **Moments · Unlocked** — only the moments the user has actually earned, each with
   its glyph, title, and flavor subtitle. **Unearned moments are not rendered at all** —
   no "?" mystery tiles. The section header/section is omitted entirely when none are
   earned yet.
4. **Footer hint** — a soft, italic single line: *"✨ Some badges stay secret until you
   earn them."* No count, no icons — it signals hidden treasure exists without revealing
   what or how many.

## Components & boundaries

- `BadgeCenter` (new, app-level) — owns derivation, summary, recent ordering, and the
  celebration queue. One clear purpose: be the single source of badge truth and earn
  events for the whole app. Depends on the existing stores + `BadgeService` +
  `BadgeSeenStore` + new earn-log.
- Earn-log store (new) — pure persistence of badge id → latest earn date. No derivation
  logic; testable in isolation.
- `MainTabView` — gains the celebration host responsibilities (task-driven refresh +
  overlay). No badge logic of its own; it only presents what `BadgeCenter` exposes.
- `InsightsView` — consumes `BadgeCenter`; renders the recent shelf and the demoted
  rows. No longer instantiates a badge view model or hosts a celebration.
- Badges page view (refactored `BadgesView`) — pure presentation of `[EarnedBadge]`
  into hero / in-progress / unlocked-moments / hint.

## Testing

- **Earn-log ordering:** earning badges in a known sequence yields `recent` sorted
  newest-first; a tier-up moves a badge to the front.
- **First-run baseline:** pre-existing earns are recorded silently and produce no
  celebration on first derivation; ordering falls back to catalog order.
- **Moments hidden:** the Badges page renders zero locked-moment tiles; the
  Moments section is absent when no moments are earned and present (earned-only) when
  some are.
- **Celebration queue:** multiple simultaneous earns surface one at a time and each
  `acknowledgeCelebration` advances to the next, then clears.
- Existing `BadgeDeriver` / `BadgeMath` / `BadgeSeenStore` tests stay green; earned-ness
  remains a pure function of inputs, independent of the earn-log and seen-state.

## Open questions

None — design approved 2026-06-19.
