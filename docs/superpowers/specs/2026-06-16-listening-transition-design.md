# Gesture-tracking Today ↔ Listening transition

**Date:** 2026-06-16
**Branch:** `listening-transition`

## Problem

Three symptoms reported when moving between the Today view and the immersive
Listening (now-playing) view:

1. **Open (Today → Listening):** a "little refresh-feeling stall" before the
   player appears, and "no animation when the screen swipes."
2. **Return (Listening → Today):** the swipe-up-to-return "only works when you
   swipe the button" — most of the screen is a dead zone.
3. **Return:** there's no screen transition animating back to Today.

## Root cause

The transition is built from two mismatched *discrete* mechanisms:

- **Open** is a `ScrollView` overscroll. `EntryDetailImmersive.swift` watches
  scroll offset via `onScrollGeometryChange`; pulling past the top
  (`offset < -80`) fires `onRequestListen()`, which sets `showingListening = true`
  in `TodayView`, presenting `ListeningView` as a `.fullScreenCover`.
  - The overscroll produces iOS's rubber-band bounce — the same motion as
    pull-to-refresh, hence the "refresh feeling."
  - `fullScreenCover` slides up *from the bottom*, the opposite direction of the
    user's downward pull, so the animation visibly fights the gesture.
- **Return** is `swipeUpToReturnGesture` in `ListeningView` — a
  `DragGesture(minimumDistance: 30)` on `.onEnded` attached via
  `.simultaneousGesture` to the root `ZStack`. The `playerStage` is a `VStack`
  of `Spacer`s over the `bloom` background; the only reliably hit-testable large
  targets are the glass control buttons, so swipes starting on empty regions are
  flaky. There is no `.contentShape` guaranteeing full-frame coverage.

## Decisions

- **Scope:** targeted fixes, not a full interactive (finger-following) rewrite.
- **Motion (revised 2026-06-16):** a directional slide (`.move(edge: .top)`) was
  tried first but did not feel fluid — sliding the full-screen blurred `bloom`
  (`blur(radius: 90)` + glass effects) repositions an expensive layer every
  frame and drops frames. Replaced with a **crisp cross-dissolve**: the swipe
  fires a haptic tap, then the player fades in/out over ~0.25s. Nothing
  repositions, so there is no jank. `reduceMotion` → instant cut.

## Design

### 1. Replace `fullScreenCover` with a custom top-edge transition — `TodayView.swift`

Wrap the existing `NavigationStack` in a `ZStack` and present `ListeningView` as
a conditional sibling above it instead of a modal cover. The player lives in its
**own** inner `ZStack` so the animation is scoped to it alone — otherwise the
implicit `.animation(value:)` sweeps the Today toolbar (in the sibling
`NavigationStack`) into the transition as the player covers/uncovers the nav bar.

```swift
ZStack {
    NavigationStack { … }   // unchanged: toolbar, .sheet(settings), .task, NewDropPrompt overlay

    ZStack {                // dedicated, animation-scoped container for the player
        if showingListening, let entry = loadedEntry {
            ListeningView(entry: entry, …)   // same params as today
                .transition(.opacity)        // crisp cross-dissolve
        }
    }
    .zIndex(1)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showingListening)
}
```

- **Insert / remove** → the player cross-dissolves in/out over ~0.25s. No layer
  repositions, so the heavy blurred `bloom` never causes the jank a slide did.
- The inner `ZStack` guarantees the player covers the nav bar; `ListeningView`'s
  `bloom` already `.ignoresSafeArea()`.
- Add `@Environment(\.accessibilityReduceMotion)` to `TodayView`; `reduceMotion`
  → `nil` animation (instant cut).
- The single `.animation(_:value:)` on the inner container drives **both**
  directions, so neither the open trigger nor `onAdvance` needs its own
  `withAnimation`.
- **Haptic:** the open already fires `Haptics.tap()` at the overscroll trigger
  (`EntryDetailImmersive.swift`). The return swipe (`swipeUpToReturnGesture` in
  `ListeningView`) fires `Haptics.tap()` too, so both directions feel like a
  decisive, confirmed page swap.
- Lifecycle is equivalent to the cover: the view is inserted/removed from the
  hierarchy, so `.task` / `.onAppear` fire and cancel as before — playback
  start/stop is unchanged.
- The `.fullScreenCover(isPresented: $showingListening)` modifier and its body
  are removed; the `ListeningView` call and all its parameters move into the
  `ZStack` branch verbatim.

The overscroll trigger in `EntryDetailImmersive.swift` is left as-is. The
descending player now covers the scroll view's bounce-back, hiding the "refresh
stall" — so no change to the snap-scroll / journal-zone behavior is needed.

### 2. Make the whole ListeningView swipeable — `ListeningView.swift`

`swipeUpToReturnGesture` already sits on the root `ZStack` via
`.simultaneousGesture`. Add `.contentShape(Rectangle())` to that `ZStack` so the
entire frame is hit-testable, eliminating the transparent `Spacer` dead zones.
`.simultaneousGesture` keeps the transport buttons and scrub bar working. The
gesture itself is unchanged (vertical-only, `translation.height < -80`,
`abs(width) < 60`).

A discoverability cue mirrors Today's "pull down to listen": a small upward
chevron + "Swipe up to close" at the top of the player stage, with a slow
vertical bob (disabled under `reduceMotion`). Context-neutral wording because the
view is shared by Today (returns to Today), Favorites, and Vault (dismiss). It is
`.accessibilityHidden` — the labeled advance button is the accessible exit.

### 3. Animated return

Falls out of #1 with no extra code: `onAdvance()` sets `showingListening = false`,
and the inner container's `.animation(value:)` runs the `.opacity` cross-dissolve
removal. The audio-stop in `onAdvance` is unchanged. Clip-finish auto-advance and
the "Read today's story" button get the same cross-dissolve for free.

## Scope

- **Files changed:** `TodayView.swift`, `ListeningView.swift`. Read
  `EntryDetailImmersive.swift` to confirm no change is required there.
- No new dependencies.
- `reduceMotion` falls back to an instant cut (`nil` animation).

## Out of scope

- Live finger-following (player tracking the finger frame-by-frame). That is the
  interactive rewrite that was explicitly declined. The return stays a
  discrete-but-reliable swipe that triggers an animated exit. Finger-tracking can
  be added later as a follow-up if the discrete feel proves insufficient.
- The horizontal `returnSwipeGesture` in `TodayView` (drives
  `onReturnToPreviousScreen` when Today is presented from elsewhere) is unrelated
  and untouched.

## Verification (manual)

UI animation/gesture work — verified by hand on the simulator/device:

1. Pull down on Today → haptic tap, then the player **cross-dissolves** in
   (no refresh-style stall, no sliding/jank).
2. Swipe up *anywhere* on the player (not just over a button) → haptic tap, then
   cross-dissolves back to Today.
3. The Today toolbar buttons (gear, live badge, streak) stay put during the
   transition — they are not swept into the animation.
4. Transport buttons (play/pause, restart, favorite) and the scrub bar still
   respond — the swipe gesture doesn't block them.
5. Enable Reduce Motion → both directions are an instant cut (no fade).
6. Let a clip finish → auto-advance back to Today cross-dissolves the same way.
