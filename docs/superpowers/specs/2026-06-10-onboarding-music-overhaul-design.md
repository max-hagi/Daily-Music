# Onboarding Music Overhaul — Design

**Date:** 2026-06-10
**Status:** Approved

## Problem

The taste seed (`TasteSeedView`) is the emotional core of onboarding, but it plays
its hand quietly: previews are tap-to-play, rating is two static buttons, and the
flow ends by dropping the user onto the tab bar — where the first-day ceremony
rises only after a delay. The chip for this work asked for "auto-playing previews
in the taste seed, swipe-to-rate feel, and flow straight into today's first
ceremony as the finale."

## Decisions (validated with mockups)

1. **Interaction model: card stack.** Tinder-style deck over the hybrid
   (swipe + buttons on current layout) and full-bleed immersive options.
2. **Preview end: loop.** If the 30-second preview finishes before the user
   swipes, it restarts. No auto-advance, no dead air.
3. **Finale: straight into the ceremony.** The reveal's button launches today's
   listening ceremony directly; the user doesn't idle on the tab bar first.

## Design

### 1. Card stack component

New file: `Daily Music/Views/Onboarding/TasteSeedCardStack.swift`.

- Renders the top 2–3 remaining StarterPack songs as a deck: front card shows
  full album art, title, artist; the next cards peek behind with slight rotation
  and scale.
- The front card tracks the drag gesture with translation + rotation. Past the
  commit threshold a judgment badge fades in over the art ("INTO IT" right /
  "NAH" left). Release past the threshold flings the card off-screen and fires
  the callback; under it, the card springs back.
- The stack is a dumb view: input is the remaining songs, output is
  `onJudge(Int)` (+1 / −1). `TasteSeedView` keeps owning the state machine
  (intro → rating → reveal), `picks`, `StartingRead`, and `SeedRatings.save` —
  none of that logic moves.
- **Accessibility:** compact 👍/👎 fallback buttons remain below the stack
  (smaller than today's 92pt circles); the front card exposes like/dislike
  accessibility actions. With Reduce Motion, the fling is replaced by a
  crossfade to the next card.

### 2. Auto-play with loop

- Intro copy is updated to set the expectation that audio will play out loud
  ("headphones on 🎧"). Tapping **Begin** is the consenting user gesture; the
  first preview starts there.
- When a card becomes front (initial Begin or after a swipe), its preview starts
  automatically via the shared `MusicPlayer`.
- On the player's `finished` event during the rating phase, the same preview is
  restarted — looping until the user swipes.
- Tap-the-art-to-pause stays for users who want quiet. Skip and exit stop
  playback (existing `stopAndExit` path).

### 3. Finale — straight into the ceremony

- The reveal's button becomes **"Hear today's song"**.
- Completing the taste seed sets a `launchIntoCeremony` flag on
  `AppEnvironment`. On first appearance, `TodayView` checks the flag, opens the
  `ListeningView` ceremony immediately (skipping the existing settle-delay), and
  clears the flag.
- `ListeningCeremony.shouldAutoOpen` and the delayed auto-rise stay unchanged
  for every subsequent day; the flag only changes day one's timing.
- If today's entry hasn't loaded by the time `TodayView` appears, the flag stays
  set until the entry arrives, then the ceremony opens (no race; worst case it
  behaves like the existing auto-open).

### 4. Scope guards

- No backend changes. No StarterPack changes.
- The daily rating UI outside onboarding is untouched. Unifying the swipe
  gesture with the daily ritual is a possible follow-up.

### 5. Testing

- Stack judgment flow: advancing through the deck, last card → reveal, skip
  mid-deck — unit tests.
- Loop-on-finished and start-on-front-card behavior — unit tests against
  `PreviewMusicEngine`.
- `launchIntoCeremony` handoff (set → ceremony opens immediately → flag
  cleared; unset → existing delayed behavior) — tests in the TodayViewModel /
  playback suite.
- Gesture feel, badge thresholds, and the reveal-to-ceremony transition are
  verified by hand in the simulator.

## Future work (explicitly out of scope)

- **Deeper Apple Music integration for subscribers** via MusicKit — e.g. full
  playback instead of 30-second previews, add-to-library, personalized starter
  pack from listening history. Parked for a later cycle.
- Swipe-to-rate as the daily ritual gesture (gesture unification).
- Rate-to-reveal community gating (needs aggregate-rating backend + social
  graph; strongest future paywall lever).
