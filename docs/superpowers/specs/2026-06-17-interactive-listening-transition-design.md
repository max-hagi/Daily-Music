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

### Single source of truth

One progress value drives the entire transition:

```
progress: Double   // 0 = Today, 1 = player fully presented
```

Everything else is derived from `progress`, so enter and exit are the same interaction run forward/backward and are fully reversible mid-gesture.

### What progress drives

| Layer | Mapping | Why |
|---|---|---|
| Bloom (`blur(radius:90)`) | **opacity = progress only** | Repositioning this layer dropped frames before. Opacity is cheap. Never translate it. |
| Foreground content (artwork, transport, text) | opacity = progress; scale = `0.96 + 0.04·progress`; vertical offset (see below) | Cheap to move; carries the spatial feel. |

**Reduce Motion:** opacity only — no scale, no offset.

### Offset behaviour differs by gesture surface (intentional)

- **Enter (finger on the journal scroll, not the player):** small offset only (content settles in from a slight displacement, ~16–24pt). A large 1:1 player translation would be wrong because the finger isn't on the player.
- **Exit (finger on the player):** foreground content **tracks the finger downward ~1:1** over a meaningful distance and falls away, while the bloom only fades behind it. Reads like the player dropping away over a dissolving backdrop.

This asymmetry is correct: each direction matches where the finger actually is.

### Enter — pull down (ceremony preserved, made live)

In the existing `onScrollGeometryChange` over-pull handler (`EntryDetailImmersive.swift`):

- Map live over-pull onto progress: `0pt → progress 0`, `~-160pt → progress 1` (clamped).
- Drive the player presentation continuously from that progress as the user pulls.
- On release (scroll returns toward 0): **commit** (spring progress → 1, set `showingListening = true`) if `progress > ~0.4` OR pull velocity was high; otherwise spring → 0 and the player fades back out as the scroll settles.
- Keep the "pull down to listen / pull down to replay" cue copy.

Constraint acknowledged: the scroll view owns its own rubber-band, so live tracking is good but not perfectly 1:1. Acceptable for the enter direction.

### Exit — swipe down to dismiss (new)

Replace `swipeUpToReturnGesture` (up, `.onEnded`-only) with a downward interactive drag on the player:

- `.onChanged`: as the user drags down, decrease `progress` from 1 toward 0; foreground content tracks the finger down + fades + scales; bloom fades. Rubber-band past the ends.
- `.onEnded`: commit via **distance AND velocity** — a fast downward flick dismisses even on a short drag; a weak/short drag springs back up. Animate the remainder with an `interactiveSpring` whose initial velocity matches the throw.
- Vertical-down only, with a horizontal-width guard, attached via `simultaneousGesture` so the horizontal scrubber keeps working. Guard by initial drag direction so a downward dismiss and a horizontal scrub never fight.
- Copy: "swipe up to close" → **"swipe down to close"** (`ListeningView.swift` swipeUpHint); flip the hint bob direction accordingly.

### The one testable unit (pure, no view)

A small pure helper file so the easy-to-get-wrong math is unit-tested independently:

```swift
enum TransitionOutcome { case commit, cancel }

enum TransitionResolver {
    /// Decide whether a released gesture should complete or snap back.
    static func resolve(progress: Double, velocity: Double) -> TransitionOutcome
}

enum TransitionMath {
    /// Clamped 0...1 mapping from journal over-pull distance.
    static func progress(forPull pull: Double) -> Double
    /// Clamped 0...1 mapping from downward dismiss-drag distance.
    static func progress(forDismissDrag drag: Double, height: CGFloat) -> Double
}
```

Exact thresholds (commit ~0.4, the velocity cutoff, the 160pt pull span, dismiss travel) are tunable constants; final values verified on device.

## Components & footprint

- **New:** `ListeningTransition.swift` — the pure `TransitionResolver` + `TransitionMath` helpers. Plus a test file.
- **`TodayView`** — owns `progress` as `@State` alongside `showingListening`; derives the player container's opacity/scale/offset from it; threads a binding to `ListeningView` for the exit drag.
- **`EntryDetailImmersive`** — enter mapping in the existing scroll handler (live progress instead of threshold fire).
- **`ListeningView`** — swipe-down interactive dismiss gesture; updated hint copy + bob direction.

## Data flow

```
Enter:  journal over-pull → TransitionMath.progress(forPull:) → progress → player opacity/scale/offset (live)
        release → TransitionResolver.resolve → spring to 0 or 1 (sets showingListening)

Exit:   downward drag on player → TransitionMath.progress(forDismissDrag:) → progress (live)
        release → TransitionResolver.resolve → spring to 1 (stay) or 0 (dismiss → onAdvance/stop)
```

## Error / edge handling

- Mid-gesture reversal works for free because progress is the single source of truth.
- Horizontal scrub vs vertical dismiss disambiguated by initial drag direction; `simultaneousGesture` preserves transport controls.
- Reduce Motion: opacity-only path, same commit/cancel logic.
- Dismiss still calls the existing `onAdvance()` (stops audio) on commit — no change to listen-tracking or collection.

## Testing

- **Unit (`TransitionResolver`):** commits above the progress threshold; commits on high velocity below threshold; cancels on slow + short.
- **Unit (`TransitionMath`):** clamping at both ends; correct endpoints for pull and dismiss mappings.
- **On device:** enter pull feel, swipe-down dismiss feel, mid-gesture reversal, scrubber unaffected, Reduce Motion.
