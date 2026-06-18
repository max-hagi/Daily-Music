# Listening Fluidity and Today Scrollbar

**Date:** 2026-06-18
**Status:** Approved

## Problem

The Today-to-Listening and Listening-to-Today transitions feel clunky because
multiple systems animate the same full-screen change. UIKit owns the hosted
Listening slide while SwiftUI separately stages and moves Today during return.
The result is a discrete handoff instead of one continuous gesture response.

Today's immersive entry also exposes a vertical scroll indicator that adds
unwanted chrome to the full-screen artwork experience.

## Goals

- Make both directions respond continuously to the user's vertical gesture.
- Use one transition state and geometry model for presentation and dismissal.
- Settle committed or cancelled gestures smoothly from their current position.
- Keep the expensive blurred artwork backdrop stationary during finger tracking.
- Hide only the Today immersive scroll indicator while preserving scrolling.
- Respect Reduce Motion.

## Design

### Transition ownership

`TodayView` owns a single normalized presentation value:

- `0`: Listening is fully above Today.
- `1`: Listening fully covers Today.
- Intermediate values: Listening follows the active pull or dismissal gesture.

The same value drives both directions. Presentation begins from Today's pull
progress and settles to `1` when committed or `0` when cancelled. Dismissal
starts at `1`, follows the upward drag, and settles to `0` when committed or
back to `1` when cancelled. Listening remains mounted until a committed return
finishes, then playback is stopped and the hierarchy is detached.

The UIKit host no longer runs an independent entrance or exit animation. It
hosts the Listening hierarchy and applies the presentation geometry supplied by
Today. This removes the current UIKit/SwiftUI animation handoff.

### Motion and performance

The opaque Listening surface moves vertically, so Today never shows through it
as a cross-fade. During gesture tracking, only lightweight foreground geometry
is updated; artwork bloom and blur remain stationary within their hosted layer.
On release, a spring continues from the current presentation value instead of
restarting from an endpoint. Existing arming thresholds, velocity commits,
haptics, and full-screen gesture hit areas remain intact.

With Reduce Motion enabled, gestures retain their interaction semantics but the
committed screen change uses a short opacity transition rather than a full
vertical travel.

### Today scrollbar

Apply `.scrollIndicators(.hidden)` to the immersive `ScrollView` used by Today.
Do not change standard entry detail screens or any other app scroll container.

## State and responsibilities

- `ListeningTransition.swift`: pure transition phase, normalized geometry,
  gesture mapping, velocity, and commit/cancel policy.
- `TodayView.swift`: mount lifecycle, shared presentation value, and cleanup.
- `EntryDetailImmersive.swift`: reports Today's downward pull continuously and
  hides its own indicator.
- `ListeningView.swift`: reports upward dismissal gesture changes and outcomes.
- `UIKitListeningTransitionHost.swift`: hosts content without starting a second
  full-screen animator.
- `TodayListeningTests.swift`: covers phase ordering, geometry, commit/cancel,
  duplicate requests, and Reduce Motion policy.

## Error and interruption handling

- Duplicate presentation or dismissal requests are ignored while transitioning.
- A cancelled gesture springs to the currently active screen.
- If the host disappears mid-transition, it detaches without firing duplicate
  playback cleanup.
- Rotation or size changes recompute offsets from the normalized presentation
  value rather than retaining a stale point offset.

## Verification

- Focused unit tests prove lifecycle and transition math before implementation.
- Build and run the existing `TodayListeningTests` suite.
- In the simulator, verify slow drags, fast flicks, threshold cancellation, both
  directions, Reduce Motion, rotation, playback cleanup, and no Today indicator.
- Confirm Vault and Favorites Listening presentation behavior is unchanged.

## Out of scope

- Changing Today content, Listening controls, gesture thresholds, or arming-ring
  visuals.
- Hiding scroll indicators outside Today's immersive entry.
- Reworking Vault or Favorites presentation.
