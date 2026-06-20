# Friends Feed + Today Social Bubbles — Design (Phase 1)

**Date:** 2026-06-20
**Status:** Approved for planning
**Scope:** Phase 1 only (no backend changes). Phase 2 is sketched at the end as future work.

## Problem

The Friends tab feels detached from the rest of the app. Every other surface
(Today, Insights, FriendInsights) is custom art-directed — immersive artwork
backdrops, gradient washes, heavy rounded display fonts, glass pills, cover
stacks. [`FriendsView`](../../../Daily%20Music/Views/Friends/FriendsView.swift)
is a stock SwiftUI `List` with system `Section` headers: grey grouped-list
chrome dropped into a designed app. It works, but it looks like iOS Settings.

Separately, Today is a solitary experience. There's no signal that friends are
engaging with the same daily drop, so the social layer is invisible until you
deliberately open a friend's mirror.

## Goals

1. Redesign the Friends tab as an **art-directed activity feed** that matches
   the app's visual language.
2. Make Today feel **alive and social** with floating friend "reaction" bubbles
   on the hero artwork.
3. Ship both with **zero backend changes** by riding on data that already flows.

## Non-goals (Phase 1)

- Sharing friends' **badges** or **streaks** (local-only today; deferred to Phase 2).
- **Friend-scoped emoji reactions** beyond loved/passed (the 🔥❤️😌💫 reaction
  bar stays anonymous-aggregate; deferred to Phase 2).
- Any schema migration or new RPC.

## Key data reality

What is already queryable per-friend, live:

| Signal | Source | Status |
|---|---|---|
| Friend **ratings** (loved `+1` / passed `-1`) | `friend_ratings` RPC via [`FriendService.friendRatings(friendID:)`](../../../Daily%20Music/Services/FriendService.swift) | ✅ live |
| **Taste match** (you vs them) | `TasteComparison.build` over ratings | ✅ live |
| Friends list + profiles | `my_friends` RPC via `FriendsStore` | ✅ live |
| Friend **reactions** (emoji) | `reaction_counts` RPC | ❌ anonymous aggregate only |
| Friend **badges / streaks** | `BadgeCenter` (derived from *own* local stores) | ❌ local-only |

Because every user gets the **same daily drop**, "which of my friends loved /
passed today's song" is a clean, already-answerable question via
`friendRatings`. Phase 1 is built entirely on the ✅ rows.

## Design

### Decisions locked during brainstorming

- Friends tab becomes a **feed**, three zones (validated visually).
- **No personal badge showcase** — the user does not want to see their own badges.
  Friends' badges (Phase 2) are the only badge surface.
- Today bubbles use **Option B: floating on the artwork**, capped ~3–4 visible
  + "+N" overflow.
- Bubbles include a **"passed" (👎)** state from a `-1` rating, worded gently.
- Bubbles are **revealed after the user listens or rates**, animating in as a
  payoff (avoids biasing the user's own rating; gives the bubbles a moment).

### Component 1 — Friends tab redesign

Replace the `List` body of `FriendsView` with a themed `ScrollView`. Reuse the
existing visual primitives already used elsewhere: gradient `wash` background
(see `FriendInsightsView.wash`), `Theme.Surface.card` rounded cards,
`Theme.Radius`/`Theme.Spacing`, `glassPillStyle`, `InitialsAvatar`,
`AlbumArtView`, the rounded-heavy display fonts.

Zones, top to bottom:

1. **Invite header card** — your friend code, QR (`QRCodeView`), and `ShareLink`,
   styled as an art-directed card instead of a list section. Slim. No badges.
2. **Activity feed** (new) — a vertical run of `FriendActivityRow`s. Incoming
   friend **requests** fold in here as actionable rows (accept/decline) when
   present, so they're not a separate stock section.
3. **Your friends** — one row per friend: avatar, name, a **taste-match % bar**,
   chevron into `FriendInsightsView`. Preserve the existing **nudge** button and
   **swipe-to-remove**.

Behavior preserved from today's `FriendsView`: deep-link friend-code prefill,
`store.load()` on appear, pull-to-refresh, keyboard "Done" toolbar.

### Component 2 — Activity feed model (Phase 1, ratings-powered)

New `FriendsActivityStore` (`@MainActor @Observable`), assembled from existing
services (`FriendService`, `EntryService`, `RatingService`):

- For a small recent window (e.g. today + a few prior drops), fetch each friend's
  rating via `friendRatings(friendID:)` and join with `entries.publishedHistory()`.
- Emit feed items:
  - **Loved / passed today's drop** — `"{name} loved today's drop"` /
    `"{name} passed on today's drop"`, with the entry's cover + a ❤️ / 👎 bubble.
  - **Taste-match highlight** (optional, low priority) — surfaces when a friend's
    match % is notably high, reusing `TasteComparison`.
- Items are value types (`FriendActivityItem`) with: friend profile, kind
  (loved / passed / matchHighlight), optional entry, timestamp-ish ordering key.
  Ordering: today's drop first, then recency by entry date.
- Degrade gracefully: a friend with no rating contributes no item; a failed fetch
  yields an empty feed, never an error screen.

`FriendActivityRow` renders one item: avatar + text + optional cover + reaction
bubble, in the shared bubble visual language (so Today and Friends match).

### Component 3 — Today floating bubbles

New `FriendReactionBubbles` view overlaid on the **Today hero artwork** (the
album-art region rendered through `EntryDetailView` in immersive mode; exact
attachment point is an implementation detail for the plan).

- **Data:** fetch friends' ratings for **today's entry** only (one
  `friendRatings` call per friend, or a batched assembly in
  `FriendsActivityStore`). Friends with a rating become a bubble: loved → ❤️,
  passed → 👎. Friends with no rating are omitted.
- **Layout:** small `avatar + emoji` capsules pinned around the artwork at a few
  fixed anchor positions. Show at most 3–4; collapse the rest into a "+N" bubble.
- **Reveal gating:** hidden until the user has **listened or rated** today's
  song. Reuse `env.listensStore.isHeard(entry)` (already drives the new-drop
  prompt) and/or presence of the user's own rating. On reveal, bubbles animate in
  (spring scale/opacity); respect `accessibilityReduceMotion`.
- **Coexistence:** this is distinct from the existing anonymous `ReactionsBar`
  emoji row. The bubbles are friend-attributed (from ratings); the reaction bar
  stays as-is.
- **Accessibility:** each bubble exposes a combined label, e.g. "Alex loved this".

## Architecture / data flow

```
FriendService.friendRatings(friendID:)  ─┐
EntryService.publishedHistory()          ├─► FriendsActivityStore ─► FriendActivityItem[]
RatingService.myRatings() (for match)   ─┘            │
                                                      ├─► FriendsView feed (FriendActivityRow)
                                                      └─► TodayView bubbles (FriendReactionBubbles, today only)
```

`FriendsActivityStore` lives on `AppEnvironment` (like `FriendsStore`) so both
Friends and Today read one consistent assembly. It loads on appear and on
pull-to-refresh; Today consumes the today-entry slice.

## Error handling

- Every cross-user fetch is best-effort (`try?`); a nil result contributes
  nothing rather than surfacing an error.
- Empty feed → a friendly empty state in the Friends tab (reuse the existing
  "no friends yet / share your invite" treatment when there are no friends; show
  a quiet "no activity yet" when there are friends but no recent ratings).
- Today bubbles simply don't render when there's no friend rating data.

## Testing

- `FriendsActivityStore` pure assembly: given seeded friend ratings + entries,
  it produces the expected loved/passed items in the expected order, and omits
  friends without ratings. Use `MockFriendService` (already seeds Alex's ratings)
  + `MockEntryService`.
- Bubble reveal gating: bubbles are absent before listen/rate and present after
  (pure predicate test on the gating condition).
- Taste-match highlight threshold (if included): boundary test.
- Follow existing test registration conventions (manual pbxproj registration per
  project notes).

## Phase 2 — future work (not in this spec)

Requires a backend seam so friends can **publish** local-only signals:

- A `friend_activity` table + publish-on-earn (badges, streak milestones) + a
  read RPC scoped to friendships via RLS.
- Feed gains **"{name} earned {badge}"** and **"{name} hit a {n}-day streak"** items.
- Optional friend-scoped **emoji reactions** (extend bubbles beyond loved/passed).

Phase 2 gets its own spec → plan once Phase 1 is live.
