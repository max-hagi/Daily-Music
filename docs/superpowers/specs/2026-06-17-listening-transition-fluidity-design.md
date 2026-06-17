# Listening Transition Fluidity

**Date:** 2026-06-17
**Status:** Approved

## Problem

The custom Today-to-Listening transition has several state and motion discontinuities:

1. The new-drop prompt mounts `ListeningView` without presenting it, so playback can begin while the player remains off-screen.
2. Entering listening moves Today's backing scroll position to the journal before the player covers it, exposing a one-frame content snap.
3. The dismiss gesture moves only the foreground while the bloom remains fixed, then starts a separate full-screen spring after release.
4. Gesture direction is recalculated continuously instead of locked, allowing a partially armed dismissal to freeze or overlap with scrubbing.
5. Playback and decorative animations begin while the entrance spring is still running.

## Goals

- Use one entrance path for pull-to-listen, replay, and the new-drop prompt.
- Keep the currently visible Today content stable throughout the entrance.
- Reveal the journal directly when Listening is dismissed.
- Make the entire Listening screen follow an upward dismiss drag.
- Preserve horizontal scrubber gestures.
- Carry gesture velocity into commit and cancel animations.
- Avoid starting playback and repeating decorative animations during the entrance.
- Preserve Reduce Motion behavior and the existing arming-ring feedback.

## Non-Goals

- Replacing the custom transition with `fullScreenCover`.
- Changing the listening layout, playback controls, collection threshold, or artwork cache.
- Changing Vault or Favorites presentation behavior beyond preserving their current defaults.
- Reintroducing the rejected curtain mask or `.drawingGroup()` implementation.

## Architecture

`TodayView` remains the source of truth for the player mount state and the `presentation` value, where `0` is fully above Today and `1` is fully covering it. `ListeningView` receives that binding and updates it during a Today dismiss drag.

The transition is divided into explicit phases:

1. **Idle:** Listening is unmounted and `presentation == 0`.
2. **Entering:** Listening mounts at `presentation == 0`, then animates to `1` on the next update cycle.
3. **Presented:** Once the entrance completes, Today scrolls to `.journal` while fully covered and Listening starts playback and decorative animations.
4. **Dragging:** An axis-locked upward drag updates `presentation` continuously from `1` toward `0`.
5. **Settling:** Release commits toward `0` or cancels toward `1` using the measured velocity.
6. **Idle after commit:** Listening unmounts only after reaching `0`; Today is already positioned at `.journal`.

All entrance triggers call the same `beginListening()` function. No caller mutates `showingListening` directly.

## Entrance Sequencing

`beginListening()` performs these operations in order:

1. Guard against an existing entrance or presented player.
2. Reset `presentation` to `0` and mount Listening.
3. Yield one main-actor update so SwiftUI lays out the off-screen player.
4. Animate `presentation` to `1` using the existing entrance spring.
5. In the animation completion, set Today's immersive scroll position to `.journal`, clear the enter arming state, and mark Listening ready.

Reduce Motion skips the spring but preserves ordering: mount, cover immediately, then update the hidden backing view and mark Listening ready.

## Direct Dismiss Gesture

The dismiss gesture locks to one axis after the initial movement passes the minimum distance:

- Vertical-up locks dismissal and prevents later horizontal drift from changing modes.
- Horizontal locks the gesture out of dismissal, leaving the scrubber path untouched.
- Downward or indeterminate motion does not arm dismissal.

While vertically locked, upward translation maps to presentation as:

`presentation = clamp(1 - upwardTranslation / viewHeight)`

The arming ring continues using the shorter existing threshold, so it can indicate a committed release before the player has traveled the full screen.

On release, the existing threshold and velocity policy chooses commit or cancel. Commit animates to `0`; cancel animates to `1`. The settling animation uses normalized gesture velocity so a flick continues naturally instead of restarting from rest.

The separate foreground offset and scale are removed. The player layer itself is the only moving surface.

## Playback and Animation Readiness

`ListeningView` receives a readiness value for Today presentations. Until ready:

- It renders the complete static player using preloaded artwork.
- It does not start playback.
- It does not start the breathing, hint-bob, intro-pulse, or equalizer animations.

Vault and Favorites default to ready because their system presentation already controls entrance timing.

If the player is dismissed before readiness, the pending playback task exits without starting audio.

## Rendering Strategy

The player continues to move through a parent transform, keeping the album-art blur visually static within that layer. `.drawingGroup()` remains prohibited because it previously produced a black mount frame. A compositing modifier is added only if simulator or device verification shows the parent transform is not already compositor-only.

## Edge Cases

- Repeated entrance requests while entering or presented are ignored.
- A clip-finish auto-dismiss and a user swipe share one dismissal guard so only one settling animation runs.
- Cancelled dismissal resets the gesture axis and ring state after returning to `presentation == 1`.
- Committed dismissal stops playback after unmounting.
- Rotation or size changes use the latest measured height without changing the normalized presentation value.
- Reduce Motion has no entrance or exit travel animation but preserves correct mount, backing-view, playback, and teardown ordering.

## Testing

Pure tests cover:

- the backing Today section changes only after entrance completion;
- every entrance source uses the same transition intent;
- axis resolution locks vertical and horizontal gestures correctly;
- drag translation maps to clamped presentation values;
- commit and cancel choose `0` and `1` respectively;
- normalized release velocity has the correct sign and scale.

Verification also includes:

- the full unit test suite;
- new-drop prompt entrance starts visible playback only after presentation;
- pull-to-listen entrance shows no Today content snap;
- swipe-up tracks the entire player under the finger;
- cancellation returns smoothly to rest;
- horizontal scrubbing never arms dismissal;
- clip finish cannot start a competing dismissal;
- Reduce Motion enters and exits without flashes.
