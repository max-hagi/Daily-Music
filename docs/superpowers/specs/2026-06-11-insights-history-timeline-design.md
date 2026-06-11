# Insights History + Taste Arc Timeline — Design

**Date:** 2026-06-11  
**Status:** Approved for implementation planning

## Goal

Reduce clutter in Insights by moving the full song history list to its own
page, then turn the quiet "You started here" memento into a tappable taste arc:
a compact at-a-glance timeline that opens into an interactive history of the
user's past archetype eras.

The engagement principle is **self-recognition over chores**. The timeline
should create the "oh, that was my phase" dopamine hit without points,
leaderboards, streak pressure, or fake tasks.

## Page Order

Insights keeps the current driver-first hierarchy, but the lower page becomes:

1. Recap moment banner, when relevant.
2. `TasteMirrorBoard`.
3. `historySummaryCard`.
4. `tasteArcCard`.
5. `See your month` button.

This removes the long inline history list that currently pushes "See your
month" to the bottom.

## History Destination

### Insights Summary Card

Replace the inline `historySection(accent:)` with a compact button/card:

- Label: `YOUR HISTORY`
- Primary line: `<count> songs in your history`
- Secondary line: newest entry title + date, or the existing empty copy.
- Right affordance: chevron.
- Tap destination: `HistoryView`.

The card should use the app's glass row/card language, not a full primary
button. It is a navigation item, not the main call to action.

### `HistoryView`

`HistoryView` owns the full list currently rendered inline:

- Uses `HistoryEntryRow` unchanged.
- Keeps inline `RatingBar` controls and reloads Insights data after rating
  changes.
- Shows the existing empty state when history is empty.
- Uses a normal navigation title: `History`.

The view can receive `[HistoryEntry]`, `accent`, and `onRatingChanged` from
`InsightsView` in v1. If the list later needs independent refresh/pagination,
it can get its own view model.

## Taste Arc At A Glance

Replace `startedHereCard` with `tasteArcCard`.

### Inputs

- Onboarding start: `startingMood`, `startingGenre`, and `startingDecade`.
- Current archetype: `mirror.archetype` or `.theShapeshifter` fallback.
- Monthly eras: derived from existing published history, ratings, and favorites.
- Known reveal milestones: derived from `ArchetypeSnapshot` where available.

### Card Layout

The card is a compact tappable preview:

- Header: `YOUR TASTE ARC`
- Left capsule: first read, using available onboarding parts.
- Center: 3-5 colored dots on a subtle horizontal arc.
- Right capsule: current archetype.
- One feedback line, chosen from the largest obvious shift:
  - mood shift, when start mood and current leading mood differ.
  - genre shift, when start genre and current leading genre differ.
  - energy shift, when energy moved meaningfully.
  - fallback: "Your taste has been building new shape since day one."
- Chevron affordance.

If there is no onboarding read and too little history, hide the card rather than
showing a fake arc.

## Interactive Timeline

### Destination

Create `TasteArcTimelineView`, opened from the taste arc card.

### Timeline Model

Add a view-model-level model, not domain persistence:

```swift
struct TasteEra: Identifiable, Equatable {
    enum Kind: Equatable {
        case onboarding
        case monthly
        case reveal
        case current
    }

    let id: String
    let kind: Kind
    let date: Date
    let title: String
    let subtitle: String
    let profile: TasteProfile?
    let mirror: TasteMirror?
    let driverLine: String?
    let songs: [DailyEntry]
}
```

Monthly eras are synthesized from real user history:

- Group published entries by calendar month.
- Join each month with ratings and favorites.
- Build a `TasteMirror` from that month's rated/favorited songs.
- Keep months with enough signal to say something real. V1 threshold:
  at least 3 rated/favorited songs in the month.
- Title from the month's profile when unlocked, otherwise the strongest
  available standout such as `Dark era`, `Indie era`, or `High energy era`.

Reveal milestones are special nodes:

- The existing `ArchetypeSnapshot` only stores the current stable/pending IDs
  and evaluation date, so v1 can decorate known current/last reveal data but
  cannot reconstruct a complete historical reveal ledger.
- If a fuller reveal history is added later, those reveal events can be
  inserted between monthly eras without changing the view contract.
- Do not duplicate the current month as both `monthly` and `current`. If the
  current month has enough signal, render it as the `current` node.

### Interaction

The first screen shows a vertical or gently curved timeline:

- Top/current era is visually strongest.
- Onboarding appears as the origin.
- Monthly eras appear as colored capsules.
- Reveal milestones use a distinct sparkle/reveal marker.

Tapping an era expands or selects it:

- Profile/era title.
- Date range.
- Driver line.
- Up to 3 songs that shaped that era.
- Optional "Replay reveal" only for eras tied to a real reveal milestone.

Avoid heavy custom gestures in v1. A scrollable timeline with tappable cards is
enough; scrubbing can be a later enhancement if the first version earns it.

## Data Flow

`InsightsViewModel.load()` already fetches published history and ratings. Extend
it to expose:

- `historyEntries`, unchanged.
- `tasteEras`, derived after history/rating/favorite join.
- A compact `tasteArcSummary` if this keeps `InsightsView` simple.

`InsightsView` passes `favoriteIDs` into `load()` today; monthly eras should use
the same favorite signal as the current mirror.

No network calls are added. No new Supabase schema is required for v1.

## Error And Empty States

- Empty history: show the history summary card with the existing empty copy so
  the destination remains discoverable.
- No onboarding read: omit the onboarding node and start from the earliest
  monthly era.
- Too few monthly songs: show only onboarding and current, or hide the taste arc
  if that would feel thin.
- Unknown persisted archetype IDs: use `TasteProfile.profile(id:)` nil handling
  and fall back to era titles from standouts.
- Rating changes: rebuild history and eras through the existing reload path.

## Visual Tone

The timeline should feel like a memory object, not a dashboard:

- Use archetype colors as small signals, not a full rainbow wash.
- Keep cards tight and scannable.
- Prefer symbols already used in the app (`sparkles`, `flag.checkered`,
  `chevron.right`) and existing glass styling.
- No leaderboards, score counters, XP bars, or achievement spam.

## Testing

Add focused unit coverage for timeline derivation:

- Monthly grouping across multiple months.
- Month threshold excludes weak/noisy eras.
- Favorites join as heart-only signal.
- Onboarding era renders when starting read exists.
- Missing onboarding read still builds monthly/current eras.
- Unknown archetype IDs do not crash.

Manual verification:

- Insights no longer buries "See your month" under the full history list.
- History destination preserves inline rating behavior.
- Taste arc card fits on small screens without text overlap.
- Timeline works in light/dark mode and with Reduce Motion enabled.

## Out Of Scope

- Persisting a complete historical reveal ledger.
- Social sharing of timeline cards.
- Push notifications for era changes.
- Gamified points, badges, or leaderboards.
- Changing the archetype scoring engine.
