# Archetype Engine v2 — Design Spec

- **Date:** 2026-06-07
- **App:** Daily Music (SwiftUI + Supabase)
- **Status:** Approved; ready for implementation plan.
- **Supersedes:** archetype section of `2026-06-02-insights-taste-mirror-design.md`

## 1. Goal

Three problems with the current engine:

1. `dominant` ranks by raw like count — a mood you've heard a lot but half-disliked can beat one you've loved every time.
2. The archetype modifier (decade/theme) is checked in a hard-coded priority order, ignoring signal strength.
3. The archetype catalogue is sparse (only 3 specialized variants) and uses placeholder identifiers as titles.

This spec fixes all three, expands the catalogue to ~50 named archetypes, and adds two UX features: dynamic "why it's you" text and a per-category song drill-down.

---

## 2. Computation changes

### 2a. Net-score dominant

In `TasteMirror.dimension()`, change the sort key from raw likes to net score:

```swift
// Before
.sorted { ($0.likes, $0.total, $1.name) > ($1.likes, $1.total, $0.name) }

// After
.sorted { ($0.likes - $0.dislikes, $0.likes, $1.name) > ($1.likes - $1.dislikes, $1.likes, $0.name) }
```

Primary: `likes − dislikes`. Tiebreak: raw likes. Everything else (`overIndex`, `skip`, `topStandout`, archetype resolution) is unchanged.

Update `TasteMirrorTests.moodDominantIsMostLiked` — name and comment should reflect "most net-positive" semantics. The worked-example assertion still holds (Melancholy net +7 still wins).

### 2b. Cross-dimension modifier selector

Replace the hard-coded mood+decade / mood+theme / mood-only cascade in `TasteMirror.build()` with a dynamic selector:

```swift
// Dimensions eligible to contribute a modifier (mood drives slot 1)
let modifierDimensions: [DimensionInsight] = [decade, theme, genre, language]

// Pick the dimension whose overIndex has the highest margin above overall
let bestModifier: String? = modifierDimensions
    .compactMap { dim -> (name: String, margin: Double)? in
        guard let oi = dim.overIndex else { return nil }
        return (oi.name, oi.likeRate - overall)
    }
    .max { $0.margin < $1.margin }?
    .name

let archetype: TasteProfile? = isArchetypeUnlocked
    ? TasteProfile.resolve(mood: mood.topStandout?.name, modifier: bestModifier)
    : nil
```

`resolve()` signature becomes `resolve(mood: String?, modifier: String?) -> TasteProfile`.

**Tie-breaking:** if two dimensions have equal margin, prefer decade > theme > genre > language (stable ordering).

**No qualifier modifier:** if no dimension has a qualifying `overIndex`, `bestModifier` is nil and `resolve()` falls through to the mood-only default.

---

## 3. Archetype catalogue

`TasteProfile` expands from 13 to ~50 entries. Each entry has: stable `id` (snake-case matching the table below), `title` (the badge name — user edits this freely), `symbol` (SF Symbol), `colors` (gradient).

The `resolve()` lookup is a flat `switch (mood, modifier)` — no priority cascade needed once the modifier is pre-selected.

### Full catalogue

| ID | Title | Mood | Modifier |
|---|---|---|---|
| `euphoric_disco_kid` | Disco Kid | Euphoric | 1970s |
| `euphoric_synth_pop_kid` | Synth-Pop Kid | Euphoric | 1980s |
| `euphoric_festival_kid` | Festival Kid | Euphoric | 2010s / 2020s |
| `euphoric_anthemist` | Anthemist | Euphoric | Empowerment & Self-Worth |
| `euphoric_default` | Euphoric | Euphoric | — |
| `joyful_flower_child` | Flower Child | Joyful | 1960s |
| `joyful_bubblegum_pop` | Bubblegum Pop | Joyful | 2000s |
| `joyful_indie_kid` | Indie Kid | Joyful | 2010s |
| `joyful_young_at_heart` | Young at Heart | Joyful | Coming of Age |
| `joyful_default` | Joy Seeker | Joyful | — |
| `tender_canyon_soul` | Canyon Soul | Tender | 1970s |
| `tender_romantic` | Romantic | Tender | Love & Romance |
| `tender_hopeless_romantic` | Hopeless Romantic | Tender | Heartbreak |
| `tender_default` | Tender Soul | Tender | — |
| `serene_free_spirit` | Free Spirit | Serene | 1960s |
| `serene_mellow_soul` | Mellow Soul | Serene | 1970s |
| `serene_ambient_wanderer` | Ambient Wanderer | Serene | Freedom & Escape |
| `serene_default` | Still Waters | Serene | — |
| `dreamy_neon_rider` | Neon Rider | Dreamy | 1980s |
| `dreamy_shoegaze_kid` | Shoegaze Kid | Dreamy | 1990s |
| `dreamy_indie_mystic` | Indie Mystic | Dreamy | 2010s |
| `dreamy_dream_chaser` | Dream Chaser | Dreamy | Longing & Desire |
| `dreamy_default` | Cloud Drifter | Dreamy | — |
| `nostalgic_rock_pilgrim` | Rock Pilgrim | Nostalgic | 1970s |
| `nostalgic_80s_time_traveler` | 80s Time Traveler | Nostalgic | 1980s |
| `nostalgic_90s_kid` | 90s Kid | Nostalgic | 1990s |
| `nostalgic_memory_keeper` | Memory Keeper | Nostalgic | Memory & Nostalgia |
| `nostalgic_default` | Sentimentalist | Nostalgic | — |
| `melancholy_dark_waver` | Dark Waver | Melancholy | 1980s |
| `melancholy_grunge_kid` | Grunge Kid | Melancholy | 1990s |
| `melancholy_indie_confessor` | Indie Confessor | Melancholy | 2000s |
| `melancholy_indie_heartbreaker` | Indie Heartbreaker | Melancholy | Heartbreak |
| `melancholy_default` | Brooder | Melancholy | — |
| `defiant_punk_purist` | Punk Purist | Defiant | 1970s |
| `defiant_rock_rebel` | Rock Rebel | Defiant | 1980s |
| `defiant_grunge_rebel` | Grunge Rebel | Defiant | 1990s |
| `defiant_protest_rebel` | Protest Rebel | Defiant | Rebellion & Protest |
| `defiant_champion` | Champion | Defiant | Empowerment & Self-Worth |
| `defiant_default` | Defiant Spirit | Defiant | — |
| `dark_post_punk_poet` | Post-Punk Poet | Dark | 1980s |
| `dark_industrial_heart` | Industrial Heart | Dark | 1990s |
| `dark_goth_soul` | Goth Soul | Dark | Loneliness |
| `dark_noir_soul` | Noir Soul | Dark | Heartbreak |
| `dark_rebel` | Dark Rebel | Dark | Rebellion & Protest |
| `dark_default` | Midnight Drifter | Dark | — |
| `balanced_default` | Eclectic | — | — |

**Genre variants** — a small second table keyed on `(mood, genre)` for cases where a genre over-index beats all decade/theme margins. Add entries for the most common genres where culturally meaningful. These are added as needed during tagging; the resolver falls through to the mood-default if no genre entry exists for that combination.

**Multi-decade matching:** "2010s" and "2020s" both route to `euphoric_festival_kid`; "2000s" and "2010s" both route to `joyful_indie_kid`. Handle this in `resolve()` with a `decadeYear >= X` check identical to the current approach, or by normalising the modifier string before lookup.

---

## 4. "Why it's you" dynamic text

The hero card's explanation sentence is templated from the actual winning signal:

```
modifier = decade  → "You keep {rate}% of {decade} songs — {margin}pts above your {overall}% average."
modifier = theme   → "You keep {rate}% of songs about {theme} — {margin}pts above your average."
modifier = genre   → "You keep {rate}% of {genre} tracks — {margin}pts above your average."
modifier = nil     → "Your most-kept mood is {mood} — you say yes {rate}% of the time."
```

All values come directly from the `DimensionInsight` that supplied the modifier and the `TasteMirror.overallLikeRate`. No hardcoded strings except the template shape.

---

## 5. Category drill-down (new UX)

Tapping any category row in any dimension breakdown (mood, decade, theme, genre, language, energy) presents a bottom sheet listing every rated song in that category.

**Sheet contents:**
- Title: `"{Category}" songs` (e.g. `"Melancholy" songs`)
- Subtitle: like-rate summary (`9 liked · 2 disliked`)
- Song list sorted: liked first, then disliked; within each group, reverse-chronological
- Each row: album art thumbnail · title · artist · 👍 or 👎 badge

**Data source:** `TasteMirror` already holds the full `[RatedSong]` list it was built from. Add a helper:

```swift
extension TasteMirror {
    func songs(inDimension dimension: DimensionInsight, category: String) -> [RatedSong]
}
```

This filters the rated list by the dimension's tag key and the category name. Pure function, no I/O.

**Navigation:** the sheet is presented from `InsightsView` (or `TasteMirrorBoard`). No new view model needed — pass the filtered `[RatedSong]` directly to a `CategorySongsSheet` view.

---

## 6. Changed files

| File | Change |
|---|---|
| `Models/TasteMirror.swift` | Net-score sort; cross-dimension modifier selector; `songs(inDimension:category:)` helper |
| `Models/TasteProfile.swift` | Expand catalogue to ~46 entries; update `resolve(mood:modifier:)` signature; update `id` to snake_case; set real titles |
| `Views/Components/TasteMirrorBoard.swift` | Dynamic "why it's you" text using modifier stats; category rows become tappable |
| `Views/Components/CategorySongsSheet.swift` | New: bottom sheet showing contributing songs for a tapped category |
| `Daily MusicTests/TasteMirrorTests.swift` | Update `moodDominantIsMostLiked` comment; add tests for modifier selector, genre modifier, and drill-down helper |

---

## 7. Testing

All new logic in `TasteMirror` is pure — fully unit-testable:

- Net-score dominant: verify a mood with higher net score beats one with more raw likes
- Modifier selector: verify decade wins over theme when its margin is higher; genre wins when it has the highest margin
- Multi-decade routing: verify 2020s → `euphoric_festival_kid`
- Modifier nil fallback: verify mood-only default when no dimension has a qualifying `overIndex`
- `songs(inDimension:category:)`: verify correct filtering and sort order

`CategorySongsSheet` verified in simulator with mock data.

---

## 8. Deferred

- Energy lean as an archetype modifier (would require doubling the catalogue; revisit when data shows energy is a strong differentiator)
- Archetype stability / hysteresis (only flip archetype after sustained signal change)
- Genre variant catalogue entries beyond the most common genres
