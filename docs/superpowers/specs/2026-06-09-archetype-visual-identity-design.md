# Archetype Visual Identity + Copy Redesign

**Date:** 2026-06-09
**Scope:** InsightsView archetype hero card — visual theming per archetype + rewritten "why you're you" copy + warmer stats copy in detail sheets.

---

## Goals

1. Each archetype's hero card has a distinct visual language that reflects its personality, not just a generic color gradient.
2. The "why it's you" text in the hero feels human and witty — archetype-voiced, no bare statistics.
3. Stats copy in detail sheets is warm and readable, not clinical.

---

## Visual Identity (Hero Card)

Approach: each archetype gets unique decorative layers on top of its gradient — a motif that reflects the mood. Same card layout, same padding, same text positions. Only the background changes.

Each description below maps to overlay layers in `ZStack` order (back to front): gradient base → decorative layer(s) → text content.

### Party Animal
- **Gradient:** `#ff9524 → #ff4500 → #c90c00`
- **Spinning burst:** conic gradient radial shape, top-right corner, slow 8s rotation animation
- **Noise grain:** SVG fractal noise blended with `overlay` mix-blend-mode, low opacity

### Flower Child
- **Gradient:** existing yellow/gold `#ffd700 → #ffab00`
- **Radial bloom:** soft white radial glow emanating from top-center
- **Bokeh dots:** 6–8 small blurred circles scattered across the card at low opacity

### Hopeless Romantic
- **Gradient:** light-to-dark — `#ffd6e8 → #ff5fa7 → #b0186e → #5e0038` (top to bottom)
- **Heart tile pattern:** subtle SVG heart repeated as background pattern, ~6% opacity
- **Top light bleed:** radial white gradient from top-left, creates a soft glow
- **Text color:** the top gradient is light so text in the upper portion should stay dark (`rgba(60,0,30,0.85)`); text in the lower portion (title, tagline, why) stays white as the bg darkens

### The Hippie
- **Gradient:** existing teal `#21b2ab → #008080`
- **Ripple rings:** 2–3 concentric circle outlines (stroke only), centered bottom-right, low opacity — like sound waves or water rings

### The Stargazer
- **Gradient:** deep cosmic radial — `radial-gradient(ellipse at 50% 0%, #6d4fc9, #2a1060, #050110)`
- **Star field:** 8–12 tiny white dots (2px) scattered across the upper portion
- **Aurora wash:** soft radial glow in purple/teal at ~20% opacity

### Born in the Wrong Generation
- **Gradient:** existing warm amber `#d48a1a → #8c5f3d`
- **Film grain:** SVG fractal noise texture, sepia-tinted, ~8% opacity — evokes analog warmth
- **Warm vignette:** subtle radial darkening at edges

### The Melancholic
- **Gradient:** `#6e90c8 → #2d4e90 → #111b4e → #050818`
- **Animated rain streaks:** thin diagonal lines moving top-to-bottom in a loop, blue-tinted, ~15% opacity
- **Moon glow:** soft radial white glow at top-right corner

### Loud & Proud
- **Gradient:** existing deep red `#cc1e1e → #660606`
- **Edge burn:** radial gradient darkening at all four edges — like a vignette pushed to the extreme
- **Diagonal energy lines:** 2–3 angled bright stripes, thin, ~10% opacity, like light catching metal

### The Outsider
- **Gradient:** `#7a4fbf → #1a0a30` (deep purple to near-black)
- **Half-circle motif:** large semicircle shape (echoes the `circle.lefthalf.filled` SF Symbol), right-aligned behind content, ~8% fill
- **Fine noise:** high-frequency fractal noise at very low opacity for texture

### The Shapeshifter
- **Gradient:** existing blue `#2155f5 → #123079`
- **Color shift overlay:** subtle animated hue-rotation on a soft radial gradient — implies fluidity without being distracting. Keep subtle; this archetype is about not having one identity, so the visual is more restrained than the others.

---

## "Why You're You" Copy

Each archetype has its own voice. Dynamic values shown in `{braces}` come from the user's data.

Archetypes marked **modifier-specific** show that copy when the named winning modifier wins; they fall back to their **mood fallback** otherwise.

| Archetype | Modifier | Copy |
|---|---|---|
| Party Animal | Era (primary) | "Turns out {era} music is basically a standing invitation and you never say no. Almost every track makes the cut." |
| Party Animal | Mood fallback | "Euphoric songs show up and you say yes. Consistently, enthusiastically, every time." |
| Flower Child | Mood only | "Joyful songs make up more of your keeps than almost any other mood. Guilty pleasure? Never met her." |
| Hopeless Romantic | Genre (primary) | "{genre} gets you every time. Your keep rate there is almost embarrassingly high." |
| Hopeless Romantic | Mood fallback | "A tender song comes on and you say yes. More often than not. More often than almost anything." |
| The Hippie | Mood only | "You keep serene songs more than almost any other mood. Everything else is just noise." |
| The Stargazer | Theme (primary) | "Songs about {theme} take you somewhere. You follow. You keep nearly every one." |
| The Stargazer | Mood fallback | "Dreamy songs take you somewhere. You keep nearly all of them. It's less a habit than a timezone." |
| Born in the Wrong Generation | Era (primary) | "{era} was made for you and you both know it. Your keep rate there is almost unfairly high for someone who technically wasn't there." |
| Born in the Wrong Generation | Mood fallback | "Nostalgic songs make up more of your keeps than almost any other mood. Homesick for somewhere you've never been." |
| The Melancholic | Era (primary) | "There's a weight to {era} music that you understand on a level most people don't even look for. You keep nearly all of it." |
| The Melancholic | Mood fallback | "Melancholy songs make up more of your keeps than almost any other mood. Not because you're not paying attention. Because you are." |
| Loud & Proud | Mood only | "You keep defiant songs more than almost any other mood. Your eardrums will heal." |
| The Outsider | Mood only | "You keep dark songs more than almost any other mood. You smile, sometimes." |
| The Shapeshifter | No modifier | "You don't have one defining taste. You have all of them. Your keep rate spreads pretty evenly across every mood, and that says a lot about you. A lot of good things." |

**Modifier matching logic:**
- Party Animal, Born in the Wrong Generation, The Melancholic → use era copy when `wm.dimensionID == "decade"`
- Hopeless Romantic → use genre copy when `wm.dimensionID == "genre"`
- The Stargazer → use theme copy when `wm.dimensionID == "theme"`
- All others, or when no `winningModifier` → use mood fallback

No em-dashes anywhere in copy. No bare percentages or "Xpts above average" phrasing.

---

## Stats Copy (Detail Sheets)

### Featured line
**Before:** `"Keeps 7 of 10 — 70% yes."`
**After:** `"{n} of {total} kept. You're basically a fan."`

Scale the second sentence based on keep rate:
- ≥ 60% → "You're basically a fan."
- 40–59% → "About half make the cut."
- < 40% → "Not really your thing."

### Energy detail line
**Before:** `"Liked songs average 3.8 out of 5."`
**After:** `"Your saved songs lean {lean}, averaging a {mean} out of 5 on energy."`

### Locked tile text
**Before:** `"Keep rating"`
**After:** `"Rate more to unlock"`

---

## Files to Change

| File | What changes |
|---|---|
| `Views/Components/TasteMirrorBoard.swift` | `heroWhy()` rewrite; `makeDetail()` featuredLine copy; `makeEnergyDetail()` featuredLine copy; locked tile text |
| `Models/TasteProfile.swift` | Add per-archetype visual decoration metadata (colors only change for Romantic and Stargazer if needed) |
| New: `Views/Components/ArchetypeHeroBackground.swift` | Extracts the hero background rendering per archetype — keeps `TasteMirrorBoard` readable |

The decorative layers are pure SwiftUI overlays. No images, no assets. All done with `ZStack`, `Canvas`, SF Symbols, and SwiftUI shape/gradient APIs.

---

## Friend Mirrors

Friend mirrors (`FriendInsightsView` / `TasteMirrorBoard` with `isCurrentUser: false`) get the same per-archetype visual backgrounds and the same rewritten copy. Existing read-only restrictions are unchanged: no tappable tiles, no detail sheets, no rating affordances. Only the hero card background and "why" text are affected, which are already rendered by `TasteMirrorBoard` and will pick up the changes automatically.

The `isCurrentUser` flag controls interactivity only — it does not affect which background or copy variant is shown.

---

## Out of Scope

- The standout tiles and secondary rows are not being restyled in this pass (they already pick up the accent color).
- The `InsightsView` color wash is not changing.
