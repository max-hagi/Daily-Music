# UIKit-Hosted Listening Transition

**Date:** 2026-06-17
**Status:** Approved

## Problem

The Today-to-Listening transition currently animates a large SwiftUI overlay while
Today remains live underneath it. Transition progress, gesture state, Today scroll
state, playback, artwork effects, and decorative animations can all invalidate view
state during the same handoff. The result is dropped frames during motion and visible
flashes or jumps at the transition boundaries.

The pull-down and pull-up interaction is valuable and must remain, but the full screen
does not need to track the finger continuously.

## Goals

- Preserve pull down from Today to enter Listening.
- Preserve pull up from Listening to return to Today.
- Preserve both arming rings, thresholds, velocity commits, and haptics.
- Animate one already-laid-out UIKit layer after the gesture commits.
- Keep Today visually and structurally unchanged throughout presentation.
- Prevent playback and repeating decorative effects from starting mid-transition.
- Eliminate start, end, black, and partially rendered frames.
- Preserve Reduce Motion behavior and VoiceOver escape actions.

## Non-Goals

- The presented screen will not track the finger across the full display.
- The listening layout, playback controls, collection threshold, artwork treatment,
  and archive presentation behavior will not be redesigned.
- Today will not scroll to another section as part of this transition.
- The rejected curtain mask and `.drawingGroup()` approaches will not return.

## Interaction

On Today, a downward pull continues to fill the existing arming ring. Releasing with
a full ring, or releasing with sufficient downward velocity, commits presentation.
An incomplete slow pull cancels and restores the resting Today state.

Inside Listening, an upward pull continues to fill the dismissal ring and may retain
the small foreground rubber-band feedback. Releasing with a full ring, or sufficient
upward velocity, commits dismissal. An incomplete slow pull springs the foreground
feedback back to rest without moving the full-screen host.

Once either gesture commits, the gesture no longer drives transition progress. A
single UIKit property animator completes the screen movement with a consistent curve.

## Architecture

`TodayView` remains responsible for the intent to open or close Listening, but it no
longer offsets `ListeningView` or owns per-frame presentation progress.

A dedicated SwiftUI-to-UIKit bridge owns a lightweight container view controller and
one child `UIHostingController` whose root is `ListeningView`. The bridge receives the
current entry, preloaded artwork, readiness state, and callbacks through explicit
inputs. `AppEnvironment` is injected into the hosted SwiftUI root.

The transition host owns this lifecycle:

1. **Idle:** no listening controller is attached.
2. **Preparing:** create the hosting controller, attach it above Today, constrain it to
   the container, force layout, and place its view one container height above rest.
3. **Presenting:** animate only the hosted view's UIKit transform to identity.
4. **Presented:** clear the transform, mark Listening ready, then start playback and
   decorative animations.
5. **Dismissing:** disable duplicate dismissal requests and animate the hosted view's
   transform one container height upward.
6. **Teardown:** detach the hosting controller, return to idle, and stop playback.

Today remains mounted underneath and receives no scroll-position mutation during any
phase. Because the listening surface is opaque, the two screens do not need a
cross-fade or coordinated layout animation.

## Animator Behavior

Entrance and exit use `UIViewPropertyAnimator` with a spring timing curve. The hosted
view is fully created and laid out before the entrance animator starts. UIKit changes
only its transform, allowing Core Animation to composite the movement without asking
SwiftUI to recalculate transition progress on every frame.

The host ignores repeated presentation requests while preparing, presenting, or
presented. It also ignores duplicate dismissals while dismissal is in flight. Animator
completion is the only place that changes readiness or tears down the child controller.

If the container size changes, the next animation uses the latest bounds. An active
animation completes using its captured start geometry rather than jumping to a new
offset.

## Listening Readiness

For Today presentation, `ListeningView` renders its complete static player immediately
but receives `isTransitionReady == false` until the UIKit entrance completes. While it
is not ready, it does not:

- start or resume playback;
- sample listen-threshold time;
- start artwork breathing, hint bobbing, intro pulse, or equalizer animation;
- accept dismissal gestures.

Archive and Favorites presentations retain their existing defaults and behavior.

## Reduce Motion And Accessibility

With Reduce Motion enabled, the host replaces vertical travel with a short opacity
transition while preserving the same prepare, ready, dismiss, and teardown ordering.
The existing named accessibility actions continue to open and close Listening without
requiring a gesture. VoiceOver focus moves into Listening after readiness and returns
to Today after teardown.

## Failure Handling

If the entry disappears before preparation completes, the host cancels presentation
and removes any partially attached controller. If presentation is interrupted, the
host resolves to either fully presented or fully idle based on animator completion
position, never a partially mounted phase. Playback teardown remains idempotent so a
clip-finish dismissal and a user dismissal cannot stop or detach twice.

## Testing

Pure tests cover the host-facing lifecycle policy:

- only idle can begin presentation;
- readiness begins only after presentation completion;
- duplicate presentation and dismissal intents are ignored;
- dismissal keeps the player mounted until animation completion;
- teardown returns to idle exactly once;
- Reduce Motion follows the same callback ordering.

Focused tests continue to cover pull thresholds, velocity commits, and cancellation.
Simulator verification checks:

- pull-down entrance has no hitch or flash at either boundary;
- pull-up dismissal has no hitch or flash at either boundary;
- cancelled pulls leave the current screen unchanged;
- horizontal scrubbing does not arm dismissal;
- playback starts only after the player is fully visible;
- Today does not jump or scroll beneath the player;
- repeated rapid gestures cannot create duplicate players;
- Reduce Motion enters and exits cleanly.

