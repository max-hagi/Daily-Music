# Today Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Declutter Today into a calm single-screen "song" zone with a distinct reading-mode "story" zone revealed on a snap-scroll; replace the playback/library/streaming button stack with a heart icon, an info sheet, and one "Open in [default service]" action backed by a Settings preference.

**Architecture:** A pure `StreamingService` enum builds per-service deep links (unit-tested). A `CatalogInfoService` fetches free iTunes-lookup facts (parsing unit-tested; live = URLSession, mock = sample). New SwiftUI components (`OpenInSection`, `SongInfoSheet`) plug into a restructured `EntryDetailView`; the immersive (Today) layout uses a two-zone view-aligned snap scroll. The default service lives in the synced `UserSettings` blob and is read by the UI via `@AppStorage`.

**Tech Stack:** SwiftUI (iOS 26 / Liquid Glass), `@Observable` MVVM-lite, Supabase-synced settings, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-06-02-today-page-redesign-design.md`

---

## Conventions (read once)

- New `.swift` files under `Daily Music/` auto-join the app target (synchronized folders). Test files go in `Daily MusicTests/`.
- Always export the toolchain first:
  ```bash
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  ```
- **Build:** `xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -25` → `** BUILD SUCCEEDED **`.
- **Test:** `xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests" 2>&1 | tail -30`.
- Module under test: `@testable import Daily_Music`.
- Work on a branch: `git checkout -b feature/today-redesign` (from `main`).
- Commit after each task with the message shown.

## File Structure

**Create:**
- `Daily Music/Models/StreamingService.swift` — service enum, deep-link builder, `ServiceLogo` view.
- `Daily Music/Services/CatalogInfoService.swift` — `CatalogInfo` + parsing + protocol + Mock + Live (iTunes lookup).
- `Daily Music/Views/SongInfoSheet.swift` — the ⓘ info panel.
- `Daily Music/Views/OpenInSection.swift` — "Open in [default]" button + quick-switch menu.
- `Daily MusicTests/StreamingServiceTests.swift`, `Daily MusicTests/CatalogInfoTests.swift`.

**Modify:**
- `Daily Music/Models/UserSettings.swift` — add `preferredStreamingService`.
- `Daily Music/ViewModels/SettingsViewModel.swift` — wire the new setting.
- `Daily Music/Views/SettingsView.swift` — replace stale music rows with the picker.
- `Daily Music/App/AppEnvironment.swift` — register `catalogInfo`.
- `Daily Music/Views/EntryDetailView.swift` — remove old controls; add action cluster + Open-in; two-zone immersive scroll.

---

## Task 1: `StreamingService` model + deep links (TDD)

**Files:**
- Create: `Daily Music/Models/StreamingService.swift`
- Test: `Daily MusicTests/StreamingServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Daily MusicTests/StreamingServiceTests.swift`:
```swift
import Testing
import Foundation
@testable import Daily_Music

struct StreamingServiceTests {
    static func entry(appleMusicID: String = "1", spotifyURI: String = "spotify:track:x",
                      artist: String = "Artist", title: String = "Title") -> DailyEntry {
        DailyEntry(id: UUID(), date: Date(), title: title, artist: artist,
                   albumArtURL: nil, journalMarkdown: "",
                   appleMusicID: appleMusicID, spotifyURI: spotifyURI)
    }

    @Test func appleMusicIsExactLink() {
        let url = StreamingService.appleMusic.url(for: Self.entry(appleMusicID: "1440947554"))
        #expect(url?.absoluteString == "https://music.apple.com/song/1440947554")
    }

    @Test func spotifyIsExactLink() {
        let url = StreamingService.spotify.url(for: Self.entry(spotifyURI: "spotify:track:4gphxUgq0JSFv2BCLhNDiE"))
        #expect(url?.absoluteString == "https://open.spotify.com/track/4gphxUgq0JSFv2BCLhNDiE")
    }

    @Test func tidalIsSearchFallback() {
        let url = StreamingService.tidal.url(for: Self.entry(artist: "R.E.M.", title: "Nightswimming"))?.absoluteString ?? ""
        #expect(url.hasPrefix("https://tidal.com/search?q="))
        #expect(url.contains("Nightswimming"))
    }

    @Test func allCasesCoverThree() {
        #expect(StreamingService.allCases.count == 3)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the **Test** command. Expected: FAIL — "cannot find 'StreamingService' in scope".

- [ ] **Step 3: Create the model**

Create `Daily Music/Models/StreamingService.swift`:
```swift
//
//  StreamingService.swift
//  Daily Music
//
//  The streaming services we can hand a song off to. Apple Music + Spotify use
//  the IDs we store (exact track links); Tidal has no stored ID so it opens a
//  search. Also the single source of truth for each service's display name + logo.
//

import SwiftUI

enum StreamingService: String, CaseIterable, Identifiable {
    case appleMusic = "Apple Music"
    case spotify    = "Spotify"
    case tidal      = "Tidal"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// Deep link to this song in the service.
    func url(for entry: DailyEntry) -> URL? {
        switch self {
        case .appleMusic: entry.appleMusicURL
        case .spotify:    entry.spotifyURL
        case .tidal:
            let q = "\(entry.artist) \(entry.title)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://tidal.com/search?q=\(q)")
        }
    }
}

/// Renders a service's logo at a consistent size. Apple has an SF Symbol; Spotify
/// uses a hand-built glyph (we can't ship the trademarked asset); Tidal is a
/// simple wordmark.
struct ServiceLogo: View {
    let service: StreamingService
    var size: CGFloat = 16

    var body: some View {
        switch service {
        case .appleMusic:
            Image(systemName: "applelogo").font(.system(size: size))
        case .spotify:
            SpotifyGlyph().frame(width: size + 2, height: size + 2)
        case .tidal:
            Text("TIDAL").font(.system(size: size * 0.8, weight: .black)).tracking(0.5)
        }
    }
}

// A hand-drawn Spotify-style glyph (three stacked waves in a green circle).
private struct SpotifyGlyph: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.12, green: 0.84, blue: 0.38))
            VStack(spacing: 2.2) {
                wave(width: 9.5, rotation: 7)
                wave(width: 8, rotation: 6)
                wave(width: 6.4, rotation: 5)
            }
            .foregroundStyle(.black.opacity(0.82))
        }
    }
    private func wave(width: CGFloat, rotation: Double) -> some View {
        Capsule().frame(width: width, height: 1.35).rotationEffect(.degrees(rotation)).offset(x: 0.8)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run the **Test** command. Expected: the 4 StreamingService tests pass, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/StreamingService.swift" "Daily MusicTests/StreamingServiceTests.swift"
git commit -m "feat: StreamingService deep-link builder + ServiceLogo (TDD)"
```

---

## Task 2: `CatalogInfoService` + iTunes parsing (TDD) + AppEnvironment

**Files:**
- Create: `Daily Music/Services/CatalogInfoService.swift`
- Modify: `Daily Music/App/AppEnvironment.swift`
- Test: `Daily MusicTests/CatalogInfoTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Daily MusicTests/CatalogInfoTests.swift`:
```swift
import Testing
import Foundation
@testable import Daily_Music

struct CatalogInfoTests {
    @Test func parsesITunesLookupPayload() {
        let json = """
        {"resultCount":1,"results":[{"collectionName":"Automatic for the People","releaseDate":"1992-10-05T07:00:00Z","trackTimeMillis":257000,"primaryGenreName":"Alternative"}]}
        """.data(using: .utf8)!
        let info = CatalogInfo.parse(json)
        #expect(info?.album == "Automatic for the People")
        #expect(info?.releaseYear == "1992")
        #expect(info?.durationSeconds == 257)
        #expect(info?.genre == "Alternative")
    }

    @Test func parseReturnsNilOnEmptyResults() {
        let json = #"{"resultCount":0,"results":[]}"#.data(using: .utf8)!
        #expect(CatalogInfo.parse(json) == nil)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the **Test** command. Expected: FAIL — "cannot find 'CatalogInfo' in scope".

- [ ] **Step 3: Create the service + parsing**

Create `Daily Music/Services/CatalogInfoService.swift`:
```swift
//
//  CatalogInfoService.swift
//  Daily Music
//
//  Pulls catalog facts for a song from Apple's FREE iTunes lookup API (no auth,
//  no paid account). Used by the "more info" sheet. Parsing is separated so it's
//  unit-testable; the live impl is a plain URLSession GET.
//

import Foundation

struct CatalogInfo: Equatable {
    var album: String?
    var releaseYear: String?
    var durationSeconds: Int?
    var genre: String?

    /// Parse the iTunes lookup JSON (`https://itunes.apple.com/lookup?id=…`).
    static func parse(_ data: Data) -> CatalogInfo? {
        struct Response: Decodable {
            struct Result: Decodable {
                let collectionName: String?
                let releaseDate: String?
                let trackTimeMillis: Int?
                let primaryGenreName: String?
            }
            let results: [Result]
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let first = decoded.results.first else { return nil }
        return CatalogInfo(
            album: first.collectionName,
            releaseYear: first.releaseDate.map { String($0.prefix(4)) },
            durationSeconds: first.trackTimeMillis.map { $0 / 1000 },
            genre: first.primaryGenreName
        )
    }

    /// "m:ss" for the duration, or nil.
    var durationText: String? {
        guard let s = durationSeconds else { return nil }
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}

protocol CatalogInfoService {
    func info(appleMusicID: String) async throws -> CatalogInfo
}

struct MockCatalogInfoService: CatalogInfoService {
    func info(appleMusicID: String) async throws -> CatalogInfo {
        try? await Task.sleep(for: .milliseconds(300))
        return CatalogInfo(album: "Automatic for the People", releaseYear: "1992",
                           durationSeconds: 257, genre: "Alternative")
    }
}

struct LiveCatalogInfoService: CatalogInfoService {
    func info(appleMusicID: String) async throws -> CatalogInfo {
        let url = URL(string: "https://itunes.apple.com/lookup?id=\(appleMusicID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let info = CatalogInfo.parse(data) else { throw URLError(.cannotParseResponse) }
        return info
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run the **Test** command. Expected: both CatalogInfo tests pass.

- [ ] **Step 5: Register in AppEnvironment**

In `AppEnvironment.swift`:
- After `let ratings: RatingService` add: `    let catalogInfo: CatalogInfoService`
- After the init param `ratings: RatingService,` add: `        catalogInfo: CatalogInfoService,`
- After `self.ratings = ratings` add: `        self.catalogInfo = catalogInfo`
- In `mock()` after `ratings: MockRatingService(),` add: `            catalogInfo: MockCatalogInfoService(),`
- In `live()` after `ratings: SupabaseRatingService(),` add: `            catalogInfo: LiveCatalogInfoService(),`

- [ ] **Step 6: Verify build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Services/CatalogInfoService.swift" "Daily MusicTests/CatalogInfoTests.swift" "Daily Music/App/AppEnvironment.swift"
git commit -m "feat: CatalogInfoService (iTunes lookup) + parsing tests + AppEnvironment"
```

---

## Task 3: Default streaming service setting (UserSettings + Settings UI)

**Files:**
- Modify: `Daily Music/Models/UserSettings.swift`
- Modify: `Daily Music/ViewModels/SettingsViewModel.swift`
- Modify: `Daily Music/Views/SettingsView.swift`

- [ ] **Step 1: Add the field to the synced blob**

In `UserSettings.swift`, after `var weeklyRecapEnabled = true` add:
```swift
    var preferredStreamingService = "Apple Music"
```
In `enum CodingKeys`, add `preferredStreamingService` to the case list.
In `init(from:)`, before `self = s`, add:
```swift
        s.preferredStreamingService = try c.decodeIfPresent(String.self, forKey: .preferredStreamingService) ?? s.preferredStreamingService
```

- [ ] **Step 2: Wire it in SettingsViewModel**

In `SettingsViewModel.swift`:
- Add a stored property (after `weeklyRecapEnabled`):
  ```swift
      var preferredStreamingService: StreamingService = .appleMusic {
          didSet { defaults.set(preferredStreamingService.rawValue, forKey: Keys.preferredStreamingService); scheduleSync() }
      }
  ```
- In `enum Keys`, add:
  ```swift
          static let preferredStreamingService = "settings.preferredStreamingService"
  ```
- In `init`, after the `weeklyRecapEnabled` line, add:
  ```swift
          self.preferredStreamingService = Self.storedEnum(Keys.preferredStreamingService, default: .appleMusic, defaults: defaults)
  ```
- In `currentSettings`, before `return s`, add:
  ```swift
          s.preferredStreamingService = preferredStreamingService.rawValue
  ```
- In `apply(_:)`, add:
  ```swift
          preferredStreamingService = StreamingService(rawValue: s.preferredStreamingService) ?? .appleMusic
  ```
- In `resetLocalPreferences()`, add:
  ```swift
          preferredStreamingService = .appleMusic
  ```

> `storedEnum` is generic over `RawRepresentable where RawValue == String`; `StreamingService` qualifies.

- [ ] **Step 3: Add the picker to SettingsView**

In `SettingsView.swift`, in `musicSection`, replace the two stale rows:
```swift
            LabeledContent("Default action", value: "Add to Library")
            LabeledContent("Preview length", value: "30 seconds")
```
with:
```swift
            Picker("Default streaming service", selection: $model.preferredStreamingService) {
                ForEach(StreamingService.allCases) { service in
                    Text(service.displayName).tag(service)
                }
            }
```

- [ ] **Step 4: Verify build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/UserSettings.swift" "Daily Music/ViewModels/SettingsViewModel.swift" "Daily Music/Views/SettingsView.swift"
git commit -m "feat: default streaming service setting (synced + Settings picker)"
```

---

## Task 4: `SongInfoSheet` (the ⓘ info panel)

**Files:**
- Create: `Daily Music/Views/SongInfoSheet.swift`

- [ ] **Step 1: Create the sheet**

Create `Daily Music/Views/SongInfoSheet.swift`:
```swift
//
//  SongInfoSheet.swift
//  Daily Music
//
//  The "more info" panel. Real catalog facts from the free iTunes lookup API
//  (album, release year, length, genre) plus the song's curated tags (mood,
//  energy, theme, decade, language). Degrades to tags-only if offline.
//

import SwiftUI

struct SongInfoSheet: View {
    let entry: DailyEntry
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var info: CatalogInfo?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            List {
                Section("Track") {
                    LabeledContent("Title", value: entry.title)
                    LabeledContent("Artist", value: entry.artist)
                    if let a = info?.album { LabeledContent("Album", value: a) }
                    if let y = info?.releaseYear { LabeledContent("Released", value: y) }
                    if let d = info?.durationText { LabeledContent("Length", value: d) }
                    if let g = info?.genre { LabeledContent("Genre", value: g) }
                    if !loaded { HStack { Text("Loading catalog info…").foregroundStyle(.secondary); Spacer(); ProgressView() } }
                }

                if hasTags {
                    Section("Your tags") {
                        if let m = entry.mood { LabeledContent("Mood", value: m) }
                        if let dec = entry.decade { LabeledContent("Era", value: dec) }
                        if let e = entry.energy { LabeledContent("Energy", value: "\(e)/5") }
                        if let t = entry.theme { LabeledContent("Theme", value: t) }
                        if let g = entry.genre { LabeledContent("Genre (curated)", value: g) }
                        if let l = entry.language { LabeledContent("Language", value: l) }
                    }
                }
            }
            .navigationTitle("Song info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .task {
            info = try? await env.catalogInfo.info(appleMusicID: entry.appleMusicID)
            loaded = true
        }
    }

    private var hasTags: Bool {
        entry.mood != nil || entry.decade != nil || entry.energy != nil
            || entry.theme != nil || entry.genre != nil || entry.language != nil
    }
}
```

- [ ] **Step 2: Verify build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/SongInfoSheet.swift"
git commit -m "feat: SongInfoSheet (iTunes facts + curated tags)"
```

---

## Task 5: `OpenInSection` (open-in button + quick switch)

**Files:**
- Create: `Daily Music/Views/OpenInSection.swift`

- [ ] **Step 1: Create the component**

Create `Daily Music/Views/OpenInSection.swift`:
```swift
//
//  OpenInSection.swift
//  Daily Music
//
//  One primary "Open in [your default service]" button (logo + name) plus a ⋯
//  menu to open this song in another service without changing the default. The
//  default is read live from the synced setting via @AppStorage (same key the
//  SettingsViewModel writes).
//

import SwiftUI

struct OpenInSection: View {
    let entry: DailyEntry
    var accent: Color = Theme.Brand.gradient[0]

    // Same UserDefaults key SettingsViewModel.Keys.preferredStreamingService writes.
    @AppStorage("settings.preferredStreamingService") private var preferredRaw = StreamingService.appleMusic.rawValue
    @Environment(\.openURL) private var openURL

    private var preferred: StreamingService { StreamingService(rawValue: preferredRaw) ?? .appleMusic }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if let url = preferred.url(for: entry) { openURL(url) }
            } label: {
                HStack(spacing: 8) {
                    ServiceLogo(service: preferred)
                    Text("Open in \(preferred.displayName)")
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.forward")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: accent))

            Menu {
                ForEach(StreamingService.allCases.filter { $0 != preferred }) { service in
                    Button {
                        if let url = service.url(for: entry) { openURL(url) }
                    } label: {
                        Label("Open in \(service.displayName)", systemImage: "arrow.up.forward.app")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
        }
        .padding(.horizontal)
    }
}
```

- [ ] **Step 2: Verify build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/OpenInSection.swift"
git commit -m "feat: OpenInSection (default-service button + quick switch)"
```

---

## Task 6: Redesign `EntryDetailView` (declutter + action cluster + two-zone Today)

**Files:**
- Modify: `Daily Music/Views/EntryDetailView.swift`

This is the largest task — best implemented with the build→simulator-screenshot loop. Remove the old controls, add the new cluster + Open-in, shrink the greeting, and (immersive only) split into the song zone + journal zone with a view-aligned snap and a reading-surface reveal.

- [ ] **Step 1: Remove the obsolete controls**

In `EntryDetailView.swift` delete these from `body`:
- the `PreviewPlayButton(...)` line,
- the `HStack { FavoriteButton(...) ; RatingBar(...) } .padding(.horizontal)` block,
- the `streamingActions` reference,
- the `Divider().padding(.vertical, 4)` that preceded the journal (the zone background now provides separation).

And delete these now-unused private structs further down the file: `PreviewPlayButton`, `AddToPlaylistButton`, `FavoriteButton`, the `streamingActions` computed property, and `SpotifyLogoIcon`. (`MusicPlayer`/MusicKit infra elsewhere is untouched.)

- [ ] **Step 2: Add the shared action cluster + Open-in + info sheet state**

Add near the top of `EntryDetailView` (with the other `@State`):
```swift
    @State private var showingInfo = false
```
Add these helper subviews to `EntryDetailView`:
```swift
    /// favorite (heart) + 👍/👎 rating + info, as one compact glass row.
    private var actionCluster: some View {
        HStack(spacing: 14) {
            heartButton
            RatingBar(entry: entry, accent: palette.accent)
            infoButton
        }
        .padding(.horizontal)
    }

    private var heartButton: some View {
        let store = env.favoritesStore
        let isFav = store.isFavorite(entry)
        return Button {
            Task { await store.toggle(entry) }
        } label: {
            Image(systemName: isFav ? "heart.fill" : "heart")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isFav ? .red : palette.accent)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
    }

    private var infoButton: some View {
        Button { showingInfo = true } label: {
            Image(systemName: "info")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(palette.accent)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Song info")
    }
```
Add this modifier to the root `ZStack` in `body` (next to the existing `.sheet`):
```swift
        .sheet(isPresented: $showingInfo) { SongInfoSheet(entry: entry) }
```

- [ ] **Step 3: Standard (non-immersive) layout — wire the new controls**

In the non-immersive branch (Vault/Favorites — `else` of `usesImmersiveBackdrop`), the content order becomes: `AlbumArtView`, `header`, `actionCluster`, `ReactionsBar(...)`, `OpenInSection(entry: entry, accent: palette.accent)`, then the journal. Keep the existing single `ScrollView`. Replace the removed controls with these three lines in order:
```swift
                    actionCluster
                    ReactionsBar(entry: entry, accent: palette.accent, isReadOnly: reactionsAreReadOnly)
                    OpenInSection(entry: entry, accent: palette.accent)
```

- [ ] **Step 4: Immersive (Today) layout — two zones with snap + journal reveal**

Replace the immersive content with a two-zone snap scroll. The song zone fills the viewport (a snap target); the journal zone has its own reading-surface background that rises over the art wash. Structure:
```swift
            ScrollView {
                VStack(spacing: 0) {
                    // ZONE 1 — the song (one screen)
                    VStack(spacing: Theme.Spacing.sm) {
                        if let preArtworkMessage {
                            Text(preArtworkMessage)
                                .font(.caption.weight(.semibold))      // shrunk greeting
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        AlbumArtView(url: entry.albumArtURL, cornerRadius: 24)
                            .padding(.horizontal, 68)
                        todayHeader(dateLabel: dateLabel)
                        actionCluster
                        ReactionsBar(entry: entry, accent: palette.accent, isReadOnly: reactionsAreReadOnly)
                        OpenInSection(entry: entry, accent: palette.accent)
                        Spacer(minLength: 0)
                        Label("the story", systemImage: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)
                    }
                    .padding(.top, Theme.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical)   // ≈ one viewport → snap target

                    // ZONE 2 — the story (journal), reading surface rises over the art
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Capsule().fill(.secondary.opacity(0.35)).frame(width: 40, height: 5)
                            .frame(maxWidth: .infinity).padding(.top, 10)
                        Text(entry.title).font(.dmTitle())
                        JournalText(markdown: entry.journalMarkdown)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, 60)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))   // opaque reading surface
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .scrollTransition { content, phase in
                        content.opacity(phase.isIdentity ? 1 : 0).offset(y: phase.isIdentity ? 0 : 40)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
```
Keep the existing `backdrop`, artwork-wait overlay, toolbar, share sheet, and `.task(id: entry.id) { palette.load }`. (The journal's opaque background provides the song/story separation; the snap provides the "resistance.")

- [ ] **Step 5: Build + verify in the simulator**

Run the **Build** command (expect success). Then launch (use the DEBUG env switch → Mock, or live) and confirm on Today: shrunk greeting, art, title, the heart+👍👎+ⓘ cluster, reactions, one "Open in [service]" button + ⋯, no play/add-to-library buttons. Scroll down → snaps into the journal with the reading surface taking over. Tap ⓘ → info sheet. Tap ⋯ → other services. Screenshot:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun simctl io booted screenshot /tmp/today_redesign.png
```

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Views/EntryDetailView.swift"
git commit -m "design: declutter Today — action cluster, Open-in, two-zone story scroll"
```

---

## Task 7: Final gate

- [ ] **Step 1:** Full test suite — run the **Test** command. Expected: all tests pass (StreamingService + CatalogInfo + the prior TasteMirror suite).
- [ ] **Step 2:** Debug build — run the **Build** command. Expected `** BUILD SUCCEEDED **`.
- [ ] **Step 3:** Release build (DEBUG code excluded):
  ```bash
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  xcodebuild build -scheme "Daily Music" -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
  ```
- [ ] **Step 4:** `git status` — expect clean tree.

---

## Self-Review (against the spec)

**Spec coverage:**
- §1 no in-app player → Task 6 removes Play/preview/Add-to-Library/streaming buttons; MusicPlayer infra untouched. ✓
- §1 Open-in default + ⋯ → Task 5 `OpenInSection`. ✓
- §1 default service in Settings, synced → Task 3. ✓
- §1 info panel (iTunes + tags) → Tasks 2 + 4. ✓
- §1 favorite → heart icon; reactions stay; rating stays → Task 6 `actionCluster`. ✓
- §1 greeting shrinks; share stays → Task 6 (caption-size greeting; toolbar share untouched). ✓
- §2 two-zone snap + journal reveal (immersive only) → Task 6 Step 4. ✓
- §3 files → all created/modified. ✓
- §6 honesty (offline → tags only; Tidal search) → Task 4 `hasTags`/optional rows; Task 1 Tidal. ✓
- §7 deferred (full playback, exact Tidal, MusicKit info) → not built. ✓

**Type consistency:** `StreamingService` (`.appleMusic/.spotify/.tidal`, `url(for:)`, `displayName`, `ServiceLogo`), `CatalogInfo` (`album/releaseYear/durationSeconds/genre/durationText`, `parse`), `CatalogInfoService.info(appleMusicID:)`, `AppEnvironment.catalogInfo`, `UserSettings.preferredStreamingService`, `SettingsViewModel.preferredStreamingService: StreamingService`, `@AppStorage("settings.preferredStreamingService")` (matches `SettingsViewModel.Keys.preferredStreamingService`) — consistent across tasks. ✓

**Note:** iTunes lookup has no reliable record-label field, so the info sheet shows album/release/length/genre (label dropped vs the spec's mention) — intentional.
