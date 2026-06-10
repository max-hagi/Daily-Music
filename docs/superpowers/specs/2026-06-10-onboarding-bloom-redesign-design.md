# Onboarding Bloom Redesign

**Date:** 2026-06-10
**Scope:** Visual redesign of the 3-step onboarding wizard and the taste-seed flow, plus two flow changes: the listen step becomes non-skippable and a "You're all set" send-off launches today's ceremony.

## Problem

The wizard (`OnboardingView` + step views) sits on a flat `systemGroupedBackground` with centered text — dark and boring next to the recently redesigned sign-in (cover wall) and rating deck. The taste-seed intro/reveal are similarly plain.

## Design

### 1. `OnboardingBloomBackground` (new, `Views/Onboarding/`)

A reusable animated backdrop: 3–4 large blurred circles (`Circle().fill().blur(radius: ~80)`) drifting on slow, offset animation loops over an adaptive base — near-white in light mode, near-black in dark mode (same colors, lower opacity / glow). Inputs:

- `palette: [Color]` — the bloom colors. Changing the palette animates the crossfade with the wizard's existing spring (`response: 0.45, dampingFraction: 0.85`).
- Respects `accessibilityReduceMotion`: static (no drift) when set, palette changes still crossfade without movement.

Replaces `Color(.systemGroupedBackground)` in `OnboardingView` and the flat tint layers in `TasteSeedView`.

### 2. Per-step accent & chrome (`OnboardingView`)

Each wizard step has an accent and bloom palette:

| Step | Accent | Bloom palette (light-mode reference) |
|---|---|---|
| 1 Say hello | violet | violet / cyan / pink |
| 2 Reminder | cyan | cyan / violet / teal |
| 3 Listen | orange | amber / pink / yellow |

The accent drives the active progress dot, the Continue/Finish button (gradient fill, e.g. violet→indigo), and selection marks. Back button and step transitions unchanged.

### 3. Step content polish

A small shared `glassCard()` view modifier: `.ultraThinMaterial` background, white hairline stroke, soft tinted shadow, continuous-corner radius.

- **Hello step:** avatar gets a soft accent-colored shadow; the name field sits on a glass card.
- **Reminder step:** the wheel picker moves onto a glass card; permission-denied note unchanged.
- **Listen step:** service rows keep their layout but get the glass treatment; the selected row gets an accent-colored border in addition to the checkmark.

### 4. Taste-seed flow restyle (`TasteSeedView`)

- **Intro:** bloom backdrop (violet/pink palette), gradient Begin button, restyled icon treatment. Copy unchanged.
- **Rating:** the bloom runs with colors extracted from the current card's artwork (reusing the artwork-color extraction the listening ceremony uses), crossfading per swipe. This replaces the current full-bleed blurred-cover backdrop. Deck dots, song meta, swipe hints, and Skip restyled to the glass/accent language. Deck mechanics, audio playback/looping, judging, and SeedRatings persistence untouched.
- **Reveal:** bloom tinted by the read's mood color, glass card for the read, gradient CTA.

### 5. Listen step non-skippable

Skip is removed from the last step; it now appears only on the reminder step (step 2). `preferredStreamingService` already defaults to `.appleMusic`, so Finish always saves a valid choice. No model or persistence changes.

### 6. "You're all set" send-off

After `finish()` saves successfully, the wizard shows a final bloom screen instead of immediately flipping to the main app: "You're all set, *firstName* — your first song is waiting 🎧" with one button, **Hear today's song**. Tapping it sets `env.launchIntoCeremony = true` (the same hook the taste-seed reveal uses) and then sets `hasCompletedOnboarding = true`, so RootView lands directly in today's listening ceremony. On save failure the existing inline error keeps the user on the wizard; the send-off only shows on success. (The `hasCompletedOnboarding` flip moves from `finish()` to the send-off button.)

## Out of scope

- Sign-in screen, email sheet, and the listening ceremony itself.
- Any change to onboarding logic: step order, name requirement, reminder permission handling, settings flush ordering, profile save, `OnboardingConfig.currentVersion`.

## Error handling

Unchanged from today: settings `flush()` swallows its own errors; profile save failure shows the inline error and re-enables the buttons. The send-off is purely additive after the success path.

## Testing & verification

Pure view styling plus two small flow changes; existing unit tests are unaffected. Verify by running the app:

1. Fresh onboarding in light mode and dark mode — blooms drift, palettes crossfade per step.
2. Reduce Motion on — backdrops static, no drifting.
3. Listen step shows no Skip; finishing without touching it saves Apple Music.
4. Send-off appears after Finish, and "Hear today's song" lands in the ceremony.
5. Taste-seed: rating backdrop tints from artwork per card; skip/complete paths still work.
