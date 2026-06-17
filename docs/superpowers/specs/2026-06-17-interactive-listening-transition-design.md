# Interactive Today ↔ Listening transition

**Date:** 2026-06-17
**Status:** Approved, ready for implementation plan
**Supersedes the feel of:** [2026-06-16-listening-transition-design.md](2026-06-16-listening-transition-design.md) (which introduced the cross-dissolve for perf; this keeps that perf win but makes the transition continuous and flips the dismiss direction)

## Problem

Moving between Today and the immersive Listening player feels clunky. Two root causes:

1. **No direct manipulation.** Both directions are *binary threshold triggers* with a fixed 0.25s cross-fade. Nothing tracks the finger; there's no live feedback. You drag blind, then on release a fixed-duration fade fires, unrelated to how fast or far you moved.
   - Enter: a *scroll* over-pull on the journal that fires `onRequestListen` once it crosses `-80pt` (`EntryDetailImmersive.swift`), flipping `showingListening = true` → `.transition(.opacity)` in `TodayView`.
   - Exit: a `DragGesture` that only acts `.onEnded` (`ListeningView.swift swipeUpToReturnGesture`).
2. **Dismiss direction is inverted from convention.** The player dismisses on **swipe up**. Every mainstream full-screen media player (Apple Music, Spotify, Instagram) dismisses on **swipe down**. Users instinctively swipe down to leave; nothing happens, so they have to relearn an upward gesture. Polishing a backwards gesture still leaves users fighting muscle memory.

## Goals

- The transition is **continuous, finger-tracked, and reversible** in both directions.
- The dismiss gesture matches platform convention: **swipe down to dismiss**.
- Keep the distinctive **pull-down-to-listen ceremony** for entering.
- **No regression to the perf win** from the 2026-06-16 redesign: the heavy blurred bloom must never animate its position.
- Respect Reduce Motion.

## Non-goals

- Replacing the player with a system `.fullScreenCover`/sheet (would inject system chrome/dimming and force a bottom-up slide, breaking the immersive ceremony and the pull-down metaphor).
- Changing the entry gesture surface (stays coupled to the journal over-pull; the existing "Listen to collect" button is unaffected).
- Reworking the listen-threshold / collection logic, scrubber, or bloom visuals.

## Design

### Two state values

The player can't be mounted during a tentative enter-pull: mounting `ListeningView` auto-starts audio (`startPlaybackIfNeeded()`). So we use two values, not one:

```
presentation: Double  // 0 = player absent, 1 = player fully presented. Drives the mounted player container.
pullProgress: Double  // 0…1 enter-only feedback on TODAY's content during the over-pull (player not yet mounted).
```

- The **player** mounts only when `presentation > 0` (i.e. at/after commit). `presentation` is the single driver of the player container and is fully reversible mid-gesture during the exit drag.
- `pullProgress` is purely the live "something is responding" feedback on Today while the user is still deciding, before any mount/audio.

### What `presentation` drives (the mounted player)

| Layer | Mapping | Why |
|---|---|---|
| Bloom (`blur(radius:90)`) | **opacity = presentation only** | Repositioning this layer dropped frames before. Opacity is cheap. Never translate it. |
| Foreground content (artwork, transport, text) | opacity = presentation; scale = `0.96 + 0.04·presentation`; vertical offset = `(1 − presentation) · dismissTravel` (downward) | Cheap to move; carries the "falls away downward" dismiss feel. |

**Reduce Motion:** opacity only — no scale, no offset (both enter feedback and exit drag).

### What `pullProgress` drives (Today, enter-only)

Today's song zone recedes slightly as the user over-pulls — `scale = 1 − 0.04·pullProgress`, `opacity = 1 − 0.25·pullProgress` — so the pull has continuous feedback before the player springs in. Resets to 0 if the user releases without committing.

### Enter — pull down (ceremony preserved, made live)

In the existing `onScrollGeometryChange` over-pull handler (`EntryDetailImmersive.swift`):

- Map live over-pull onto `pullProgress`: `0pt → 0`, `~160pt → 1` (clamped), reported up via a new `onListenPullProgress: (Double) -> Void` closure. Today's song zone recedes live (above).
- **Commit** the instant `pullProgress` crosses `~0.4` during the pull (latched by the existing `pullTriggered` guard): haptic + `onRequestListen?()`. This is the same latch mechanism as today, but at a feedback-backed ~64pt instead of a blind 80pt — the user *sees* Today recede as they approach commit.
- On commit, `TodayView` mounts the player and springs `presentation` 0 → 1 (a connected spring, not a flat 0.25s fade).
- If the user releases before commit, the scroll bounces back, `pullProgress` returns to 0, and Today settles — no mount, no audio.
- Keep the "pull down to listen / pull down to replay" cue copy.

Constraint acknowledged: the scroll view owns its own rubber-band, so this is "live feedback + threshold commit," not a 1:1 finger-tracked mount. That is the correct trade for the enter direction given the audio lifecycle; the fully finger-tracked interaction is the exit.

### Exit — swipe down to dismiss (new)

Replace `swipeUpToReturnGesture` (up, `.onEnded`-only) with a downward interactive drag bound to `presentation` (a `@Binding` passed in from `TodayView`):

- `.onChanged`: as the user drags down by `d` points, set `presentation = 1 − TransitionMath.dismissFraction(forDrag: d, height:)`; the player's foreground tracks the finger down + fades + scales; bloom fades. (Upward drag clamps at `presentation = 1`, i.e. rubber-bands closed.)
- `.onEnded`: feed the released `dismissFraction` and the gesture's vertical velocity into `TransitionResolver.resolve`. **commit** → spring `presentation` to 0, then call `onAdvance()`; **cancel** → spring `presentation` back to 1. A fast downward flick commits even on a short drag; a weak/short drag springs back up.
- Vertical-down only, with a horizontal-width guard, attached via `simultaneousGesture` so the horizontal scrubber keeps working. Guard by initial drag direction so a downward dismiss and a horizontal scrub never fight.
- Copy: "swipe up to close" → **"swipe down to close"** (`ListeningView.swift` swipeUpHint); chevron `chevron.up` → `chevron.down`; flip the hint bob direction (`+4` instead of `−4`).

### The one testable unit (pure, no view)

A small pure helper file so the easy-to-get-wrong math is unit-tested independently:

```swift
enum TransitionOutcome { case commit, cancel }

enum TransitionResolver {
    /// committedFraction: 0 = at the start of the gesture's intent, 1 = intent fully achieved.
    /// velocity: points/sec, positive = moving toward the intent.
    /// Decide whether a released gesture should complete (commit) or snap back (cancel).
    static func resolve(committedFraction: Double, velocity: Double) -> TransitionOutcome
}

enum TransitionMath {
    /// Clamped 0...1 mapping from journal over-pull distance (points, positive = pulled down).
    static func progress(forPull pull: Double) -> Double
    /// Clamped 0...1 dismissal fraction from a downward dismiss-drag (points, positive = down),
    /// scaled to a fraction of screen height so it feels consistent across devices.
    static func dismissFraction(forDrag drag: Double, height: CGFloat) -> Double
}
```

Exact constants (commit fraction ~0.4, the velocity cutoff ~800, the ~160pt pull span, the ~0.35·height dismiss span) are tunable; final values verified on device.

For the **enter** direction, `resolve` is not needed — the commit is the `pullProgress ≥ 0.4` latch in the scroll handler. `resolve` is used by the **exit** drag, which has a real `DragGesture` velocity.

## Components & footprint

- **New:** `Daily Music/Views/Components/ListeningTransition.swift` — the pure `TransitionResolver` + `TransitionMath` helpers. Auto-compiles (app target is a file-system-synchronized group).
- **Tests:** appended to the existing `Daily MusicTests/TodayListeningTests.swift` (the test target is **not** auto-synced, so reusing a registered file avoids editing `project.pbxproj`).
- **`TodayView`** — owns `presentation` and `pullProgress` as `@State`; mounts the player when `presentation > 0`; derives the player container's opacity/scale/offset from `presentation`; passes `$presentation` to `ListeningView` for the exit drag; springs `presentation` 0 → 1 on `onRequestListen`.
- **`EntryDetailView` / `EntryDetailImmersive`** — new `onListenPullProgress: (Double) -> Void` prop; the scroll handler reports live `pullProgress` and applies the recede to the song zone; commit latch unchanged in spirit (now at the `0.4` fraction).
- **`ListeningView`** — `@Binding var presentation: Double`; swipe-down interactive dismiss gesture replacing `swipeUpToReturnGesture`; updated hint copy/chevron/bob.

## Data flow

```
Enter:  journal over-pull → TransitionMath.progress(forPull:) → pullProgress → Today song-zone recede (live)
        pullProgress ≥ 0.4 → latch → Haptics.tap() + onRequestListen()
        onRequestListen → mount player + spring presentation 0 → 1

Exit:   downward drag on player → TransitionMath.dismissFraction(forDrag:height:) → presentation = 1 − fraction (live)
        release → TransitionResolver.resolve(committedFraction: fraction, velocity:)
                → commit: spring presentation → 0, onAdvance()  |  cancel: spring presentation → 1
```

## Error / edge handling

- Mid-gesture reversal during exit works for free because `presentation` is the single driver of the mounted player.
- Horizontal scrub vs vertical dismiss disambiguated by initial drag direction; `simultaneousGesture` preserves transport controls.
- Reduce Motion: opacity-only path, same commit/cancel logic.
- Dismiss still calls the existing `onAdvance()` (stops audio) on commit — no change to listen-tracking or collection.
- If the user releases the enter-pull before the `0.4` latch, no player is mounted and no audio starts.

## Testing

- **Unit (`TransitionResolver`):** commits at/above the commit fraction with zero velocity; commits on high positive velocity below the fraction; cancels on high negative velocity above the fraction; cancels on low fraction + low velocity.
- **Unit (`TransitionMath`):** `progress(forPull:)` clamps at 0 and 1 and hits 1 at the span; `dismissFraction(forDrag:height:)` clamps, returns 0 for non-positive height, and scales with height.
- **On device:** enter pull recede + commit spring, swipe-down dismiss feel, mid-gesture reversal, scrubber unaffected, Reduce Motion.
