# Insights Redesign — v2

**Date:** 2026-06-09
**Status:** Approved for implementation

## Goal

Replace the 46-archetype system with 9 iconic, mood-anchored archetypes that are instantly readable, socially shareable, and dopamine-delivering. Restructure the Insights screen into a clear three-act scroll with a transparent, inline-ratable history at the bottom.

---

## The 9 Archetypes

| Mood | Name | Tagline | Gradient (lead → tail) |
|------|------|---------|------------------------|
| Euphoric | Party Animal | "The emergency contact for fun." | `#FF6A1E → #FF3D00` |
| Joyful | Flower Child | "Has a pocket full of sunshine. Sharing whether you asked or not." | `#FFD700 → #FFAA00` |
| Tender | Hopeless Romantic | "Every love song is their autobiography." | `#FF64AA → #C71585` |
| Serene | The Hippie | "Peace and love, man. ☮️ Peace and love." | `#20B2AA → #008080` |
| Dreamy | The Stargazer | "Body on Earth. Mind: somewhere past the third star on the right." | `#9370DB → #4B0082` |
| Nostalgic | Born in the Wrong Generation | "Would've thrived in any decade except this one." | `#D4891A → #8B5E3C` |
| Melancholy | The Melancholic | "Won't listen to anything that doesn't mean something. Everything means something." | `#4A6FA5 → #1A237E` |
| Defiant | Loud & Proud | "Not a phase. Never was." | `#CC1E1E → #660000` |
| Dark | The Outsider | "Sunlight? Never heard of her." | `#7A4FBF → #1A0A2E` |
| Balanced | The Shapeshifter | "Commits to nothing. Loves everything." | `#2153F5 → #0B1F7A` (existing Eclectic) |

The `balanced` archetype fires when `TasteMirror.mood.topStandout` is nil — no dominant mood across all ratings.

---

## What Changes

### 1. `TasteProfile.swift` — full rewrite

**Add** a `tagline: String` field.

**Remove** 36 modifier-specific variants. Keep exactly 10 static instances (9 moods + balanced).

**Simplify `resolve()`** from a ~100-line switch to a 10-branch mood lookup:

```swift
static func resolve(mood: String?, modifier: String?) -> TasteProfile {
    switch mood {
    case "Euphoric":   return partyAnimal
    case "Joyful":     return flowerChild
    case "Tender":     return hopelessRomantic
    case "Serene":     return theHippie
    case "Dreamy":     return theStargazer
    case "Nostalgic":  return bornInTheWrongGeneration
    case "Melancholy": return theMelancholic
    case "Defiant":    return loudAndProud
    case "Dark":       return theOutsider
    default:           return theShapeshifter
    }
}
```

The `modifier` parameter is kept in the signature so call sites don't change, but it no longer drives the archetype — it drives the flavor text in the hero (existing `heroWhy` logic in `TasteMirrorBoard`, unchanged).

**Update SF Symbols** to match the new names:

| Name | Symbol |
|------|--------|
| Party Animal | `sparkles` |
| Flower Child | `leaf.fill` |
| Hopeless Romantic | `heart.fill` |
| The Hippie | `bird.fill` |
| The Stargazer | `moon.stars.fill` |
| Born in the Wrong Generation | `clock.arrow.circlepath` |
| The Melancholic | `cloud.moon.fill` |
| Loud & Proud | `flame.fill` |
| The Outsider | `circle.lefthalf.filled` |
| The Shapeshifter | `circle.grid.2x2.fill` |

---

### 2. `TasteMirrorBoard.swift` — section labels + tagline line in hero

**Hero card** gains one new text element between the name and the flavor text:

```
[icon]                          YOUR ARCHETYPE
The Outsider                                    ← .system(size: 34, weight: .heavy, design: .rounded)
"Sunlight? Never heard of her."                 ← .callout.italic, .white.opacity(0.82)
Because 89% of your Post-Punk picks land…      ← .footnote, .white.opacity(0.58)  (existing heroWhy)
```

**Section headers** added above the tile grid and above the history section:

```swift
Text("WHY YOU'RE YOU")
    .font(.caption2.weight(.heavy))
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, alignment: .leading)
```

Everything else in `TasteMirrorBoard` — tiles, secondary rows, `StandoutDetailView` drill-down — is **unchanged**.

---

### 3. `InsightsView.swift` — history section

Add a `historySection` view at the bottom of the scroll, below `TasteMirrorBoard`:

```swift
private func historySection(_ mirror: TasteMirror) -> some View {
    // All published entries, newest first, with current rating from RatingsStore
}
```

**Data source:** `env.entries.publishedHistory()` joined with `env.ratings` (already loaded in `InsightsViewModel.load()`). Pass the full joined list down as `[HistoryEntry]`.

**`HistoryEntry`** — view-model level struct, not domain. Lives in `InsightsViewModel.swift`:
```swift
struct HistoryEntry: Identifiable {
    let entry: DailyEntry
    var rating: Int?   // +1 / -1 / nil (unrated)
    var id: UUID { entry.id }
}
```

**Each row (`HistoryEntryRow`):**
- `AlbumArtView` (44pt, cornerRadius 10)
- Song title + artist name (existing `DailyEntry` fields)
- Date formatted as "Jun 8"
- `RatingBar(entry: entry, controlSize: 36, symbolSize: 14, spacing: 8)` — reuse existing component directly, no new pill needed. Its existing `RatingsStore` binding means re-rating is already wired up and propagates across all screens for free.

After a rating change `InsightsViewModel.load()` is called to recompute the mirror, same as the existing `onRatingChanged` callback in `TasteMirrorBoard`.

If the mirror's archetype changes as a result of re-rating, the hero badge gradient transitions with the existing `.easeInOut(duration: 0.6)` animation. **No fullscreen reveal** is triggered from inline re-rating — the fullscreen reveal fires only from the weekly `ArchetypeSnapshotStore` cadence.

---

### 4. Animations

**Principle:** animate state changes, not attention. Never block interaction.

| Moment | Animation |
|--------|-----------|
| Screen load — badge entrance | `.spring(response: 0.55, dampingFraction: 0.8)` slide-up + fade |
| Tagline fade-in after name | `.easeOut(duration: 0.3).delay(0.15)` |
| Flavor text fade-in | `.easeOut(duration: 0.25).delay(0.25)` |
| Tiles entrance | `.easeOut(duration: 0.3).delay(Double(index) * 0.07)`, capped at index 3 |
| History rows | No stagger — static appearance |
| Rating pill tap | `.spring(response: 0.35, dampingFraction: 0.65)` scale 0.85 → 1.1 → 1.0 + color cross-fade |
| Archetype gradient shift (re-rating) | Existing `.easeInOut(duration: 0.6)` on `washColors` |
| Reduce motion | All spring/slide animations replaced with `.easeInOut(duration: 0.4)` opacity-only transitions |

---

## What Does NOT Change

| File | Status |
|------|--------|
| `TasteMirror.swift` | Untouched — pure engine, no domain changes |
| `ArchetypeRevealView.swift` | Untouched — weekly reveal experience is perfect as-is |
| `ArchetypeSnapshotStore.swift` | Untouched — weekly cadence logic unchanged |
| `StandoutDetailView.swift` | Untouched |
| `CategorySongsSheet.swift` | Untouched |
| `FriendInsightsView.swift` | Picks up new names transparently via `TasteProfile.resolve()` |
| `TasteMirrorTests.swift` | Untouched — TasteMirror engine unchanged |

**`ArchetypeRevealTests.swift` and `ArchetypeSnapshotTests.swift`** need updating for the new archetype IDs and tagline field.

---

## New Files

| File | Purpose |
|------|---------|
| `Views/Components/HistoryEntryRow.swift` | One row in the history section — reuses existing `RatingBar` and `AlbumArtView` |

---

## Migration Note

`ArchetypeSnapshotStore` persists the archetype ID string in `UserDefaults` (e.g. `"euphoric_disco_kid"`). When existing users update to this version, their stored IDs won't match any of the 9 new IDs. `TasteProfile.profile(id:)` returns `nil` for unknown IDs, so `stableArchetype` is nil on first launch after the update. `ArchetypeSnapshotEvaluator` will treat this as a fresh state and queue a new reveal at the next weekly evaluation — effectively giving existing users a clean, satisfying re-reveal moment. No migration code needed; nil-handling already exists in the evaluator.

---

## Edge Cases

- **Unrated entry tapped to +1 then immediately to -1:** `model.load()` fires twice. Both calls are idempotent — second call overwrites first. Acceptable.
- **History with 0 entries:** Section shows empty state text: *"Your daily songs will appear here once you start listening."*
- **Archetype "forming" (< 10 ratings):** Hero shows "FORMING" state as before. History section still shows all entries (helps users understand they need to rate more).
- **Very long song titles:** `.lineLimit(1)` + `.minimumScaleFactor(0.8)` on song name in `HistoryEntryRow`.
