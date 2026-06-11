# Insights History Timeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the full Insights history into its own destination and add a tappable, monthly-era taste arc timeline.

**Architecture:** Keep v1 inside the existing Insights boundary to avoid Xcode project-file churn: pure derivation types/functions live in `InsightsViewModel.swift`, SwiftUI destination/helper views live in `InsightsView.swift`, and focused tests are appended to `TasteMirrorTests.swift`. The model derives monthly eras from already-fetched history, ratings, favorites, onboarding read, and the current mirror.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, existing Daily Music design-system styles.

---

### Task 1: Timeline Derivation Model

**Files:**
- Modify: `Daily Music/ViewModels/InsightsViewModel.swift`
- Modify: `Daily MusicTests/TasteMirrorTests.swift`

- [ ] **Step 1: Add failing tests**

Append tests to `Daily MusicTests/TasteMirrorTests.swift` that call `InsightsViewModel.buildTasteEras(...)` and verify:

```swift
@Test func tasteErasBuildOnboardingMonthlyAndCurrentNodes() {
    let calendar = Calendar(identifier: .gregorian)
    let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
    let february = calendar.date(from: DateComponents(year: 2026, month: 2, day: 12))!
    let march = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12))!
    let januaryEntries = (0..<3).map { Self.entry(id: 10 + $0, mood: "Serene", year: 2010, genre: "Indie", energy: 2).withDate(january.addingTimeInterval(Double($0) * 86_400)) }
    let februaryEntries = (0..<3).map { Self.entry(id: 20 + $0, mood: "Euphoric", year: 2020, genre: "Pop", energy: 5).withDate(february.addingTimeInterval(Double($0) * 86_400)) }
    let currentEntries = (0..<10).map { Self.entry(id: 100 + $0, mood: "Euphoric", year: 2020, genre: "Pop", energy: 5).withDate(march.addingTimeInterval(Double($0) * 86_400)) }
    let all = januaryEntries + februaryEntries + currentEntries
    let ratings = Dictionary(uniqueKeysWithValues: all.map { ($0.id, 1) })
    let mirror = TasteMirror.build(from: currentEntries.map { RatedSong(entry: $0, value: 1) })

    let eras = InsightsViewModel.buildTasteEras(
        history: all,
        ratings: ratings,
        favoriteIDs: [],
        startingRead: StartingRead(mood: "Serene", genre: "Indie", decade: "2010s"),
        currentMirror: mirror,
        snapshot: .empty,
        calendar: calendar
    )

    #expect(eras.first?.kind == .current)
    #expect(eras.contains { $0.kind == .onboarding })
    #expect(eras.contains { $0.kind == .monthly && $0.title.contains("January") })
    #expect(eras.contains { $0.kind == .monthly && $0.title.contains("February") })
}
```

Also add:

```swift
@Test func tasteErasExcludeWeakMonthsAndFavoritesCountAsSignal() {
    let calendar = Calendar(identifier: .gregorian)
    let april = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5))!
    let may = calendar.date(from: DateComponents(year: 2026, month: 5, day: 5))!
    let weak = (0..<2).map { Self.entry(id: 300 + $0, mood: "Dark", genre: "Post-Punk").withDate(april.addingTimeInterval(Double($0) * 86_400)) }
    let heartOnly = (0..<3).map { Self.entry(id: 400 + $0, mood: "Dreamy", genre: "Ambient").withDate(may.addingTimeInterval(Double($0) * 86_400)) }
    let currentMirror = TasteMirror.build(from: [])
    let eras = InsightsViewModel.buildTasteEras(
        history: weak + heartOnly,
        ratings: Dictionary(uniqueKeysWithValues: weak.map { ($0.id, 1) }),
        favoriteIDs: Set(heartOnly.map(\.id)),
        startingRead: StartingRead(),
        currentMirror: currentMirror,
        snapshot: .empty,
        calendar: calendar
    )

    #expect(!eras.contains { $0.title.contains("April") })
    #expect(eras.contains { $0.title.contains("May") })
}
```

Add this helper extension in the test file:

```swift
private extension DailyEntry {
    func withDate(_ date: Date) -> DailyEntry {
        DailyEntry(
            id: id, date: date, title: title, artist: artist,
            albumArtURL: albumArtURL, journalMarkdown: journalMarkdown,
            appleMusicID: appleMusicID, spotifyURI: spotifyURI,
            genre: genre, year: year, mood: mood, energy: energy,
            theme: theme, language: language
        )
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DailyMusicTests/TasteMirrorTests
```

Expected: FAIL because `TasteEra`, `buildTasteEras`, and the `StartingRead()` initializer are missing or inaccessible.

- [ ] **Step 3: Implement derivation**

In `InsightsViewModel.swift`:

- Add `TasteEra` and `TasteArcSummary`.
- Add `private(set) var tasteEras: [TasteEra] = []`.
- Add `private(set) var tasteArcSummary: TasteArcSummary?`.
- Change `load(favoriteIDs:)` to `load(favoriteIDs:startingRead:)` with a default `StartingRead()`.
- Build eras after `mirror` is built and snapshot is evaluated.
- Add `static func buildTasteEras(...)`.

Core behavior:

```swift
struct TasteEra: Identifiable, Equatable {
    enum Kind: Equatable { case onboarding, monthly, reveal, current }
    let id: String
    let kind: Kind
    let date: Date
    let title: String
    let subtitle: String
    let profile: TasteProfile?
    let mirror: TasteMirror?
    let driverLine: String?
    let songs: [DailyEntry]
}

struct TasteArcSummary: Equatable {
    let origin: String
    let current: String
    let feedback: String
    let colors: [String]
}
```

Use a month threshold of 3 rated/favorited entries, exclude the current month from monthly era nodes, and sort timeline display newest-first with current first and onboarding last.

- [ ] **Step 4: Verify derivation tests pass**

Run the same `xcodebuild test` command. Expected: PASS for `TasteMirrorTests`.

---

### Task 2: History Destination

**Files:**
- Modify: `Daily Music/Views/InsightsView.swift`

- [ ] **Step 1: Replace inline history with a summary card**

Rename `historySection(accent:)` to `historySummaryCard(accent:)`. Render a `NavigationLink` to `HistoryView(entries:accent:onRatingChanged:)`. The summary should show:

- `YOUR HISTORY`
- `<count> songs in your history`
- newest song/date or existing empty copy
- `chevron.right`

- [ ] **Step 2: Add `HistoryView`**

Add a private SwiftUI view in `InsightsView.swift`:

```swift
private struct HistoryView: View {
    let entries: [HistoryEntry]
    let accent: Color
    let onRatingChanged: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if entries.isEmpty {
                    Text("Your daily songs will appear here once you start listening.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xl)
                } else {
                    ForEach(entries) { item in
                        HistoryEntryRow(item: item, accent: accent, onRatingChanged: onRatingChanged)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("History")
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
```

- [ ] **Step 3: Build**

Run:

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: build succeeds.

---

### Task 3: Taste Arc Card And Timeline Destination

**Files:**
- Modify: `Daily Music/Views/InsightsView.swift`

- [ ] **Step 1: Wire starting read into load**

Add `@AppStorage("startingDecade") private var startingDecade = ""` and a computed `startingRead` property. Pass it to every `model.load(...)` call.

- [ ] **Step 2: Replace `startedHereCard` with `tasteArcCard`**

Render a `NavigationLink` to `TasteArcTimelineView(eras: model?.tasteEras ?? [], accent: accent)`.

The card shows header `YOUR TASTE ARC`, origin capsule, 3-5 era dots, current capsule, feedback line, and a chevron.

- [ ] **Step 3: Add `TasteArcTimelineView`**

Add a private SwiftUI view in `InsightsView.swift` that displays eras newest-first:

- current era gets the strongest material/accent treatment.
- onboarding gets `flag.checkered`.
- reveal gets `sparkles`.
- each row can expand inline on tap to show `driverLine` and up to 3 songs.

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: build succeeds.

---

### Task 4: Final Verification

**Files:**
- Verify all modified files.

- [ ] **Step 1: Run focused tests**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DailyMusicTests/TasteMirrorTests
```

Expected: PASS.

- [ ] **Step 2: Run full build**

Run:

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: PASS.

- [ ] **Step 3: Review diff**

Run:

```bash
git diff --stat
git diff -- "Daily Music/ViewModels/InsightsViewModel.swift" "Daily Music/Views/InsightsView.swift" "Daily MusicTests/TasteMirrorTests.swift"
```

Expected: Only planned files changed.
