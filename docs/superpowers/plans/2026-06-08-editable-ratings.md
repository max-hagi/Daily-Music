# Editable Ratings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static 👍/👎 emoji in `CategorySongsSheet` with interactive thumb buttons that save changes to the right backend (onboarding seed songs → UserDefaults, catalog songs → Supabase), and show a read-only rating badge on Vault list rows.

**Architecture:** `CategorySongsSheet` gains `@Environment(AppEnvironment.self)`, local optimistic state, and a `setRating` method that routes writes by `entry.date == .distantPast`. A `onRatingChanged` callback threads up through `StandoutDetailView` → `TasteMirrorBoard` → `InsightsView` to trigger a mirror reload. `VaultTintedEntryRow` loads rating state lazily via the existing `.task` pattern and shows a badge.

**Tech Stack:** SwiftUI, Swift Concurrency (async/await), UserDefaults (`SeedRatings`), `RatingService` (Supabase), Swift Testing (`@Test`)

---

## File Map

| File | Change |
|------|--------|
| `Daily Music/Views/Components/CategorySongsSheet.swift` | Full rewrite — interactive thumbs, local state, routing logic |
| `Daily Music/Views/StandoutDetailView.swift` | Add `onRatingChanged` param, thread to `CategorySongsSheet` |
| `Daily Music/Views/Components/TasteMirrorBoard.swift` | Add `onRatingChanged` param, thread to `StandoutDetailView` |
| `Daily Music/Views/InsightsView.swift` | Provide `onRatingChanged` closure to `TasteMirrorBoard` |
| `Daily Music/Views/VaultView.swift` | Load + display rating badge in `VaultTintedEntryRow` |
| `Daily MusicTests/TasteSeedTests.swift` | Add mutation tests for the seed rating update logic |

---

## Task 1: Test the seed mutation logic

The seed-update code in `setRating` performs three operations on a `[RatedSong]` array: replace an existing entry, insert a new one, or remove it. Test all three before writing any view code.

**Files:**
- Modify: `Daily MusicTests/TasteSeedTests.swift`

- [ ] **Step 1.1: Add three mutation tests to TasteSeedTests**

Open `Daily MusicTests/TasteSeedTests.swift` and add these three tests inside `struct TasteSeedTests`:

```swift
// Helper already exists in the file as `entry(mood:genre:year:)` — reuse it.

@Test func seedRatingsMutate_replaceExisting() {
    SeedRatings.clear()
    let e = entry(mood: "Dreamy", genre: "Alternative", year: 2015)
    SeedRatings.save([RatedSong(entry: e, value: 1)])

    // Simulate the view's "flip to dislike" path
    var seeds = SeedRatings.load()
    if let i = seeds.firstIndex(where: { $0.entry.id == e.id }) {
        seeds[i] = RatedSong(entry: e, value: -1)
    }
    SeedRatings.save(seeds)

    let result = SeedRatings.load()
    #expect(result.count == 1)
    #expect(result[0].value == -1)
    SeedRatings.clear()
}

@Test func seedRatingsMutate_removeOnClear() {
    SeedRatings.clear()
    let e = entry(mood: "Dreamy", genre: "Alternative", year: 2015)
    SeedRatings.save([RatedSong(entry: e, value: 1)])

    // Simulate the view's "tap active thumb → clear" path
    var seeds = SeedRatings.load()
    seeds.removeAll { $0.entry.id == e.id }
    SeedRatings.save(seeds)

    #expect(SeedRatings.load().isEmpty)
    SeedRatings.clear()
}

@Test func seedRatingsMutate_insertNew() {
    SeedRatings.clear()
    let e = entry(mood: "Dreamy", genre: "Alternative", year: 2015)

    // Simulate inserting a previously-unrated seed
    var seeds = SeedRatings.load()
    seeds.append(RatedSong(entry: e, value: 1))
    SeedRatings.save(seeds)

    let result = SeedRatings.load()
    #expect(result.count == 1)
    #expect(result[0].entry.id == e.id)
    SeedRatings.clear()
}
```

- [ ] **Step 1.2: Run the new tests to confirm they pass**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  -only-testing "Daily MusicTests/TasteSeedTests" \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  2>&1 | grep -E "(PASS|FAIL|error:|Test Suite)"
```

Expected: all three new tests pass alongside the existing four.

- [ ] **Step 1.3: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily MusicTests/TasteSeedTests.swift"
git commit -m "test(insights): seed rating mutation — replace, remove, insert"
```

---

## Task 2: Rewrite `CategorySongsSheet` with interactive thumbs

Replace the static emoji with Liquid Glass thumb buttons. Route writes through `setRating` based on `entry.date == .distantPast`.

**Files:**
- Modify: `Daily Music/Views/Components/CategorySongsSheet.swift`

- [ ] **Step 2.1: Replace the entire file contents**

```swift
//
//  CategorySongsSheet.swift
//  Daily Music
//
//  Bottom sheet listing the rated songs that belong to one insight category.
//  Liked songs appear first, then disliked, both reverse-chronological within
//  their group. Each row has inline 👍/👎 buttons to re-rate in place.
//
//  Routing: seed songs (entry.date == .distantPast, from the onboarding
//  StarterPack) write to SeedRatings (UserDefaults); catalog songs write to
//  RatingService (Supabase). After any write, fires onRatingChanged so
//  InsightsViewModel can reload the mirror.
//

import SwiftUI

struct CategorySongsSheet: View {
    let title: String
    let songs: [RatedSong]
    var onRatingChanged: (() -> Void)? = nil

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    // Tracks in-flight optimistic overrides; keyed by entry id.
    @State private var localRatings: [UUID: Int?] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty {
                    ContentUnavailableView(
                        "No songs yet",
                        systemImage: "music.note.list",
                        description: Text("Rate more songs in this category to see them here.")
                    )
                } else {
                    List(songs, id: \.entry.id) { rated in
                        songRow(rated)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.regularMaterial)
        .presentationCornerRadius(34)
        .presentationDragIndicator(.visible)
        .onAppear {
            localRatings = Dictionary(uniqueKeysWithValues: songs.map { ($0.entry.id, $0.value) })
        }
    }

    // MARK: row

    private func songRow(_ rated: RatedSong) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            AlbumArtView(url: rated.entry.albumArtURL, cornerRadius: 8)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(rated.entry.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(rated.entry.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            ratingButtons(rated)
        }
        .padding(.vertical, 4)
    }

    private func ratingButtons(_ rated: RatedSong) -> some View {
        let current = localRatings[rated.entry.id] ?? rated.value
        return HStack(spacing: 6) {
            thumbButton(value: 1,  symbol: "hand.thumbsup.fill",   tint: .green,
                        isActive: current == 1,  rated: rated)
            thumbButton(value: -1, symbol: "hand.thumbsdown.fill", tint: .red,
                        isActive: current == -1, rated: rated)
        }
    }

    private func thumbButton(value: Int, symbol: String, tint: Color,
                              isActive: Bool, rated: RatedSong) -> some View {
        Button {
            Haptics.tap()
            setRating(isActive ? nil : value, for: rated)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isActive ? .white : tint)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isActive ? .clear.tint(tint).interactive() : .clear.interactive(),
            in: .circle
        )
        .accessibilityLabel(value > 0
            ? (isActive ? "Remove like" : "Like")
            : (isActive ? "Remove dislike" : "Dislike"))
    }

    // MARK: write

    private func setRating(_ newValue: Int?, for rated: RatedSong) {
        localRatings[rated.entry.id] = newValue   // optimistic

        Task {
            if rated.entry.date == .distantPast {
                // Onboarding seed song — persisted in UserDefaults, not Supabase.
                var seeds = SeedRatings.load()
                if let newValue {
                    if let i = seeds.firstIndex(where: { $0.entry.id == rated.entry.id }) {
                        seeds[i] = RatedSong(entry: rated.entry, value: newValue)
                    } else {
                        seeds.append(RatedSong(entry: rated.entry, value: newValue))
                    }
                } else {
                    seeds.removeAll { $0.entry.id == rated.entry.id }
                }
                SeedRatings.save(seeds)
            } else {
                // Catalog song — write to Supabase song_ratings.
                try? await env.ratings.setRating(newValue, entryID: rated.entry.id)
            }
            onRatingChanged?()
        }
    }
}
```

- [ ] **Step 2.2: Build to confirm no compile errors**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
xcodebuild build \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  2>&1 | grep -E "(error:|warning:|BUILD)"
```

Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 2.3: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Views/Components/CategorySongsSheet.swift"
git commit -m "feat(insights): interactive rating thumbs in CategorySongsSheet"
```

---

## Task 3: Thread `onRatingChanged` through `StandoutDetailView`

`StandoutDetailView` creates `CategorySongsSheet` — it needs to forward the callback.

**Files:**
- Modify: `Daily Music/Views/StandoutDetailView.swift`

- [ ] **Step 3.1: Add `onRatingChanged` parameter to `StandoutDetailView`**

In `StandoutDetailView.swift`, find the struct declaration and add the new stored property right after `let detail: StandoutDetail`:

```swift
struct StandoutDetailView: View {
    let detail: StandoutDetail
    var onRatingChanged: (() -> Void)? = nil      // ← add this line
    @Environment(\.dismiss) private var dismiss
    @State private var drill: CategoryDrill?
```

- [ ] **Step 3.2: Forward the callback to `CategorySongsSheet`**

Find the `.sheet(item: $drill)` at the bottom of `body` and update it:

```swift
        .sheet(item: $drill) { d in
            CategorySongsSheet(title: d.name, songs: d.songs, onRatingChanged: onRatingChanged)
        }
```

(The old line was `CategorySongsSheet(title: d.name, songs: d.songs)` — add `, onRatingChanged: onRatingChanged`.)

- [ ] **Step 3.3: Build**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
xcodebuild build \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3.4: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Views/StandoutDetailView.swift"
git commit -m "feat(insights): thread onRatingChanged through StandoutDetailView"
```

---

## Task 4: Thread `onRatingChanged` through `TasteMirrorBoard`

`TasteMirrorBoard` creates `StandoutDetailView` — it needs to forward the callback.

**Files:**
- Modify: `Daily Music/Views/Components/TasteMirrorBoard.swift`

- [ ] **Step 4.1: Add `onRatingChanged` parameter to `TasteMirrorBoard`**

Find the struct declaration and add the property after `var displayArchetype`:

```swift
struct TasteMirrorBoard: View {
    let mirror: TasteMirror
    var isCurrentUser: Bool = true
    var displayArchetype: TasteProfile? = nil
    var onRatingChanged: (() -> Void)? = nil      // ← add this line
    @State private var detail: StandoutDetail?
```

- [ ] **Step 4.2: Forward the callback to `StandoutDetailView`**

Find `.sheet(item: $detail)` in `body` and update it:

```swift
        .sheet(item: $detail) { StandoutDetailView(detail: $0, onRatingChanged: onRatingChanged) }
```

(The old line was `StandoutDetailView(detail: $0)` — add `, onRatingChanged: onRatingChanged`.)

- [ ] **Step 4.3: Build**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
xcodebuild build \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4.4: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Views/Components/TasteMirrorBoard.swift"
git commit -m "feat(insights): thread onRatingChanged through TasteMirrorBoard"
```

---

## Task 5: Wire the callback in `InsightsView`

`InsightsView` owns the `InsightsViewModel` and is the right place to provide the reload closure.

**Files:**
- Modify: `Daily Music/Views/InsightsView.swift`

- [ ] **Step 5.1: Pass `onRatingChanged` to `TasteMirrorBoard`**

In `InsightsView.swift`, find the `content(_:)` function. It currently reads:

```swift
TasteMirrorBoard(mirror: mirror, displayArchetype: model?.stableArchetype)
```

Replace that line with:

```swift
TasteMirrorBoard(
    mirror: mirror,
    displayArchetype: model?.stableArchetype,
    onRatingChanged: { Task { await model?.load() } }
)
```

(`model` is the `@State private var model: InsightsViewModel?` already in scope.)

- [ ] **Step 5.2: Build**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
xcodebuild build \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5.3: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Views/InsightsView.swift"
git commit -m "feat(insights): reload mirror on rating change from CategorySongsSheet"
```

---

## Task 6: Rating badge on `VaultTintedEntryRow`

`VaultTintedEntryRow` already loads artwork via `.task(id: entry.id)`. Add a parallel rating load and a small badge in the trailing area.

**Files:**
- Modify: `Daily Music/Views/VaultView.swift`

- [ ] **Step 6.1: Add `@Environment` and rating state to `VaultTintedEntryRow`**

`VaultTintedEntryRow` is a `private struct` at the bottom of `VaultView.swift`. Find its declaration:

```swift
private struct VaultTintedEntryRow: View {
    let entry: DailyEntry
    var eyebrow: String?

    @State private var palette = ArtworkPalette()
```

Add the new properties right after `@State private var palette`:

```swift
private struct VaultTintedEntryRow: View {
    let entry: DailyEntry
    var eyebrow: String?

    @Environment(AppEnvironment.self) private var env
    @State private var palette = ArtworkPalette()
    @State private var myRating: Int? = nil
```

- [ ] **Step 6.2: Add rating load to the `.task` modifier**

Find the existing `.task` at the bottom of `VaultTintedEntryRow.body`:

```swift
        .task(id: entry.id) { await palette.load(from: entry.albumArtURL) }
```

Replace it with two tasks (one for palette, one for rating):

```swift
        .task(id: entry.id) { await palette.load(from: entry.albumArtURL) }
        .task(id: entry.id) { myRating = try? await env.ratings.myRating(entryID: entry.id) }
```

- [ ] **Step 6.3: Add the rating badge to the trailing HStack**

Inside `VaultTintedEntryRow.body`, find the `HStack` that contains `Spacer()` and the chevron:

```swift
            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent.opacity(0.72))
```

Add the badge between `Spacer()` and the chevron:

```swift
            Spacer()

            if let r = myRating {
                Text(r > 0 ? "👍" : "👎")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent.opacity(0.72))
```

- [ ] **Step 6.4: Build**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
xcodebuild build \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6.5: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Views/VaultView.swift"
git commit -m "feat(vault): show rating badge on VaultTintedEntryRow"
```

---

## Task 7: Manual integration smoke test

Run the simulator and walk through the critical paths before wrapping up.

**Files:** none — verification only.

- [ ] **Step 7.1: Launch in simulator**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
xcodebuild build \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  2>&1 | grep -E "(error:|BUILD)"
```

Then open the app in the iOS Simulator.

- [ ] **Step 7.2: Verify seed song re-rating**

1. Go to **Insights** tab.
2. Tap any unlocked tile (Mood, Theme, etc.).
3. Tap the featured category → `CategorySongsSheet` opens.
4. Find a song with `date` in the distant past (these are the 10 StarterPack songs — recognizable names like "Dancing Queen", "Levitating", etc.).
5. Tap the inactive thumb — verify it fills with color, the active thumb clears.
6. Dismiss all sheets. Confirm Insights reloads (loading indicator may flash briefly).
7. Re-open the same drill-down — confirm the new rating persists.

- [ ] **Step 7.3: Verify catalog song re-rating**

1. Find a catalog song (any song not from StarterPack) in the `CategorySongsSheet`.
2. Tap the inactive thumb — verify optimistic update.
3. Dismiss. Confirm Insights updates.
4. Re-open the sheet — rating should match what you set.

- [ ] **Step 7.4: Verify tap-to-clear**

1. Tap the currently active thumb on any song — it should clear (both thumbs now unselected).
2. Dismiss and re-open — song should show neither thumb active.

- [ ] **Step 7.5: Verify Vault badge**

1. Go to **Vault** tab.
2. Scroll to "Recent picks" — any entry you've previously rated should show 👍 or 👎 in the trailing area.
3. Unrated entries show no badge.

- [ ] **Step 7.6: Verify FriendInsightsView is still read-only**

1. Open a friend's profile → their Insights.
2. Tap a tile — `StandoutDetailView` opens (no `onRatingChanged` passed since `isCurrentUser: false` prevents tile taps from creating a `CategoryDrill`).
3. Confirm no thumbs appear in the friend's song rows — their mirror is still read-only.

   *(Note: the friend drill-down uses the same `TasteMirrorBoard` with `isCurrentUser: false`, which already prevents tile taps from opening drill-downs at all — no `CategorySongsSheet` is presented for friends, so this is structurally safe.)*

- [ ] **Step 7.7: Final commit if any polish fixes were needed**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
# Only if you made any small fixes during testing:
git add -p
git commit -m "fix(ratings): polish from smoke test"
```

---

## Summary of commits

| # | Message |
|---|---------|
| 1 | `test(insights): seed rating mutation — replace, remove, insert` |
| 2 | `feat(insights): interactive rating thumbs in CategorySongsSheet` |
| 3 | `feat(insights): thread onRatingChanged through StandoutDetailView` |
| 4 | `feat(insights): thread onRatingChanged through TasteMirrorBoard` |
| 5 | `feat(insights): reload mirror on rating change from CategorySongsSheet` |
| 6 | `feat(vault): show rating badge on VaultTintedEntryRow` |
| 7 | *(optional polish)* |
