# Today return transition

**Date:** 2026-06-18
**Status:** Approved for implementation

## Problem

The Listening-to-Today dismissal currently moves the hosted Listening view off-screen. In practice, the moving layer reads as another copy of the screen already being shown, then Today appears only when the host detaches. The visible transition should instead be the live Today view sliding upward over a stationary Listening view, with no final content cut.

## Motion contract

- A committed upward swipe keeps Listening stationary at offset `0`.
- The existing live Today layer moves above Listening in stacking order and starts one viewport height below its resting position.
- Today animates from offset `height` to `0` with a non-rebounding ease-in-out curve.
- The Listening host remains mounted until Today completely covers it, then dismisses and detaches behind Today.
- Reduce Motion skips the slide and returns to Today immediately.
- Cancelled or under-threshold swipes keep the existing rubber-band behavior and do not alter layer order.

## Architecture

`TodayView` owns the visible return choreography because it owns both the live Today layer and the Listening presentation intent. It records the available viewport height and a small return phase that determines Today's offset and stacking order.

`ListeningView` continues to resolve the gesture and calls `onAdvance` only for a committed dismissal. The UIKit host continues to own Listening readiness and teardown. During a return, `TodayView` first animates its own layer into place; only after that animation completes does it set the host presentation intent to false. Any host dismissal animation therefore occurs fully behind the opaque Today layer and cannot affect the visible transition.

No snapshot or duplicate Today hierarchy is created. The screen that moves is the same live NavigationStack the user interacts with after the transition.

## State flow

1. Listening is presented; Today remains mounted underneath at its normal position.
2. A committed swipe invokes `finishListening()`.
3. Today is placed at offset `viewportHeight`, raised above Listening, and kept non-interactive for the transition.
4. On the next render cycle, Today animates to offset `0`.
5. Animation completion sets `showingListening` to false and restores the idle return phase.
6. The UIKit host detaches Listening and stops playback through its existing dismissal callback.

Repeated finish requests while a return is active are ignored. Starting a new Listening presentation resets the return phase so Today remains underneath the host.

## Testing

- Add a focused unit test for the return-layout policy: at return start, Today is at `height` and Listening is at `0`; at completion, both offsets are `0` and Today is the front layer.
- Preserve existing host state-machine, gesture threshold, animation-policy, and Reduce Motion tests.
- Run the focused Today/Listening test suite, then the project test suite.
- Verify in the simulator or on device that Today, not Listening, is the moving layer and that no cut occurs at teardown.

## Scope

This change affects only Today's Listening dismissal. Presentation into Listening, Vault and Favorites presentations, playback behavior, collection thresholds, and gesture commit thresholds remain unchanged.
