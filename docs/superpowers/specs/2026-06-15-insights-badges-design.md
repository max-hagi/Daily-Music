# Insights Badges — design

> Status: approved design, ready for implementation plan.
> Date: 2026-06-15

## Goal

Add a gamification layer to the **Insights** tab: a set of badges that reward the
daily ritual the app is built around. Badges are **derived** from data the app
already tracks and syncs (listens, streak, favorites, ratings) — no new backend
for v1. The feature reinforces the existing retention loop (streaks, reminders,
widget) by giving the user visible goals to pull toward and small celebrations
when they hit them.

## Intent decisions (settled during brainstorming)

- **Core job:** reward the daily habit (showing up, catching drops on their day),
  not pure collection or taste exploration.
- **Model:** mixed — **tiered** badges for things you count, **one-time** badges
  for special moments.
- **Locked visibility:** tiered counts are visible as goals (with progress to the
  next tier); moments are hidden ("?" mystery tiles) until earned, so they stay a
  delight.
- **Earn moment:** lightweight — a celebration card/toast with haptic when the
  user next opens Insights, dismissable. No full-screen interrupt.
- **Placement:** a single **summary card** in the Insights scroll that taps into a
  dedicated full badge screen (Approach A from layout mockups).
- **Architecture:** Approach C — build the pure-derived version now, but behind a
  `BadgeService` protocol seam so a Supabase-backed source (for friend-profile
  badges / sharing) can be added later without reworking the UI.

## Badge set

### Tiered — counts (visible as goals, progress bar to next tier)

| Badge          | Symbol | Source                                              | Tiers              |
| -------------- | ------ | --------------------------------------------------- | ------------------ |
| Daily Streak   | 🔥     | `Streak.best` (and `current` for the live number)   | 3 · 7 · 14 · 30 · 100 |
| Mint Collector | 💿     | count of listens with status `.heardSameDay`        | 5 · 25 · 50 · 100 · 250 |
| Crate Digger   | 🗄️     | `ListensStore.collectionCount`                      | 10 · 50 · 100 · 250 |
| Kept Forever   | ❤️     | `FavoritesStore.ids.count` (saved/favourited songs) | 5 · 25 · 50 · 100  |
| Critic         | ⚖️     | count of songs rated 👍/👎                          | 10 · 50 · 100 · 250 |
| Rescuer        | 🛟     | count of listens with status `.rescued`             | 1 · 5 · 10 · 25    |

Tier progression: a badge's "unlocked tier" is the highest threshold it has met;
progress = current value mapped between the current tier and the next. Past the
top tier, the badge is fully maxed (no progress bar, show "max" state).

### Moments — one-time (hidden until earned)

| Badge         | Symbol | Earn condition                                                       |
| ------------- | ------ | ------------------------------------------------------------------- |
| First Press   | ✨     | First ever song heard on its drop day (`.heardSameDay`).            |
| Perfect Week  | 🗓️     | 7 consecutive drops each caught same-day (a 7-long mint run).        |
| Comeback      | 🌱     | Rebuilt a streak back to ≥7 after a previous streak broke.          |
| Night Owl     | 🦉     | Caught a drop after midnight (derived from `heardAt` time-of-day).   |
| Flawless Month| 🌕     | A full calendar month with zero missed drops.                       |
| Revealed      | 🔮     | Unlocked the first taste archetype (ties to existing reveal).       |

Unearned moments render as a generic "?" mystery tile — the user knows a moment
exists but not what it is.

## Architecture

The app is MVVM + a swappable service layer (see `docs/ARCHITECTURE.md`). Badges
follow the same shape.

### Models — `Badge.swift`

- `BadgeKind`: `.tiered(thresholds: [Int])` | `.moment`
- `BadgeDefinition`: `id`, `title`, `subtitle`, `systemImage` (or emoji), `kind`,
  `tint` — the static catalogue of all badges. Pure data, no logic.
- `EarnedBadge`: a definition joined with the user's current state —
  `value: Int`, `unlockedTier: Int?` (nil = not yet earned for tiered; for moments
  a simple `isEarned: Bool`), `progressToNext: Double?`, `nextThreshold: Int?`,
  `isMaxed: Bool`. Identifiable by definition id.
- Helper on the tiered case to compute `unlockedTier` / `progressToNext` /
  `nextThreshold` from a raw value + thresholds — pure, unit-testable.

### Service — `BadgeService` protocol + `DerivedBadgeService`

- `protocol BadgeService { func badges() async -> [EarnedBadge] }` (the seam).
- `DerivedBadgeService` is constructed with the inputs it needs (the listen
  records / `ListensStore` data, `Streak`, favorite ids, ratings map, archetype
  snapshot state). It computes every `EarnedBadge` synchronously from those
  snapshots. Kept free of UI types so it can be tested with fixtures.
- Future `SupabaseBadgeService` (or a `FriendBadgeService`) can implement the same
  protocol for cross-device / friend-profile badges. Not built in v1.

### Seen state — `BadgeSeenStore`

- A small `UserDefaults`-backed store of "already-celebrated" keys. A key encodes
  badge id + tier (e.g. `mint:50`, or `moment:firstPress`) so each new *tier* can
  celebrate once, not just the first unlock.
- Mirrors `ArchetypeSnapshotStore`'s pattern. **Nothing about whether a badge is
  earned depends on this store** — it only decides whether to *celebrate*. A
  reinstall re-derives all badges correctly; at worst a few recently-earned ones
  re-celebrate once.

### View model — `BadgesViewModel` (`@MainActor @Observable`)

- Loads `[EarnedBadge]` via the `BadgeService`.
- Diffs earned badges/tiers against `BadgeSeenStore` to produce a list of
  **newly-earned** badges to celebrate (then marks them seen on acknowledge).
- Exposes a `summary` for the Insights card: earned count, count "close" to next
  tier, the single nearest goal line, and a small peek strip (a few representative
  discs, earned first).
- Exposes the full ordered list for `BadgesView` (tiered section then moments).

## UI

### Insights summary card

- Lives in `InsightsView`'s content stack, between the `TasteMirrorBoard` hero and
  the existing history card.
- Built like the existing `historySummaryCard` / `tasteArcCard`: a glass card with
  a leading icon, an uppercase `YOUR BADGES` label, a headline (e.g. `9 earned ·
  3 close`), the nearest-goal line (e.g. `Daily Streak — 16 days to one month`),
  a 5-disc peek strip, and a chevron.
- Wrapped in a `NavigationLink` to `BadgesView`, using `PressableCardButtonStyle`.

### BadgesView (full screen)

- Scrollable, two sections matching the approved mockup:
  - **Tiered** — each badge as a disc + name + subtitle + progress bar + "X · next:
    Y" tier label (or a maxed state).
  - **Moments** — earned ones show their real disc + name; unearned render as "?"
    mystery tiles.
- Styled with the app's glass/material vocabulary; tinted to the active archetype
  accent like the rest of Insights.

### Earn celebration

- Lightweight. When `InsightsView` appears and `BadgesViewModel` reports
  newly-earned badge(s), present a dismissable celebration card/toast (badge disc,
  title, tier reached) with a `Haptics` cue. Dismiss → mark seen.
- Reuses existing flare/haptic styling; no full-screen cover (that's reserved for
  archetype reveals).

## Testing

TDD the pure derivation, which is deterministic given fixture inputs:

- Tier math: `unlockedTier` / `progressToNext` / `nextThreshold` for values below
  first threshold, exactly on a threshold, between thresholds, and past the max.
- Each tiered badge's value derivation from fixture stores (mint count from
  statuses, crate count, saves, ratings, rescued count).
- Moment predicates: First Press (one mint), Perfect Week (7-in-a-row vs a broken
  run), Comeback (break then rebuild to ≥7), Night Owl (`heardAt` after midnight),
  Flawless Month (a clean month vs a month with a miss), Revealed.
- `BadgeSeenStore` diffing: newly-earned detection, re-earning a higher tier
  celebrates again, already-seen does not re-celebrate.
- Zero-data: empty stores yield all tiered badges at tier 0 and all moments
  unearned, no crashes.

Test registration: per project convention, new test files need manual pbxproj
registration (see memory `apple-music-integration`).

## Out of scope (v1)

- Backend `user_badges` table / persisted `earned_at`.
- Badges on friend profiles; sharing a badge card.
- Push notifications for badge earns.

The `BadgeService` protocol seam keeps all of the above cheap to add later.
