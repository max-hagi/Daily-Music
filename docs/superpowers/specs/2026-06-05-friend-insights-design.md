# Friend insights (Social Phase C) — a friend's taste + "you vs them"

**Date:** 2026-06-05
**Status:** Approved, ready for implementation

## 1. Goal

From the Friends tab, tap a friend to see **their** taste — rendered with the same
Insights mirror, read-only — plus a **"you vs them"** comparison (how much your
taste matches, songs you both love, songs you clash on).

## 2. Scope

**In:** friend-insights screen (their read-only mirror + comparison card), a new
pure `TasteComparison` engine, extraction of the Insights rendering into a
reusable `TasteMirrorBoard`, a `NavigationLink` entry point, mock seeding.

**Out (later phases):** friend-avatar bubbles on favourited entries; the global
all-vs-friends toggle on Today/Vault; nudges (need APNs/paid account).

## 3. Data & backend

No new backend. The pieces already exist:
- `EntryService.publishedHistory()` → `[DailyEntry]` (shared, tagged catalog).
- `RatingService.myRatings()` → `[UUID: Int]` (my 👍 = +1 / 👎 = −1).
- `FriendService.friendRatings(friendID:)` → `[UUID: Int]` — the friend's ratings,
  via the `friend_ratings` RPC, which itself re-checks `are_friends(...)` server-side
  ([friend-graph.sql:125](friend-graph.sql); applied to the live DB 2026-06-05).
- `TasteMirror.build(from: [RatedSong])` — the pure engine, reused unchanged.

A friend's mirror = `TasteMirror.build` fed `publishedHistory ⨝ friendRatings`,
exactly how `InsightsViewModel` builds mine today.

## 4. New pure engine — `TasteComparison`

`Models/TasteComparison.swift`. Pure, `Equatable`, no I/O — a sibling to `TasteMirror`.

```swift
struct TasteComparison: Equatable {
    let coRatedCount: Int          // songs we BOTH rated
    let agreedCount: Int           // co-rated where our 👍/👎 sign matches
    let matchPercent: Int?         // round(agreed/coRated*100); nil until coRated >= minShared
    let bothLoved: [DailyEntry]    // both 👍, in publishedHistory order
    let clashed:   [DailyEntry]    // one 👍, one 👎, in publishedHistory order

    static let minShared = 3       // below this, a % is meaningless → show "not enough yet"

    static func build(mine: [UUID: Int], theirs: [UUID: Int], history: [DailyEntry]) -> TasteComparison
}
```

**Rules:**
- `coRated` = keys present in both maps. `agreedCount` = co-rated where `sign(mine)==sign(theirs)`.
  These come straight from the maps (don't require `history`) so the % is accurate.
- `matchPercent` = `coRatedCount >= minShared ? Int((Double(agreed)/Double(coRated)*100).rounded()) : nil`.
- `bothLoved` / `clashed` resolve entries by walking `history` (stable order); entries
  not in history are simply omitted from the lists (the counts/% are unaffected).
- Empty inputs → all zeros, `matchPercent == nil`, empty lists.

**Tested** in the existing `Daily MusicTests/TasteMirrorTests.swift` (add a
`TasteComparisonTests` struct in that already-registered file — avoids the
test-target pbxproj edit). Cases: exact %, below-`minShared` → nil, both-loved /
clashed partitioning, empty inputs.

## 5. Reusable render — `TasteMirrorBoard`

`Views/Components/TasteMirrorBoard.swift`. Extract the entire mirror visualization
currently private to `InsightsView` — the archetype hero, the 2×2 standout tiles
(Mood/Era/Theme/Energy), the Genre/Language rows, locked-tile states — into one
view:

```swift
struct TasteMirrorBoard: View {
    let mirror: TasteMirror
    var accent: Color
    // Owns its own tile-tap → StandoutDetailView sheet, so both screens get
    // tappable, read-only standout breakdowns for free.
}
```

`StandoutDetailView` + the `makeDetail`/tile-color helpers move with it (or become
reachable to it). After extraction:
- `InsightsView` becomes a thin wrapper: load state → `TasteMirrorBoard(mirror:accent:)`
  + its existing **"See your month" (Wrapped)** button and first-run rating nudge.
  **Its on-screen result must look identical** (verified by build + eyeball).
- `FriendInsightsView` reuses the same board, read-only (no Wrapped, no nudge).

## 6. Friend screen — `FriendInsightsView` + `FriendInsightsViewModel`

`ViewModels/FriendInsightsViewModel.swift`:
```swift
@MainActor @Observable final class FriendInsightsViewModel {
    private(set) var state: LoadState<(mirror: TasteMirror, comparison: TasteComparison)> = .loading
    // init(entries:ratings:friends:) ; load(friendID:)
    // load: history = publishedHistory; theirs = friendRatings(friendID); mine = myRatings
    //       mirror = TasteMirror.build(history ⨝ theirs); comparison = TasteComparison.build(mine, theirs, history)
}
```
Degrades like the others (`try?` per source → empty mirror / zeroed comparison, never an error wall).

`Views/Friends/FriendInsightsView.swift` — top to bottom:
1. **Header:** friend avatar + `displayName` ("Alex's taste").
2. **Taste-match card:** big `matchPercent%` ("78% match · you agree on 14 of 18 songs you both rated"), or "Not enough shared ratings yet" when `< minShared`; then a few **you both loved** rows and a couple **you clash on** rows (each capped ~3, tap → song detail).
3. **Their mirror:** `TasteMirrorBoard(mirror:accent:)`. Accent = their archetype color (same rule Insights uses), brand fallback.

## 7. Entry point

`FriendsView.friendsSection` — the friend row (which has the `// Phase C will push
the friend's insights here` marker) becomes a `NavigationLink(value: friend)`, with
`.navigationDestination(for: Friend.self) { FriendInsightsView(friend: $0) }` on the
list. (`Friend` is `Identifiable`; add `Hashable` if needed for the destination.)

## 8. Mock seeding

`MockFriendService` currently returns `[:]` for `friendRatings`. Seed "Alex" with a
spread of ratings against the mock catalog so the friend screen + comparison are
populated when exploring in the DEBUG mock environment.

## 9. Edge cases

- Friend with few/no ratings → mirror shows the normal progressive-reveal locked
  tiles; comparison shows "Not enough shared ratings yet."
- No songs in common → `coRatedCount == 0`, empty both-loved/clash lists, no %.
- Not actually accepted friends → the RPC returns no rows (server-enforced) → empty mirror.

## 10. Testing

`TasteComparison` unit tests (above) + full build + manual: open the Friends tab in
the mock env, tap Alex, confirm the match card + populated mirror render.

## 11. Files

| File | Change |
|------|--------|
| `Models/TasteComparison.swift` | NEW — pure comparison engine |
| `Views/Components/TasteMirrorBoard.swift` | NEW — extracted mirror render (+ owns StandoutDetail) |
| `ViewModels/FriendInsightsViewModel.swift` | NEW — builds friend mirror + comparison |
| `Views/Friends/FriendInsightsView.swift` | NEW — header + match card + board |
| `Views/InsightsView.swift` | EDIT — render via `TasteMirrorBoard` (look unchanged) |
| `Views/Friends/FriendsView.swift` | EDIT — `NavigationLink` → friend insights |
| `Services/FriendService.swift` | EDIT — seed mock Alex ratings |
| `Daily MusicTests/TasteMirrorTests.swift` | EDIT — add `TasteComparisonTests` |
| `Views/StandoutDetailView.swift` | EDIT (likely) — move/share with the board |
