# Today pull artwork bleed

**Date:** 2026-06-18
**Status:** Approved for implementation

## Problem

Pulling down on Today exposes the arming ring outside the bounds of the immersive album-art backdrop. The newly exposed area falls back to the window background, producing a hard white or black cutoff depending on the system appearance.

## Visual contract

- The existing blurred album-art treatment extends through the exposed pull region and top safe area.
- The extension is visually continuous with Today's current immersive backdrop; it must not introduce a second gradient, hard edge, or differently scaled artwork layer.
- The arming ring keeps its current neutral tint while pulling and its current green tint when armed.
- While the ring is visible, a restrained adaptive material backing protects its contrast against bright, dark, or detailed artwork.
- The backing disappears with the ring and does not remain on Today at rest.
- Light mode, dark mode, and Reduce Motion retain the same visual hierarchy.

## Architecture

Make the immersive artwork backdrop reusable by both `EntryDetailView` and the Today-level pull surface. The shared renderer accepts the resolved artwork image and accent color and owns the existing blur, saturation, opacity, and immersive gradient recipe. Today uses its already preloaded `ArtworkPalette`, including the process-cache fallback, so the pull surface is themed from its first visible frame.

Place the Today-level backdrop behind the live `NavigationStack` and pull indicator. It should only become visible where the inner scrolling content currently exposes the default window background. The normal Today composition remains visually unchanged because the existing immersive content continues to cover it.

Add an explicit contrast-backing style input to `PullArmingRing`, disabled by default and enabled only by Today. When enabled, the ring and label share one compact adaptive material surface. Preserve the existing progress, armed state, chevron motion, colors, accessibility behavior, and opacity threshold. Listening's exit ring keeps its current unbacked appearance.

## Behavior and scope

This is a presentation-only change. Pull distance, gesture recognition, commit velocity, haptics, Today-to-Listening presentation, Listening-to-Today return choreography, playback, and collection behavior remain unchanged. Vault and Favorites retain their current detail backdrops and do not gain the Today pull indicator treatment.

## Testing

- Add focused coverage for any extracted pure backdrop-style policy or pull-indicator style selection.
- Preserve the existing transition math, state-machine, and animation-policy tests.
- Run the focused Today/Listening tests and the full project test suite.
- Verify interactively with bright and dark album artwork in both system appearances: the exposed region remains artwork-backed, the ring stays legible, and no edge appears during pull, cancel, or commit.
