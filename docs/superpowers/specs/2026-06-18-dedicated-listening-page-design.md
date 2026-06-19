# Dedicated Listening Page

**Date:** 2026-06-18
**Status:** Approved

## Problem

The Today-to-Listening transition has remained visibly unstable after several
iterations involving shared SwiftUI geometry, interactive progress, and UIKit
hosting. The current path coordinates Today scrolling, arming progress,
full-screen layer movement, Listening readiness, playback, and teardown. Those
responsibilities make an otherwise simple navigation action sensitive to render
timing and competing animations.

The new-drop prompt also uses an in-memory dismissal flag. Recreating Today or
relaunching the app resets that flag, allowing the prompt to appear repeatedly
on the same day.

## Goals

- Keep the pull-to-fill interaction as the intentional trigger for Listening.
- Present Listening as an independent full-screen page after the gesture commits.
- Use a pleasing native upward page lift with no custom crossfade.
- Keep both swipe-up and a visible Close button as Listening exit controls.
- Show the new-drop prompt at most once per local calendar day.
- Preserve playback, collection thresholds, artwork preload, and accessibility.

## Non-goals

- Making Listening track the user's entrance or dismissal drag.
- Morphing Today artwork or controls into Listening.
- Changing pull thresholds, collection semantics, or Listening content.
- Changing Vault or Favorites presentation behavior.

## Interaction Design

### Entering Listening

Today retains its existing pull gesture and arming ring. While the user pulls,
the ring fills and Today may use its existing lightweight recede feedback. A
cancelled pull resets the ring and does nothing else.

When the pull commits, Today fires the existing haptic, resets its local gesture
feedback, and sets a single presentation Boolean. SwiftUI presents
`ListeningView` through `fullScreenCover`. The standard full-screen-cover motion
lifts the complete Listening page upward from the bottom. No Listening content
is mounted into Today's layer stack and no transition value is shared between
the two views.

### Leaving Listening

Listening keeps its swipe-up arming ring. The drag changes only the ring and any
small local foreground feedback; it never reveals or moves Today. Releasing an
armed swipe invokes the same dismissal callback as the visible Close button.
The full-screen cover then dismisses as one page.

The Close button has an accessibility label, and Listening retains its VoiceOver
Close action. Reduce Motion follows the system full-screen-cover behavior rather
than a custom fade path.

## Architecture

`TodayView` owns a `showingListening` Boolean and presents `ListeningView` with
`fullScreenCover`. It passes the already-loaded artwork and the existing
collection-threshold callback into Listening. It ignores additional committed
pulls while presentation is already active.

The Today path no longer needs normalized full-screen presentation geometry,
Today-to-Listening phase choreography, readiness gating, layer offsets, or a
UIKit-hosted transition. Transition math that still serves the arming threshold
and commit/cancel decision remains pure and reusable.

`ListeningView` uses one dismissal callback for its Close button, swipe-up
commit, accessibility action, and any automatic completion path that should
leave Listening. Presentation-specific geometry is not passed from Today.

Playback starts when the presented Listening page is ready. Dismissal stops
playback exactly once and clears the presentation Boolean. The cover remains
opaque throughout its visible lifetime to prevent Today or a stale player frame
from flashing through.

## Once-per-Day New-Drop Prompt

Replace the session-only dismissal flag with a persisted last-shown day value.
The value represents a local calendar day, not a process session.

When today's loaded entry becomes available, the prompt is eligible only when:

1. The entry is not collected.
2. The stored last-shown value is not the current local calendar day.

Immediately before presenting an eligible prompt, Today persists the current
day. Recording at presentation time prevents view recreation, tab changes, or
app relaunches from showing it again. Dismissing the prompt or opening Listening
does not need a second write. On the next local calendar day, the comparison
naturally makes the prompt eligible again for the new uncollected entry.

## Interruption And Error Handling

- A cancelled or under-threshold entrance pull resets Today feedback.
- Duplicate entrance commits are ignored while the cover is presented.
- Swipe and button exits converge on one idempotent dismissal path.
- If Listening disappears because its presenter is removed, playback cleanup
  still runs without requiring transition completion state.
- Artwork loading failure uses Listening's existing fallback and does not affect
  presentation.
- A missing or unloaded daily entry never records the prompt as shown.

## Testing

Focused tests cover:

- Pull commit and cancellation policy.
- Duplicate presentation suppression.
- Swipe-up and Close-button convergence on one cleanup path.
- Playback cleanup occurring once per dismissal.
- Prompt eligibility when uncollected and not shown today.
- Prompt suppression after it has appeared once on the same day, including an
  app relaunch represented by a new Today instance reading persisted state.
- Prompt eligibility on the next local calendar day.
- Prompt suppression for a collected entry.

Simulator verification covers slow and fast pull commits, cancelled pulls,
repeated open and close cycles, swipe and button dismissal, Reduce Motion,
artwork-load failure, black or stale-frame flashes, and repeated Today visits on
the same day. Vault and Favorites Listening flows are checked for regressions.
