# Interactive Today ↔ Listening transition

**Date:** 2026-06-17 (rev 2 — opaque takeover + arming ring, validated via interactive prototype)
**Status:** Approved, ready for implementation plan
**History:** rev 1 of this doc specified a finger-tracked *cross-dissolve* with a swipe-down dismiss. That was built, then rejected on feel: the opacity cross-fade shows Today through the player (double-exposure = unpolished), and swipe-down fought the player's upward exit motion. This rev replaces the visual model. See [[feedback_transition-feel]].

## Problem

The Today→Listening transition feels clunky/unpolished. Two root causes confirmed with the user:

1. **Cross-fade ghosting.** Driving the player in/out with `.opacity` means both full screens are visible at once mid-transition — it reads as cheap. The destination should **take over opaquely**.
2. **No arming feedback + wrong dismiss direction.** A blind threshold with no indicator feels mysterious (the reason plain pull-to-refresh was disliked). And dismissing *down* contradicts the fact that the player arrived by being pulled *down* over Today.

## Goals

- **Opaque vertical takeover** — the player is a solid layer that slides; Today never shows through it.
- **Finger-tracked pull with an arming Ring indicator** — a circular progress ring fills toward a threshold, label flips "Keep pulling…" → "Release", haptic detent when it arms. The static text cue fades out as the ring fades in (they swap, never overlap).
- **Gesture/motion symmetry** — **pull down to open, swipe up to close.** The player slides down from above to cover Today; the inverse is pushing it back up.
- **Preserve the bloom perf budget** — the heavy `blur(radius:90)` bloom is never finger-tracked. During the pull only lightweight foreground moves; the bloom moves only in the brief one-shot commit slide (rasterized if needed).
- Respect Reduce Motion.

## Non-goals

- System `.fullScreenCover`/sheet for Today's player (forces bottom-up slide + system chrome, breaks the ceremony).
- Changing Vault/Favorites, which keep their own `.fullScreenCover` presentation (they are out of scope for the new pull model; their swipe-to-dismiss is unchanged from today's behavior unless trivially free).
- Reworking listen-threshold/collection, scrubber, or bloom visuals.

## The model (what the approved prototype does)

```
TODAY  ──pull down (ring fills at top)──▶  release when full  ──▶  player slides DOWN to cover (opaque)
PLAYER ──swipe up  (ring fills at bottom)─▶  release when full  ──▶  player slides UP off-screen, Today revealed
```

Below threshold on release → everything springs back, nothing happens. The player conceptually lives *above* Today: hidden = offset `-height`, presented = offset `0`.

## State

In `TodayView`:
- `presentation: Double` — player vertical position, 0 = off-screen above, 1 = fully covering. The player container is `.offset(y: -(1 - presentation) * viewHeight)`, **opaque, no opacity animation**. Spring-animated only on commit/cancel of a transition (never finger-tracked, so the bloom never moves under the finger).
- `enterArm: Double` (0…1) — Today-pull arming progress; drives the top Ring overlay and Today's recede.
- `showingListening: Bool` — mount gate (player mounts when true; set true at enter-commit, false after the dismiss slide completes — mounting starts audio, so we only mount at commit).
- `viewHeight: CGFloat` — captured for the slide distance.

In `ListeningView`:
- `dismissArm: Double` (0…1) `@State` — up-pull arming; drives the bottom Ring overlay and a small foreground rubber-band (bloom stays put).
- `presentation: Binding<Double>` — so the dismiss commit can spring the player up.

## Components

| File | Responsibility |
|---|---|
| `Daily Music/Views/Components/ListeningTransition.swift` (new) | Pure helpers: `TransitionMath.armProgress(forPull:span:)` and `armProgress(forDrag:height:)` (clamped 0…1); `TransitionResolver.resolve(armProgress:velocity:) -> .commit/.cancel`. |
| `Daily Music/Views/Components/PullArmingRing.swift` (new) | Reusable indicator view: `PullArmingRing(progress:armed:label:)` — circular progress ring + center chevron that flips when armed + label below. Pure presentation, no gesture logic. |
| `TodayView` | Owns `presentation`/`enterArm`/`showingListening`/`viewHeight`; renders the top Ring overlay during the enter pull; mounts + slides the opaque player; springs presentation on commit/cancel. |
| `EntryDetailView` / `EntryDetailImmersive` | New `onListenArm: (Double) -> Void`; the scroll over-pull handler reports `enterArm` and commits when the ring fills (or a fast over-pull flick). |
| `ListeningView` | `presentation` binding + a swipe-**up** dismiss gesture driving `dismissArm`; bottom Ring overlay; foreground rubber-band; commit springs presentation → 0 then `onAdvance()`. |

## Pure helpers (the testable unit)

```swift
enum TransitionOutcome: Equatable { case commit, cancel }

enum TransitionResolver {
    /// Velocity (points/sec toward the intent) that commits even before the ring fills.
    static let commitVelocity = 800.0
    /// Commit once the ring is full, or on a fast flick. Cancel otherwise.
    static func resolve(armProgress: Double, velocity: Double) -> TransitionOutcome {
        if velocity >= commitVelocity { return .commit }
        return armProgress >= 1 ? .commit : .cancel
    }
}

enum TransitionMath {
    static let pullSpan: Double = 150          // over-pull distance that fills the ring (enter)
    static let dismissHeightFraction: Double = 0.28  // up-drag span as a fraction of height (exit)

    static func armProgress(forPull pull: Double) -> Double { clamp(pull / pullSpan) }
    static func armProgress(forDrag drag: Double, height: CGFloat) -> Double {
        guard height > 0 else { return 0 }
        return clamp(drag / (Double(height) * dismissHeightFraction))
    }
    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
}
```

## Enter — pull down

In the existing `onScrollGeometryChange` over-pull handler (`EntryDetailImmersive`):
- `enterArm = TransitionMath.armProgress(forPull: max(0, -offset))`, reported via `onListenArm`.
- TodayView renders `PullArmingRing(progress: enterArm, armed: enterArm >= 1, label:)` pinned near the top, fading/translating in with `enterArm`; the static "pull down to listen" cue fades out as `enterArm` rises. Today content recedes slightly (`scale 1 → 0.97`, the existing recede).
- Haptic detent (`Haptics.tap()`) the moment `enterArm` crosses 1 (latched).
- Commit when, during the pull, `enterArm >= 1` (latched by the existing `pullTriggered` guard) → `Haptics.tap()`, `onRequestListen?()`. TodayView then mounts the player and springs `presentation` 0 → 1 (slides down to cover). Label reads "Release to listen" while armed.
- Release before full → scroll bounces back, `enterArm` returns to 0, ring + recede fade out, no mount.

## Exit — swipe up

Replace the old gesture with an upward `DragGesture` on the player (`simultaneousGesture`, so the horizontal scrubber still works; gated to clearly-upward drags via an `isUpwardDrag` check):
- `.onChanged`: `dismissArm = TransitionMath.armProgress(forDrag: max(0, -translation.height), height:)`; bottom `PullArmingRing` fills; the player **foreground** (not the bloom) rubber-bands up a little; bottom cue ("swipe up to close") fades out as the ring fills; haptic detent at `dismissArm` crossing 1.
- `.onEnded`: `TransitionResolver.resolve(armProgress: dismissArm, velocity: -translation/​value.velocity.height)`. **commit** → `Haptics.tap()`, spring `presentation` 1 → 0 (player slides up off-screen) then `onAdvance()`; **cancel** → spring foreground back, `dismissArm` to 0.

## Opaque slide & perf

- The player container is opaque (its own bloom/black background). The transition is `.offset(y:)` driven by `presentation`, **never** `.opacity` — no ghosting.
- The bloom moves only during the brief commit/cancel slide (a one-shot ~0.4s spring), never under the finger. If profiling shows drops, wrap the player container in `.compositingGroup()` (or `.drawingGroup()` during the slide) so the blur rasterizes once. **Validate on device.**
- During the *pull* (pre-commit), the bloom does not move at all — enter moves Today + ring; exit moves only the foreground + ring.

## Reduce Motion

No slide, no rubber-band, no recede: enter-commit sets `presentation = 1` instantly; dismiss-commit calls `onAdvance()` immediately. The Ring still fills (it's informational, minimal motion) but without the bob/scale flourish.

## Error / edge handling

- `presentation` is the single driver of the mounted player position; mid-commit it's spring-animated, not finger-tracked, so it can't get "stuck" between values.
- Scrub vs dismiss disambiguated by initial drag direction; `simultaneousGesture` preserves transport controls.
- Mount only at enter-commit, so a tentative pull never starts audio.
- `finishListening()` (non-gesture dismissals: bottom "Read today's story" button, clip-finished auto-advance) springs `presentation` → 0 then tears down, so those animate too; a double call (finish/swipe race) is guarded.

## Testing

- **Unit (`TransitionResolver`):** commits when the ring is full at zero velocity; commits on a fast flick before full; cancels when short + slow.
- **Unit (`TransitionMath`):** `armProgress(forPull:)` clamps 0…1 and reaches 1 at `pullSpan`; `armProgress(forDrag:height:)` clamps, returns 0 for non-positive height, scales with height.
- **On device:** enter pull → ring fills → opaque slide-down; swipe-up → ring fills → opaque slide-up; release-before-full springs back; scrubber unaffected; Reduce Motion; bloom stays smooth during the commit slide.
