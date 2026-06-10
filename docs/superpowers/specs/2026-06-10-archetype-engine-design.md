# Archetype Engine v2 — Affinity-Profile Scorer

**Date:** 2026-06-10
**Status:** Approved design, pending implementation plan

## Problem

The archetype is a pure lookup on the user's single top mood
(`TasteProfile.resolve`), and "top mood" usually falls back to `dominant` —
raw like-count. Because every user rates the same curator-chosen daily drop,
raw counts mirror the editorial mood mix, not the user's taste. The better
signal (`overIndex`, like-rate vs. the user's average) needs ≥3 ratings per
category plus a 10% margin and rarely fires on sparse data. Result: archetypes
feel inaccurate. Genre, energy, and theme are ignored entirely (flavor text
only), and one 👍 can decide an identity.

## Decisions (made with Maxime, 2026-06-10)

1. **Signals:** ratings (👍/👎) + favorites (hearts). No new instrumentation.
2. **Model:** per-archetype affinity vectors over mood / energy / theme /
   genre, scored against the user's smoothed, recency-weighted like-rates.
3. **Receipts:** evidence shown in both the reveal and the Insights hero.
4. **Taxonomy:** moods/themes/energy stay exactly as they are — no renames, no
   re-tagging of `daily_entries`. Adjacent-mood overlap is handled by partial
   affinity weights, not vocabulary changes.
5. **Cast changes** (display titles only — snake_case `id`s are FROZEN because
   they're persisted in `ArchetypeSnapshotStore` and key the flares dict,
   hero backgrounds, and voiced copy):
   - `the_hippie` → **"Golden Hour"** — *"Life at 0.75× speed. On purpose."*
   - `the_melancholic` → **"The Poet"** — keeps its existing tagline.
   - New 11th archetype `the_pophead` → **"The Pophead"** — *"Knows every
     word. Including the ad-libs."* First genre-anchored archetype.
6. **StarterPack:** swap one of the two Euphoric songs (Levitating) for a
   recognizable **Serene** track so all 9 moods are reachable from onboarding:
   "Banana Pancakes" — Jack Johnson, 2005, Serene, energy 2, theme
   Love & Romance, genre Singer-Songwriter (appleMusicID + artwork URL looked
   up at implementation time).

## Architecture

### 1. Affinity vectors (new: `Models/ArchetypeAffinity.swift`)

Each archetype (except The Shapeshifter) declares a static weight table.
Weights are hand-tuned constants, unit-tested for separability.

| Archetype (id) | Moods | Energy | Themes | Genre |
|---|---|---|---|---|
| party_animal | Euphoric 1.0, Joyful 0.3 | High 0.6 | Freedom & Escape 0.3 | — |
| flower_child | Joyful 1.0, Euphoric 0.3, Serene 0.2 | — | Hope & Perseverance 0.4 | — |
| hopeless_romantic | Tender 1.0 | Low 0.2 | Love & Romance 0.6, Longing & Desire 0.4, Heartbreak 0.3 | — |
| the_hippie (Golden Hour) | Serene 1.0, Dreamy 0.2, Joyful 0.2 | Low 0.4 | Freedom & Escape 0.3, Hope & Perseverance 0.2 | — |
| the_stargazer | Dreamy 1.0, Serene 0.2 | Low 0.3 | Longing & Desire 0.4 | — |
| born_in_the_wrong_generation | Nostalgic 1.0 | — | Memory & Nostalgia 0.6, Coming of Age 0.2 | — |
| the_melancholic (The Poet) | Melancholy 1.0, Tender 0.2 | Low 0.3 | Heartbreak 0.4, Loneliness 0.4 | — |
| loud_and_proud | Defiant 1.0, Dark 0.2 | High 0.5 | Rebellion & Protest 0.5, Empowerment & Self-Worth 0.3 | — |
| the_outsider | Dark 1.0, Melancholy 0.2 | — | Loneliness 0.4 | — |
| the_pophead | Joyful 0.4, Euphoric 0.4 | High 0.3 | — | Pop 0.9 |

**Separability axes** (each adjacent pair has a distinguishing dimension):
Party Animal vs. Flower Child → energy; The Poet vs. The Outsider → theme
(heartbreak/loneliness vs. dark mood itself); Golden Hour vs. Stargazer →
theme (freedom/hope vs. longing); The Pophead vs. Flower Child/Party Animal →
genre (must over-index on Pop specifically).

**The Shapeshifter** has no vector. It wins by absence: top score below an
absolute floor means taste is genuinely flat — an earned identity, not a
fallback.

### 2. Signal math (new: `ArchetypeScorer`, pure, no I/O)

Input: `[RatedSong]` where `RatedSong` gains two fields (Codable with
defaults so previously persisted seed JSON still decodes):
`isFavorite: Bool = false`, `ratedAt: Date?` (nil → fall back to
`entry.date`; catalog songs are rated on their drop day, which is a fine
proxy — no service/schema change).

Per song, a recency weight: `decay = 0.5^(ageDays / 45)` (45-day half-life).

Per category `c` (each mood, energy band, theme, and genre value):
- `wLike(c)` = Σ decay × (1 + 0.75·isFavorite) over songs with value > 0
- `wDislike(c)` = Σ decay over songs with value < 0
- Favorited-but-unrated songs count as likes with strength 0.75 × decay
  (hearts are signal even without a thumb).
- Smoothed like-rate: `r(c) = (wLike + 1) / (wLike + wDislike + 2)` (Laplace —
  one lucky 👍 cannot decide an identity).
- Signal: `s(c) = r(c) − rOverall` (centering on the user's overall smoothed
  rate removes both general positivity bias and curator exposure bias).
- Confidence: `conf(c) = n / (n + 3)` where `n = wLike + wDislike`
  (saturating; ~0.5 at 3 ratings, ~0.8 at 12).

`score(archetype) = Σ affinityWeight(c) × s(c) × conf(c)` over the
archetype's vector entries.

**Winner selection:**
- Unlock threshold unchanged: ≥ 10 rated songs (`minRatedArchetype`).
- If top score < `scoreFloor` (≈ 0.02, tuned in tests) → The Shapeshifter.
- **Hysteresis:** if the incumbent (previous stable archetype) is within
  `stickyMargin` (≈ 0.015) of the top score, the incumbent keeps the title.
  Prevents sibling-flapping on top of the existing weekly snapshot gate.
- Deterministic tie-break: `TasteProfile.allCases` order.

`TasteProfile.resolve(mood:modifier:)` is deleted. Call sites:
- `TasteMirror.build` → uses `ArchetypeScorer`.
- `TasteSeedView` reveal → scores the 10 seed picks directly (a real first
  read instead of a mood-string lookup).
- Wrapped + friend mirrors already flow through `TasteMirror.build` — they
  get the new scorer for free (friend mirrors pass an empty favorites set).

### 3. Receipts (`ArchetypeEvidence`)

The scorer returns the top 2–3 contributing (dimension, category) pairs with
human-readable counts, e.g. *"You liked 6 of your 7 Melancholy drops"*,
*"…and hearted 3 Heartbreak songs"* (favorites line included only when hearts
actually contributed). Surfaced in:
- **Reveal** (`ArchetypeRevealView`): replaces the generic `revealReason`
  strings in `InsightsViewModel`.
- **Insights hero**: a receipts subline under the existing voiced copy
  (`ArchetypeCopy.swift` gains the evidence parameter; the witty voice stays,
  receipts ground it).
- Friend mirrors use third-person phrasing (existing `isCurrentUser` plumbing).

### 4. What does not change

`ArchetypeSnapshotStore` weekly cadence and reveal gating; the reveal
animation; all dimension tiles and drill-downs; `WinningModifier` flavor
text; the database schema; the 10-rating unlock.

## Files touched

| File | Change |
|---|---|
| `Models/ArchetypeAffinity.swift` (new) | Affinity vectors + `ArchetypeScorer` + `ArchetypeEvidence` |
| `Models/TasteProfile.swift` | Retitle Golden Hour / The Poet; add `thePophead` (id, title, tagline, symbol, gradient); delete `resolve` |
| `Models/TasteMirror.swift` | `RatedSong` gains `isFavorite`/`ratedAt` (back-compat decode); `build(from:favoriteIDs:)` calls the scorer; expose evidence |
| `Models/SeedRatings.swift` | Stamp `ratedAt` at save time |
| `Models/StarterPack.swift` | Swap Levitating → a Serene track |
| `Models/ArchetypeRevealFlare.swift` | Flare entry for `the_pophead` |
| `ViewModels/InsightsViewModel.swift` | Pass favorite IDs into build; evidence-based reveal reason |
| `Views/Onboarding/TasteSeedView.swift` | Reveal via scorer |
| `Views/Components/ArchetypeCopy.swift` | Voiced copy: retitled tone for Golden Hour/The Poet, new `the_pophead` case, receipts subline |
| `Views/Components/ArchetypeHeroBackground.swift` | `PopheadBg` |
| `Daily MusicTests/TasteMirrorTests.swift` (+ new `ArchetypeScorerTests`) | See below |

## Testing (pure functions, no I/O)

1. **Exposure-bias regression:** curator-heavy Joyful catalog, user likes only
   the Melancholy drops → The Poet, never Flower Child.
2. **Flat rater** (likes everything equally) → The Shapeshifter.
3. **Favorites tip a near-tie** between two siblings.
4. **Recency:** a month of contrary daily ratings outweighs the onboarding
   seed; seed alone still yields a sensible first read.
5. **Pophead separability:** loves joyful folk → Flower Child; loves the same
   moods but over-indexes on Pop genre → The Pophead.
6. **Hysteresis:** incumbent within sticky margin keeps the title.
7. **Back-compat:** old persisted seed JSON (no `isFavorite`/`ratedAt`)
   decodes; every archetype id has a flare, hero background, and voiced copy
   (exhaustiveness test over `allCases`).
8. Receipts copy: counts match the underlying tallies.

## Risks / notes

- Weights are hand-tuned: the test suite doubles as the tuning harness; tweak
  constants, not structure.
- The Pophead needs real visual-identity work (gradient, symbol, flare,
  background, voiced copy) to match the bar set by the existing 10.
- `docs/ARCHITECTURE.md` must be updated with the new scorer (per standing
  maintenance rule).
