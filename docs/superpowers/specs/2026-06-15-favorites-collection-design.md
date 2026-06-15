# Favorites as a Collection — Design

**Date:** 2026-06-15
**Status:** Approved (pending spec review)
**Surface:** `FavoritesView` (the Favorites tab)

## Goal

Turn the Favorites screen from a plain hearted-songs list into a real *collection*:

1. Render each favorite with the **record/sleeve treatment** (`SleeveView`) instead of
   plain `AlbumArtView`, so the condition "quality" (mint / secondhand / salvaged /
   missing) reads at a glance — identical to how the Vault shows the same songs.
2. Let the user **drag to rearrange** their collection into a manual order.
3. Add **search** (free-text) and **filter** (genre / decade / mood) to dig the crate.

This is a single-screen, focused change. No backend schema changes.

## Decisions (locked)

| Question | Decision |
| --- | --- |
| Condition source | **Reuse listen status** — `env.listensStore.status(for: entry)`, same as the Vault. No new state. |
| Surface the grade | **Sleeve only (visual).** The `SleeveView` treatment + its embedded "secondhand"/"salvaged" stamps carry the grade. No extra captions/badges. |
| Order storage | **Local-only (UserDefaults).** No Supabase migration. |
| Default order | **Newest-first** until the user drags. Manual order takes over after the first reorder. New hearts land **on top**; un-hearted songs drop out. |
| Reorder trigger | **Long-press → rearrange mode → drag → Done.** |
| Reorder layout | **"Lift off the shelves"** — browse as the shelf wall; while editing, records lift into a uniform 3-column grid, then settle back on Done. |
| Filter dimensions | **Genre, Decade, Mood** (metadata). Condition-grade filtering is out of scope. |
| Search | **Free-text over title + artist.** |

## Components

### 1. `SleeveView` swap (condition treatment)

In `FavoritesView`, replace the `AlbumArtView` inside the record cell with:

```swift
SleeveView(
    entry: entry,
    status: env.listensStore.status(for: entry),
    size: <cell size>,
    missingVariant: env.variants.missingSleeve,
    secondhandVariant: env.variants.secondhand
)
```

This is the exact wiring the Vault uses (`VaultView` → `MonthShelvesView`), so a song's
condition looks the same in both places.

- **Drop the `.ultraThinMaterial` frame** currently wrapping the art. `SleeveView`
  brings its own sleeve, peeking disc, and shadow; the glass frame would fight it. The
  Vault renders sleeves bare. Keep the title/artist caption beneath each record.

### 2. `FavoritesOrderStore` (new — local-only order)

New `@MainActor @Observable` store, **owned by `FavoritesView` as `@State`** (single
consumer; no `AppEnvironment` plumbing). Backed by `UserDefaults`.

- **Key:** `favorites.manual_order.v1`, value `[String]` (uuid strings). **Key absent =
  no manual order yet.**
- **Injectable `UserDefaults`** (default `.standard`) so tests use a throwaway suite.

API (the ordering logic is **pure** and unit-tested):

```swift
/// Pure. No saved order → returns `favorites` untouched (newest-first as given).
/// Saved order present → orders by it; favorites NOT in the saved list (newly
/// hearted) prepend on top in their incoming order; saved ids no longer present
/// are ignored.
func arranged(_ favorites: [DailyEntry]) -> [DailyEntry]

/// Persists the given live id order (also trims ids not in `ids`, so stored order
/// can't grow stale). Called when a drag settles.
func commit(_ ids: [UUID])
```

`favorites` is passed in already date-sorted newest-first (from the view model).

### 3. `FavoritesFilter` (new — pure search + filter)

A small value type + pure helpers, in `Models/FavoritesFilter.swift`. Holds the active
narrowing state and decides what shows.

```swift
struct FavoritesFilter: Equatable {
    var query: String = ""              // free-text over title + artist
    var genres: Set<String> = []        // empty = no genre constraint
    var decades: Set<String> = []
    var moods: Set<String> = []

    var isActive: Bool { !query.isEmpty || !genres.isEmpty || !decades.isEmpty || !moods.isEmpty }

    /// An entry passes when it matches the (possibly empty) query AND each
    /// non-empty dimension contains the entry's value. Within a dimension the
    /// selected values are OR'd; across dimensions they are AND'd.
    func matches(_ entry: DailyEntry) -> Bool
}

/// The distinct genre/decade/mood values present in the current favorites, used
/// to build the filter sheet (only offer facets that actually exist).
func availableFacets(in favorites: [DailyEntry]) -> (genres: [String], decades: [String], moods: [String])
```

`DailyEntry.genre/decade/mood` are optional strings (already used by `FavoriteEntryPeek`).
`matches` ignores `nil`/empty values when building facets and treats a `nil` dimension
value as "does not match" when that dimension is constrained.

### 4. `FavoritesView` changes

New view state:

```swift
@State private var orderStore = FavoritesOrderStore()
@State private var arranged: [DailyEntry] = []   // working array (ordered, pre-filter)
@State private var filter = FavoritesFilter()
@State private var isRearranging = false
@State private var showingFilterSheet = false
```

**Data flow** (per render):
`FavoritesStore.ids` → `FavoritesViewModel` loads filtered entries (newest-first) →
`orderStore.arranged(...)` → `arranged` → apply `filter.matches` → **displayed subset** →
wall or grid. The existing `.task(id: env.favoritesStore.ids)` reload still drives
hearts in/out; `arranged` keeps new ones on top and drops removed ones.

**Browse mode (default):**
- The existing shelf wall — rows of 3 + decorative ledges — now rendering `SleeveView`s.
- Tap opens the entry (`selectedEntry`). Context menu (Open / Remove favorite) unchanged.
- **Long-press (~0.4s)** on a record → `isRearranging = true` + haptic. Only enterable
  with **≥2 favorites and no active search/filter** (see below).
- **`.searchable`** bound to `filter.query` (over title + artist).
- A **Filter** toolbar button (`line.3.horizontal.decrease.circle`, filled + count badge
  when active) → presents a **filter sheet**: sections for Genre / Decade / Mood, each a
  list of toggleable facets from `availableFacets`, plus a **Clear** action.

**Rearrange mode:**
- Ledges fade out; records lift into a uniform **3-column `LazyVGrid`** and **jiggle**
  (±~1.5° autoreversing wobble, phase-offset per record).
- Each record glides between wall ↔ grid via `matchedGeometryEffect(id: entry.id)`.
- Tap-to-open and context menu are **disabled**.
- Toolbar shows **Done**; tapping the background also exits.
- **Drag:** long-press-drag in the grid tracks the lifted record (raised z-index, slight
  scale-up + shadow) and maps the finger position → target grid index from the uniform
  cell metrics (`GeometryReader`). `arranged` reshuffles live with animation. On release,
  `orderStore.commit(arranged.map(\.id))`.

**Search/filter ⇄ rearrange interaction:**
- Rearrange is **disabled while narrowing** (query non-empty or any filter set) — you
  can't sensibly reorder a subset. If a filter/search is applied while rearranging, exit
  rearrange. Manual order is preserved underneath; the filtered view renders the matching
  subset in its current arranged order.

**States:**
- **No favorites** — existing empty state, unchanged.
- **No matches** (favorites exist but filter/search excludes all) — a distinct "No matches"
  message with a **Clear filters** button.
- Loading / failed — unchanged.

### 5. Optional helper

A small reusable `JiggleModifier` if it keeps `FavoritesView` readable; otherwise inline.

## Testing

TDD the pure logic; interactions are verified by hand (matches the project's test style —
no UI tests).

**`FavoritesOrderStoreTests`** (injected `UserDefaults(suiteName:)`):
- No saved order → `arranged` returns input unchanged (newest-first passthrough).
- Saved order present → output respects it.
- New favorite (not in saved order) → appears on top.
- Removed favorite (in saved order, not in input) → dropped.
- `commit` persists and survives a fresh store instance on the same suite.
- `commit` trims ids no longer present.

**`FavoritesFilterTests`**:
- Empty filter → everything matches; `isActive == false`.
- Query matches title or artist case-insensitively; non-match excluded.
- Single dimension constrains correctly; `nil` entry value excluded when that dimension is set.
- Multiple dimensions AND together; values within a dimension OR together.
- `availableFacets` returns distinct, non-empty values only.

**Manual / visual:** sleeve treatment matches the Vault, long-press enters rearrange,
records lift into the grid and jiggle, drag reorders smoothly, Done settles them onto the
shelves in the new order, order persists across app launches, search + filter narrow live,
rearrange is blocked while narrowing.

## Files

- **New:** `Daily Music/ViewModels/FavoritesOrderStore.swift`
- **New:** `Daily Music/Models/FavoritesFilter.swift`
- **New:** `Daily MusicTests/FavoritesOrderStoreTests.swift`
- **New:** `Daily MusicTests/FavoritesFilterTests.swift`
- **Edit:** `Daily Music/Views/FavoritesView.swift` (sleeve swap, search, filter sheet,
  rearrange mode, wall↔grid, jiggle, drag, no-matches state)
- New test files need manual `.pbxproj` target registration (project convention).

## Out of scope (v1)

- Cross-device order sync (would need a Supabase `position` column + migration).
- Edge auto-scroll while dragging near the top/bottom (favorites lists are short).
- Condition-grade filtering, and any favorites-specific condition independent of listen status.
- Reordering within a filtered subset.
