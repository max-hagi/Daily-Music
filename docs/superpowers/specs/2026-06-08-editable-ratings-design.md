# Editable Ratings — Design Spec
**Date:** 2026-06-08

## Problem

Users rate songs during onboarding (the StarterPack taste-seed) and can't view or change those
ratings afterwards. The same gap exists for catalog ratings from the Insights drill-down: the
`CategorySongsSheet` shows songs with a static 👍/👎 emoji but no way to change them. The Vault
list rows show no rating state at all, so it's not obvious the entries are already re-rateable via
the detail view.

## Scope

- Make ratings interactive in `CategorySongsSheet` (covers seed songs and catalog songs).
- Show a read-only rating badge on `VaultTintedEntryRow` in the Vault list.
- No changes to `EntryRow` (Favorites), `RatingBar`, `RatingModel`, or the Supabase schema.

## Two Rating Backends

There are two sources of truth for ratings:

| Type | Detection | Backend |
|------|-----------|---------|
| Seed (onboarding StarterPack) | `entry.date == .distantPast` | `SeedRatings` (UserDefaults) |
| Catalog | any other date | `RatingService` (Supabase `song_ratings`) |

Seed songs use `date: .distantPast` (set in `StarterPack.song()`). This is a reliable, stable
signal — no new model field is needed.

## Part 1 — Interactive thumbs in `CategorySongsSheet`

### New parameters
```swift
// Already has:
let title: String
let songs: [RatedSong]

// Add:
var onRatingChanged: (() -> Void)? = nil   // fires after any write; callers reload Insights
```

### Local state
```swift
@Environment(AppEnvironment.self) private var env
@State private var localRatings: [UUID: Int?] = [:]   // overrides for optimistic UI
```

`localRatings` is seeded in `.onAppear` from the incoming `songs` array. When a thumb is tapped,
the entry's slot is updated immediately (optimistic), then an async task writes to the correct
backend and fires `onRatingChanged()`.

### Rating write logic
```
func setRating(_ newValue: Int?, for rated: RatedSong):
  localRatings[rated.entry.id] = newValue           // optimistic
  if rated.entry.date == .distantPast:
    load SeedRatings, replace/insert/remove the matching RatedSong, save
  else:
    env.ratings.setRating(newValue, entryID: rated.entry.id)
  onRatingChanged?()
```

Tapping the active thumb sets `newValue = nil` (clear). Tapping the inactive thumb switches to
that value.

**Error handling:** Seed writes (`SeedRatings.save`) are synchronous and cannot fail. Catalog
writes (`RatingService.setRating`) can fail; on failure the optimistic local state is left as-is
(wrong) — this matches the existing `RatingModel` pattern and is acceptable for v1. A future
improvement could revert `localRatings` on error.

### Row UI
Replace the static `Text(rated.value > 0 ? "👍" : "👎")` with two small Liquid Glass thumb
buttons matching the visual language of `RatingBar` (smaller `controlSize` appropriate for list
rows, e.g. 32 pt). Show the active thumb filled (green/red), inactive thumb clear. Use the
existing `RatingBar` style constants as reference — don't re-introduce magic numbers.

Haptic feedback: `Haptics.tap()` on each tap, same as `RatingBar`.

### Reload signal
After a successful write, `onRatingChanged?()` is called. `InsightsView` provides:
```swift
{ Task { await self.model?.load() } }
```

The reload is fire-and-forget — the sheet stays open showing the optimistic state. When the user
closes all the sheets and returns to `InsightsView`, the mirror reflects the updated ratings.

## Part 2 — Callback wiring

The callback threads through three layers. Each adds one optional parameter:

| File | Change |
|------|--------|
| `StandoutDetailView` | Add `onRatingChanged: (() -> Void)? = nil`; pass to `CategorySongsSheet` |
| `TasteMirrorBoard` | Add `onRatingChanged: (() -> Void)? = nil`; pass to `StandoutDetailView` |
| `InsightsView` | Pass `onRatingChanged: { Task { await model?.load() } }` to `TasteMirrorBoard` |

`FriendInsightsView` also uses `TasteMirrorBoard` but with `isCurrentUser: false` — its tiles
are already inert (no `onTap` closure). Leave `onRatingChanged` as `nil` there; the sheet is
never shown for a friend's mirror.

`StandoutDetail` and `CategoryDrill` are value-type snapshots — no changes needed to them.

## Part 3 — Vault rating badge on `VaultTintedEntryRow`

`VaultTintedEntryRow` already loads artwork palette via `.task(id: entry.id)`. Add a second
load alongside it:

```swift
@Environment(AppEnvironment.self) private var env
@State private var myRating: Int? = nil

// in .task(id: entry.id):
myRating = try? await env.ratings.myRating(entryID: entry.id)
```

In the trailing HStack (between the `Spacer()` and the chevron), show a small badge when rated:
```swift
if let r = myRating {
    Text(r > 0 ? "👍" : "👎")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

The badge is read-only. Re-rating is done by opening the entry detail (already supported via
`RatingBar` with `allowsRating: true`). No change to the tap gesture or the `fullScreenCover`.

## What is NOT in scope

- `EntryRow` (used in Favorites) — no changes.
- `RatingBar` / `RatingModel` — no changes.
- Supabase schema — no changes.
- Any new screen or navigation destination.
- `FriendInsightsView` — read-only, no rating changes.

## Files changed

1. `Views/Components/CategorySongsSheet.swift` — interactive thumbs + local rating state
2. `Views/StandoutDetailView.swift` — thread `onRatingChanged` parameter
3. `Views/Components/TasteMirrorBoard.swift` — thread `onRatingChanged` parameter
4. `Views/InsightsView.swift` — provide `onRatingChanged` closure
5. `Views/VaultView.swift` — add rating badge to `VaultTintedEntryRow`

## Testing notes

- Tap 👍 on a seed song in Insights → close all sheets → Insights mirror updates.
- Tap 👎 on the same seed song → rating flips → mirror updates again.
- Tap the active thumb → rating clears → song drops from rated count.
- Tap 👍 on a catalog song → `song_ratings` row updated (confirmed via Supabase dashboard).
- Vault list row shows 👍/👎 badge for previously rated entries, blank for unrated.
- `FriendInsightsView` drill-down shows no thumbs (read-only, `onRatingChanged` is nil).
