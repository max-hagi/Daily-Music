# Favorites Collection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Favorites tab into a real collection — record/sleeve treatment per song, drag-to-rearrange with a persisted manual order, plus search and genre/decade/mood filtering.

**Architecture:** Two new pure, unit-tested value types carry the logic: `FavoritesOrderStore` (local UserDefaults manual order) and `FavoritesFilter` (search + facet predicate). `FavoritesView` is rewritten to render sleeves via the existing `SleeveView`, narrow the list through the filter, and enter a long-press "rearrange mode" where shelf ledges fade, records jiggle, and a drag-and-drop delegate reshuffles the order live.

**Tech Stack:** SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`), UserDefaults, `UniformTypeIdentifiers` (drag/drop).

**Spec:** `docs/superpowers/specs/2026-06-15-favorites-collection-design.md`

---

## File Structure

- **Create** `Daily Music/ViewModels/FavoritesOrderStore.swift` — local manual-order store (pure `arranged` + `commit`).
- **Create** `Daily Music/Models/FavoritesFilter.swift` — `FavoritesFilter` predicate + `favoritesFacets(in:)`.
- **Create** `Daily Music/Views/Components/FavoritesCollectionSupport.swift` — `Jiggle` modifier, `FavoriteReorderDelegate`, `FavoritesFilterSheet`.
- **Create** `Daily MusicTests/FavoritesOrderStoreTests.swift` — order store tests.
- **Create** `Daily MusicTests/FavoritesFilterTests.swift` — filter tests.
- **Modify** `Daily Music/Views/FavoritesView.swift` — rewrite the `FavoritesView` struct (lines 12–228) for sleeves, order, search, filter, rearrange. The three private detail structs below it (`FavoriteEntryPeek`, `FavoriteEntryDetail`) are unchanged.

**Project conventions (from build-command memory):**
- App target (`Daily Music/`) is filesystem-synchronized — new source files auto-compile.
- Test target (`Daily MusicTests/`) is **not** synchronized — each new test file must be added to the `Daily MusicTests` target in Xcode so `project.pbxproj` updates, or it won't compile/run.
- Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`
- Test: same with `test` and `-only-testing:"Daily MusicTests/<Suite>"`.

---

## Task 1: `FavoritesOrderStore`

**Files:**
- Create: `Daily Music/ViewModels/FavoritesOrderStore.swift`
- Test: `Daily MusicTests/FavoritesOrderStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Daily MusicTests/FavoritesOrderStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct FavoritesOrderStoreTests {
    /// A throwaway UserDefaults suite so tests never touch real storage or each other.
    static func freshDefaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    static func entry(_ i: Int) -> DailyEntry {
        DailyEntry(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i))!,
            date: Date(timeIntervalSince1970: TimeInterval(i) * 86_400),
            title: "T\(i)", artist: "A\(i)",
            albumArtURL: nil, journalMarkdown: "",
            appleMusicID: "\(i)", spotifyURI: "spotify:track:\(i)"
        )
    }

    @Test func noSavedOrderReturnsInputUnchanged() {
        let store = FavoritesOrderStore(defaults: Self.freshDefaults())
        let favs = [Self.entry(3), Self.entry(2), Self.entry(1)]
        #expect(store.arranged(favs).map(\.id) == favs.map(\.id))
    }

    @Test func savedOrderIsRespected() {
        let store = FavoritesOrderStore(defaults: Self.freshDefaults())
        let a = Self.entry(1), b = Self.entry(2), c = Self.entry(3)
        store.commit([c.id, a.id, b.id])
        #expect(store.arranged([a, b, c]).map(\.id) == [c.id, a.id, b.id])
    }

    @Test func newFavoriteAppearsOnTop() {
        let store = FavoritesOrderStore(defaults: Self.freshDefaults())
        let a = Self.entry(1), b = Self.entry(2)
        store.commit([a.id, b.id])
        let c = Self.entry(3) // newly hearted, not in saved order
        #expect(store.arranged([c, a, b]).map(\.id) == [c.id, a.id, b.id])
    }

    @Test func removedFavoriteIsDropped() {
        let store = FavoritesOrderStore(defaults: Self.freshDefaults())
        let a = Self.entry(1), b = Self.entry(2), c = Self.entry(3)
        store.commit([a.id, b.id, c.id])
        #expect(store.arranged([a, c]).map(\.id) == [a.id, c.id]) // b un-hearted
    }

    @Test func commitPersistsAcrossInstances() {
        let defaults = Self.freshDefaults()
        let a = Self.entry(1), b = Self.entry(2)
        FavoritesOrderStore(defaults: defaults).commit([b.id, a.id])
        let reloaded = FavoritesOrderStore(defaults: defaults)
        #expect(reloaded.arranged([a, b]).map(\.id) == [b.id, a.id])
    }
}
```

Then add this file to the `Daily MusicTests` target in Xcode (File inspector → Target Membership) so `project.pbxproj` picks it up.

- [ ] **Step 2: Run the test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/FavoritesOrderStoreTests"`
Expected: FAIL — compile error, `cannot find 'FavoritesOrderStore' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Daily Music/ViewModels/FavoritesOrderStore.swift`:

```swift
//
//  FavoritesOrderStore.swift
//  Daily Music
//
//  Local-only manual ordering for the Favorites collection. Until the user drags
//  to reorder, there is no saved order and favorites render in the order given
//  (newest-first). After the first reorder we persist an explicit id list to
//  UserDefaults; newly hearted songs prepend on top, un-hearted ones drop out.
//

import Foundation

@MainActor
@Observable
final class FavoritesOrderStore {
    private let defaults: UserDefaults
    private let key = "favorites.manual_order.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The saved manual order, or nil if the user hasn't reordered yet.
    private var savedOrder: [UUID]? {
        guard let strings = defaults.array(forKey: key) as? [String] else { return nil }
        return strings.compactMap(UUID.init(uuidString:))
    }

    /// Pure. No saved order → `favorites` unchanged. Otherwise: favorites present
    /// in the saved list follow its order; favorites NOT in it (newly hearted)
    /// prepend on top in their incoming order; saved ids absent from `favorites`
    /// are dropped.
    func arranged(_ favorites: [DailyEntry]) -> [DailyEntry] {
        guard let order = savedOrder else { return favorites }
        let position = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
        let known = favorites
            .filter { position[$0.id] != nil }
            .sorted { position[$0.id]! < position[$1.id]! }
        let fresh = favorites.filter { position[$0.id] == nil }
        return fresh + known
    }

    /// Persist an explicit manual order. Stores exactly `ids`, so passing the live
    /// arranged ids both establishes the order and trims any stale ids.
    func commit(_ ids: [UUID]) {
        defaults.set(ids.map(\.uuidString), forKey: key)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/FavoritesOrderStoreTests"`
Expected: PASS — all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/ViewModels/FavoritesOrderStore.swift" "Daily MusicTests/FavoritesOrderStoreTests.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "feat(favorites): add FavoritesOrderStore for local manual order"
```

---

## Task 2: `FavoritesFilter`

**Files:**
- Create: `Daily Music/Models/FavoritesFilter.swift`
- Test: `Daily MusicTests/FavoritesFilterTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Daily MusicTests/FavoritesFilterTests.swift`:

```swift
import Testing
import Foundation
@testable import Daily_Music

struct FavoritesFilterTests {
    static func entry(_ i: Int, title: String = "", artist: String = "",
                      genre: String? = nil, year: Int? = nil, mood: String? = nil) -> DailyEntry {
        DailyEntry(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i))!,
            date: Date(timeIntervalSince1970: TimeInterval(i) * 86_400),
            title: title.isEmpty ? "T\(i)" : title,
            artist: artist.isEmpty ? "A\(i)" : artist,
            albumArtURL: nil, journalMarkdown: "",
            appleMusicID: "\(i)", spotifyURI: "spotify:track:\(i)",
            genre: genre, year: year, mood: mood
        )
    }

    @Test func emptyFilterMatchesEverythingAndIsInactive() {
        let f = FavoritesFilter()
        #expect(f.isActive == false)
        #expect(f.hasFacetFilters == false)
        #expect(f.matches(Self.entry(1)) == true)
    }

    @Test func queryMatchesTitleOrArtistCaseInsensitively() {
        var f = FavoritesFilter(); f.query = "BLON"
        #expect(f.matches(Self.entry(1, title: "Blonde", artist: "X")) == true)
        var g = FavoritesFilter(); g.query = "drake"
        #expect(g.matches(Self.entry(2, title: "Y", artist: "Drake")) == true)
        #expect(g.matches(Self.entry(3, title: "Y", artist: "Z")) == false)
    }

    @Test func singleDimensionConstrainsAndNilIsExcluded() {
        var f = FavoritesFilter(); f.genres = ["Pop"]
        #expect(f.matches(Self.entry(1, genre: "Pop")) == true)
        #expect(f.matches(Self.entry(2, genre: "Rock")) == false)
        #expect(f.matches(Self.entry(3, genre: nil)) == false)
    }

    @Test func dimensionsAndTogetherValuesOrWithin() {
        var f = FavoritesFilter()
        f.genres = ["Pop", "Rock"]
        f.decades = ["1980s"]
        #expect(f.matches(Self.entry(1, genre: "Pop", year: 1985)) == true)
        #expect(f.matches(Self.entry(2, genre: "Rock", year: 1985)) == true)
        #expect(f.matches(Self.entry(3, genre: "Pop", year: 1995)) == false) // decade fails
        #expect(f.matches(Self.entry(4, genre: "Jazz", year: 1985)) == false) // genre fails
    }

    @Test func facetsAreDistinctNonEmptySorted() {
        let favs = [
            Self.entry(1, genre: "Pop", year: 1985, mood: "Dreamy"),
            Self.entry(2, genre: "Pop", year: 1995, mood: nil),
            Self.entry(3, genre: "Rock", year: nil, mood: "Dreamy"),
        ]
        let facets = favoritesFacets(in: favs)
        #expect(facets.genres == ["Pop", "Rock"])
        #expect(facets.decades == ["1980s", "1990s"])
        #expect(facets.moods == ["Dreamy"])
    }
}
```

Add this file to the `Daily MusicTests` target in Xcode.

- [ ] **Step 2: Run the test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/FavoritesFilterTests"`
Expected: FAIL — `cannot find 'FavoritesFilter' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Daily Music/Models/FavoritesFilter.swift`:

```swift
//
//  FavoritesFilter.swift
//  Daily Music
//
//  Pure search + facet narrowing for the Favorites collection. `query` is free
//  text over title + artist; `genres`/`decades`/`moods` are OR within a dimension
//  and AND across dimensions. A nil entry value never matches a constrained
//  dimension.
//

import Foundation

struct FavoritesFilter: Equatable {
    var query: String = ""
    var genres: Set<String> = []
    var decades: Set<String> = []
    var moods: Set<String> = []

    /// True when the facet menu has any selection (drives the toolbar icon's filled state).
    var hasFacetFilters: Bool {
        !genres.isEmpty || !decades.isEmpty || !moods.isEmpty
    }

    /// True when anything (search or facets) is narrowing the list.
    var isActive: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty || hasFacetFilters
    }

    func matches(_ entry: DailyEntry) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            let hay = "\(entry.title) \(entry.artist)".lowercased()
            if !hay.contains(q) { return false }
        }
        if !genres.isEmpty { guard let g = entry.genre, genres.contains(g) else { return false } }
        if !decades.isEmpty { guard let d = entry.decade, decades.contains(d) else { return false } }
        if !moods.isEmpty { guard let m = entry.mood, moods.contains(m) else { return false } }
        return true
    }
}

/// Distinct, non-empty, sorted facet values present in `favorites` — used to build
/// the filter sheet so it only offers values that actually exist.
func favoritesFacets(in favorites: [DailyEntry])
    -> (genres: [String], decades: [String], moods: [String]) {
    func distinct(_ values: [String?]) -> [String] {
        Array(Set(values.compactMap { $0 }.filter { !$0.isEmpty })).sorted()
    }
    return (
        genres: distinct(favorites.map(\.genre)),
        decades: distinct(favorites.map(\.decade)),
        moods: distinct(favorites.map(\.mood))
    )
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/FavoritesFilterTests"`
Expected: PASS — all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/FavoritesFilter.swift" "Daily MusicTests/FavoritesFilterTests.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "feat(favorites): add FavoritesFilter search + facet predicate"
```

---

## Task 3: Collection support views (jiggle, reorder delegate, filter sheet)

These are presentational pieces with no unit tests; verify by compiling. They depend on `FavoritesFilter` (Task 2) and `DailyEntry`.

**Files:**
- Create: `Daily Music/Views/Components/FavoritesCollectionSupport.swift`

- [ ] **Step 1: Write the implementation**

Create `Daily Music/Views/Components/FavoritesCollectionSupport.swift`:

```swift
//
//  FavoritesCollectionSupport.swift
//  Daily Music
//
//  Helpers for the Favorites collection: the rearrange-mode jiggle, the
//  drag-and-drop reorder delegate, and the genre/decade/mood filter sheet.
//

import SwiftUI
import UniformTypeIdentifiers

/// A gentle continuous wobble used to signal "rearrange mode" (like the iOS home
/// screen). `seed` phase-offsets each record so the wall doesn't wobble in sync.
struct Jiggle: ViewModifier {
    let active: Bool
    let seed: Int
    @State private var wobble = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? (wobble ? 1.3 : -1.3) : 0))
            .animation(
                active
                    ? .easeInOut(duration: 0.13 + Double(abs(seed) % 5) * 0.01).repeatForever(autoreverses: true)
                    : .default,
                value: wobble
            )
            .onAppear { wobble = active }
            .onChange(of: active) { _, now in wobble = now }
    }
}

/// Live drag-to-reorder for the favorites wall. As the dragged record hovers over
/// another, the two swap immediately so the wall reshuffles under the finger; the
/// new order is committed on drop.
struct FavoriteReorderDelegate: DropDelegate {
    let item: DailyEntry
    @Binding var items: [DailyEntry]
    @Binding var dragging: DailyEntry?
    let onCommit: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != item,
              let from = items.firstIndex(of: dragging),
              let to = items.firstIndex(of: item) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            items.move(fromOffsets: IndexSet(integer: from),
                       toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        onCommit()
        return true
    }
}

/// Sheet of genre/decade/mood facets. Only dimensions with values are shown.
struct FavoritesFilterSheet: View {
    @Binding var filter: FavoritesFilter
    let facets: (genres: [String], decades: [String], moods: [String])
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                section("Genre", values: facets.genres, keyPath: \.genres)
                section("Decade", values: facets.decades, keyPath: \.decades)
                section("Mood", values: facets.moods, keyPath: \.moods)
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        filter.genres = []; filter.decades = []; filter.moods = []
                    }
                    .disabled(!filter.hasFacetFilters)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, values: [String],
                         keyPath: WritableKeyPath<FavoritesFilter, Set<String>>) -> some View {
        if !values.isEmpty {
            Section(title) {
                ForEach(values, id: \.self) { value in
                    Button {
                        if filter[keyPath: keyPath].contains(value) {
                            filter[keyPath: keyPath].remove(value)
                        } else {
                            filter[keyPath: keyPath].insert(value)
                        }
                    } label: {
                        HStack {
                            Text(value).foregroundStyle(.primary)
                            Spacer()
                            if filter[keyPath: keyPath].contains(value) {
                                Image(systemName: "checkmark").foregroundStyle(.pink)
                            }
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Components/FavoritesCollectionSupport.swift"
git commit -m "feat(favorites): add jiggle, reorder delegate, filter sheet"
```

---

## Task 4: Rewrite `FavoritesView` (sleeves + order + search + filter + rearrange)

Wire everything together: render `SleeveView`s, drive display order through `FavoritesOrderStore`, narrow with `FavoritesFilter`, and add long-press rearrange mode.

**Files:**
- Modify: `Daily Music/Views/FavoritesView.swift` (replace the `FavoritesView` struct, lines 12–228; leave `FavoriteEntryPeek` and `FavoriteEntryDetail` untouched)

- [ ] **Step 1: Replace the import and the `FavoritesView` struct**

At the top of the file, change `import SwiftUI` to:

```swift
import SwiftUI
import UniformTypeIdentifiers
```

Then replace the entire `struct FavoritesView: View { ... }` (lines 12–228) with:

```swift
struct FavoritesView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: FavoritesViewModel?
    @State private var selectedEntry: DailyEntry?
    @State private var recentlyRemoved: DailyEntry?

    // Collection state
    @State private var orderStore = FavoritesOrderStore()
    @State private var arranged: [DailyEntry] = []   // ordered, pre-filter
    @State private var filter = FavoritesFilter()
    @State private var isRearranging = false
    @State private var showingFilterSheet = false
    @State private var draggingEntry: DailyEntry?

    /// The list actually shown: manual order, then narrowed by search/filter.
    private var displayed: [DailyEntry] { arranged.filter(filter.matches) }

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    switch model.state {
                    case .loaded:  loadedContent
                    case .empty:   emptyState
                    case .failed:  failedState
                    case .loading: loadingState
                    }
                } else {
                    loadingState
                }
            }
            .navigationTitle("Favorites")
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $filter.query, prompt: "Search favorites")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingFilterSheet) {
                FavoritesFilterSheet(filter: $filter, facets: favoritesFacets(in: arranged))
                    .presentationDetents([.medium, .large])
            }
            .overlay(alignment: .bottom) {
                if recentlyRemoved != nil {
                    UndoBanner(message: "Removed from favorites") { undoRemove() }
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: recentlyRemoved)
            .task(id: recentlyRemoved) {
                guard recentlyRemoved != nil else { return }
                try? await Task.sleep(for: .seconds(4))
                recentlyRemoved = nil
            }
        }
        // Re-runs whenever the favorites SET changes (hearting/un-hearting anywhere).
        .task(id: env.favoritesStore.ids) {
            if model == nil { model = FavoritesViewModel(entries: env.entries) }
            await model?.load(favoriteIDs: env.favoritesStore.ids)
            if case .loaded(let entries) = model?.state {
                arranged = orderStore.arranged(entries)
            }
        }
        .fullScreenCover(item: $selectedEntry) { entry in
            FavoriteEntryDetail(entry: entry) { selectedEntry = nil }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isRearranging {
                Button("Done") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { isRearranging = false }
                }
                .fontWeight(.semibold)
            } else {
                Button { showingFilterSheet = true } label: {
                    Image(systemName: filter.hasFacetFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filter")
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: Theme.Surface.favoritesBackground,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var loadingState: some View {
        MusicLoadingView(title: nil, tint: .pink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
    }

    // .loaded can briefly hold entries before `arranged` syncs in the task; while
    // not narrowing, an empty `displayed` means that one-frame gap → show loading.
    @ViewBuilder
    private var loadedContent: some View {
        if displayed.isEmpty {
            if filter.isActive { noMatchesState } else { loadingState }
        } else {
            wall
        }
    }

    private var wall: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header(count: arranged.count)
                    .padding(.horizontal, Theme.Spacing.md)
                ForEach(shelfRows(displayed), id: \.self) { row in
                    shelf(row)
                }
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .scrollContentBackground(.hidden)
        .background(background)
        .refreshable {
            await env.favoritesStore.load()
            Haptics.tap()
        }
    }

    // Chunk the wall into rows of three records.
    private func shelfRows(_ entries: [DailyEntry]) -> [[DailyEntry]] {
        stride(from: 0, to: entries.count, by: 3).map {
            Array(entries[$0 ..< min($0 + 3, entries.count)])
        }
    }

    private func shelf(_ row: [DailyEntry]) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
                ForEach(row) { entry in recordCell(entry) }
                ForEach(0 ..< (3 - row.count), id: \.self) { _ in
                    Spacer().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            // The shelf ledge — fades while rearranging so records "lift off".
            Rectangle()
                .fill(.primary.opacity(0.12))
                .frame(height: 2)
                .padding(.horizontal, Theme.Spacing.sm)
                .opacity(isRearranging ? 0 : 1)
        }
    }

    private func recordCell(_ entry: DailyEntry) -> some View {
        let cell = VStack(spacing: 6) {
            SleeveView(entry: entry,
                       status: env.listensStore.status(for: entry),
                       size: 104,
                       missingVariant: env.variants.missingSleeve,
                       secondhandVariant: env.variants.secondhand)
            VStack(spacing: 1) {
                Text(entry.title).font(.caption.weight(.semibold)).lineLimit(1)
                Text(entry.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .modifier(Jiggle(active: isRearranging, seed: entry.id.hashValue))

        return Group {
            if isRearranging {
                cell
                    .opacity(draggingEntry == entry ? 0 : 1)
                    .onDrag {
                        draggingEntry = entry
                        return NSItemProvider(object: entry.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: FavoriteReorderDelegate(
                        item: entry,
                        items: $arranged,
                        dragging: $draggingEntry,
                        onCommit: { orderStore.commit(arranged.map(\.id)) }
                    ))
            } else {
                Button { selectedEntry = entry } label: { cell }
                    .buttonStyle(.plain)
                    .onLongPressGesture(minimumDuration: 0.4) {
                        guard arranged.count >= 2, !filter.isActive else { return }
                        Haptics.tap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isRearranging = true
                        }
                    }
                    .contextMenu {
                        Button { selectedEntry = entry } label: {
                            Label("Open Entry", systemImage: "arrow.up.forward.app")
                        }
                        Button(role: .destructive) { removeFavorite(entry) } label: {
                            Label("Remove Favorite", systemImage: "heart.slash.fill")
                        }
                    } preview: {
                        FavoriteEntryPeek(entry: entry)
                    }
            }
        }
    }

    private func header(count: Int) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "heart.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.pink)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) \(count == 1 ? "favorite" : "favorites")")
                    .font(.dmTitle())
                Text("The songs that stopped you in your tracks.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .glassCardStyle(tint: .pink.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "heart.slash")
                .font(.system(size: 56))
                .foregroundStyle(.pink.opacity(0.7))
            VStack(spacing: Theme.Spacing.sm) {
                Text("No favorites yet")
                    .font(.dmTitle())
                Text("Tap the heart on any song to save it to your collection.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }

    private var noMatchesState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.pink.opacity(0.7))
            VStack(spacing: Theme.Spacing.sm) {
                Text("No matches")
                    .font(.dmTitle())
                Text("No favorites match your search or filters.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Clear filters") {
                withAnimation { filter = FavoritesFilter() }
            }
            .buttonStyle(.bordered)
            .tint(.pink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }

    private var failedState: some View {
        ContentUnavailableView {
            Label("Couldn't load favorites", systemImage: "exclamationmark.triangle")
        } actions: {
            Button("Retry") {
                Task { await model?.load(favoriteIDs: env.favoritesStore.ids) }
            }
            .buttonStyle(.bordered)
            .tint(.pink)
        }
        .background(background)
    }

    // MARK: - Remove + undo

    private func removeFavorite(_ entry: DailyEntry) {
        Haptics.thud()
        model?.remove(id: entry.id)
        arranged.removeAll { $0.id == entry.id }
        recentlyRemoved = entry
        Task { await env.favoritesStore.toggle(entry) }
    }

    private func undoRemove() {
        guard let entry = recentlyRemoved else { return }
        Haptics.tap()
        recentlyRemoved = nil
        Task { await env.favoritesStore.toggle(entry) }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run the full test suite to confirm no regressions**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: PASS (including the two new suites from Tasks 1–2).

- [ ] **Step 4: Manual verification (simulator or device)**

Confirm each, in order:
- Favorites render as record sleeves with their condition treatment (mint/secondhand/salvaged/missing), matching how the same songs look in the Vault.
- Search narrows by title/artist; the filter button opens the sheet; selecting genre/decade/mood narrows the wall; the button icon fills when facets are active; "Clear filters" / no-matches state work.
- Long-press a record (with ≥2 favorites, no active filter) → ledges fade, records jiggle, **Done** appears. Long-press does nothing while a search/filter is active.
- Drag a record over another → the wall reshuffles live; release drops it there; **Done** exits and the new order sticks.
- Relaunch the app → the manual order persists; heart a new song → it appears on top; un-heart one → it drops out.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/FavoritesView.swift"
git commit -m "feat(favorites): collection wall — sleeves, manual reorder, search, filter"
```

---

## Self-Review Notes

- **Spec coverage:** sleeve swap (Task 4 `recordCell`), condition via listen status (Task 4), local order store (Task 1), newest-first default + new-on-top + drop-removed (Task 1 + Task 4 `arranged`/`removeFavorite`), long-press rearrange with lift/jiggle/drag (Tasks 3–4), Done/background exit (Task 4 toolbar), search + genre/decade/mood filter (Tasks 2–4), rearrange disabled while narrowing (Task 4 `onLongPressGesture` guard), no-matches state (Task 4). All covered.
- **Implementation note vs spec:** the spec described a literal wall→uniform-grid container swap with `matchedGeometryEffect`. This plan keeps the single chunked-wall layout and instead fades the shelf ledges + jiggles records, with live drag-and-drop reorder — same "lift off the shelves to rearrange" UX intent, materially simpler and less fragile than a cross-tree geometry match. Update the spec's §4 if you want the doc to match the built behavior.
- **Type consistency:** `FavoritesOrderStore.arranged/commit`, `FavoritesFilter.matches/isActive/hasFacetFilters`, `favoritesFacets(in:)`, `Jiggle`, `FavoriteReorderDelegate`, `FavoritesFilterSheet` are referenced consistently across tasks.

## Out of Scope (v1)

- Cross-device order sync (Supabase `position` column + migration).
- Edge auto-scroll while dragging.
- Condition-grade filtering; favorites-specific condition independent of listen status.
- Reordering within a filtered subset.
