# Listening Experience & Preview Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real in-app 30-second preview audio (no paid Apple account) and an immersive "Listening" ceremony that plays today's song, then flows into the Today/journal screen when the preview ends.

**Architecture:** A new `PreviewMusicEngine` implements the existing `MusicEngine` protocol by resolving each track's `previewUrl` through the already-present iTunes lookup (`CatalogInfoService`) and streaming it with `AVPlayer`. The `MusicEngine`/`MusicPlayer` seam is extended to report elapsed time and a "finished" event (it is currently time-blind). A new presentational `ListeningView` consumes `MusicPlayer` and is presented by `TodayView` as a full-screen cover — auto-shown the first time a user encounters today's drop (tracked by an `@AppStorage` "heard" flag), and re-openable any time via a toolbar button.

**Tech Stack:** SwiftUI, `@Observable` MVVM-lite, `AVFoundation` (`AVPlayer`), Apple's free iTunes lookup API, Swift Testing (`Daily MusicTests`), `xcodeproj` Ruby gem for test-file registration.

**Scope note:** This is the first of several Phase-0 chunks from `docs/superpowers/specs/2026-06-06-engagement-monetization-design.md`. The optional daily reflection and the onboarding taste-seed are *separate* upcoming plans — not in this one.

---

## Build & test commands (used throughout)

Always export the toolchain first (the machine defaults to CommandLineTools):

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

- **Build:** `xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17'`
- **Test:** `xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests"`
- **Ruby (Homebrew, for adding test files):** `/opt/homebrew/opt/ruby/bin/ruby scripts/add_test_files.rb "<path>"`

**Synchronized-folder rule:** New `.swift` files under `Daily Music/` auto-join the app target (it's a synchronized group — no `.pbxproj` edits). New files under `Daily MusicTests/` do **not** — they must be registered via the Ruby script in Task 2.

---

## File structure

**Modify:**
- `Daily Music/Services/CatalogInfoService.swift` — add `previewURL` to `CatalogInfo` (parse + mock).
- `Daily Music/Services/MusicPlayer.swift` — extend `MusicEngine` (progress/finish), `PlaybackState` (`.finished`), `MusicPlayer` (elapsed/duration/progress + finished/replay), and `MockMusicEngine` (simulate progress + finish).
- `Daily Music/Services/Music/MusicKitMusicEngine.swift` — add the new `MusicEngineError.addToPlaylistUnavailable` case + satisfy the new protocol members.
- `Daily Music/App/AppEnvironment.swift` — wire `PreviewMusicEngine` into `live()`.
- `Daily Music/Views/TodayView.swift` — present `ListeningView`, auto-open ceremony, add "Listen" toolbar button.
- `Daily MusicTests/CatalogInfoTests.swift` — add a `previewURL` parse test.

**Create:**
- `scripts/add_test_files.rb` — register new test files into the `Daily MusicTests` target.
- `Daily Music/Services/Music/PreviewMusicEngine.swift` — the AVPlayer-based preview engine.
- `Daily Music/Models/ListeningCeremony.swift` — pure "should auto-open?" decision.
- `Daily Music/Views/ListeningView.swift` — the immersive listening screen.
- `Daily MusicTests/PlaybackTests.swift` — `MusicPlayer` + `ListeningCeremony` tests.

---

### Task 1: Add `previewURL` to `CatalogInfo`

The iTunes lookup already runs; we just capture one more field (`previewUrl`).

**Files:**
- Modify: `Daily Music/Services/CatalogInfoService.swift`
- Test: `Daily MusicTests/CatalogInfoTests.swift` (existing file — no registration needed)

- [ ] **Step 1: Add the failing test** to the end of `CatalogInfoTests.swift` (inside the existing test struct, or as a new `@Test` — match the file's existing style):

```swift
@Test func parseExtractsPreviewURL() {
    let json = """
    {"results":[{"collectionName":"Be the Cowboy","releaseDate":"2018-08-17T12:00:00Z","trackTimeMillis":150000,"primaryGenreName":"Indie Rock","collectionViewUrl":"https://music.apple.com/album/x","previewUrl":"https://audio-ssl.itunes.apple.com/clip.m4a"}]}
    """.data(using: .utf8)!
    let info = CatalogInfo.parse(json)
    #expect(info?.previewURL == URL(string: "https://audio-ssl.itunes.apple.com/clip.m4a"))
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run the **Test** command above.
Expected: FAIL — `CatalogInfo` has no member `previewURL`.

- [ ] **Step 3: Add the field + parse it.** In `CatalogInfoService.swift`:

Add the stored property to the struct (give it a default so existing call sites keep compiling):

```swift
    var albumURL: URL?
    var previewURL: URL?
```

Add `previewUrl` to the nested `Result` decodable and to the constructed value inside `parse(_:)`:

```swift
            struct Result: Decodable {
                let collectionName: String?
                let releaseDate: String?
                let trackTimeMillis: Int?
                let primaryGenreName: String?
                let collectionViewUrl: String?
                let previewUrl: String?
            }
```

```swift
        return CatalogInfo(
            album: first.collectionName,
            releaseYear: first.releaseDate.map { String($0.prefix(4)) },
            durationSeconds: first.trackTimeMillis.map { $0 / 1000 },
            genre: first.primaryGenreName,
            albumURL: first.collectionViewUrl.flatMap(URL.init(string:)),
            previewURL: first.previewUrl.flatMap(URL.init(string:))
        )
```

Add a real preview URL to `MockCatalogInfoService` so the mock is realistic:

```swift
        return CatalogInfo(
            album: "Automatic for the People",
            releaseYear: "1992",
            durationSeconds: 257,
            genre: "Alternative",
            albumURL: URL(string: "https://music.apple.com/us/album/automatic-for-the-people/1440947547"),
            previewURL: URL(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/92/36/e7/9236e7aa-cf4e-0010-483d-41601131043e/mzaf_10003196158059738086.plus.aac.p.m4a")
        )
```

- [ ] **Step 4: Run the test, verify it passes**

Run the **Test** command. Expected: PASS (plus all existing tests still green).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/CatalogInfoService.swift" "Daily MusicTests/CatalogInfoTests.swift"
git commit -m "feat(audio): parse iTunes previewUrl into CatalogInfo"
```

---

### Task 2: Add the test-file registration script + the `PlaybackTests` file

The `Daily MusicTests` group is **not** synchronized, so a new test file must be registered in the `.pbxproj`. We add a small reusable script (mirrors the existing `scripts/add_test_target.rb` pattern).

**Files:**
- Create: `scripts/add_test_files.rb`
- Create: `Daily MusicTests/PlaybackTests.swift`

- [ ] **Step 1: Create `scripts/add_test_files.rb`**

```ruby
require 'xcodeproj'

path = 'Daily Music.xcodeproj'
project = Xcodeproj::Project.open(path)
test = project.targets.find { |t| t.name == 'Daily MusicTests' }
raise 'test target not found' unless test

group = project.main_group.find_subpath('Daily MusicTests', true)

ARGV.each do |rel|
  base = File.basename(rel)
  already = test.source_build_phase.files_references.any? { |fr| fr && fr.path && fr.path.end_with?(base) }
  if already
    puts "skip (already present): #{rel}"
    next
  end
  ref = group.new_file(rel)
  test.add_file_references([ref])
  puts "added: #{rel}"
end

project.save
puts 'OK'
```

- [ ] **Step 2: Create `Daily MusicTests/PlaybackTests.swift`** with one trivial passing test (real tests are added in later tasks):

```swift
import Testing
@testable import Daily_Music

struct PlaybackTests {
    @Test func placeholder() {
        #expect(true)
    }
}
```

- [ ] **Step 3: Register the file**

Run: `/opt/homebrew/opt/ruby/bin/ruby scripts/add_test_files.rb "Daily MusicTests/PlaybackTests.swift"`
Expected output: `added: Daily MusicTests/PlaybackTests.swift` then `OK`.

- [ ] **Step 4: Run the tests, verify the new file is picked up**

Run the **Test** command. Expected: PASS, and the output includes `PlaybackTests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/add_test_files.rb "Daily MusicTests/PlaybackTests.swift" "Daily Music.xcodeproj"
git commit -m "test: add reusable test-file registration script + PlaybackTests"
```

---

### Task 3: Extend the `MusicEngine`/`MusicPlayer` seam for progress + finish

The seam is currently time-blind (`idle/buffering/playing/paused`, no elapsed time, no end event). Add an `.finished` state, an `elapsed`/`duration`/`progress` readout, and `onProgress`/`onFinish` callbacks the engine drives.

**Files:**
- Modify: `Daily Music/Services/MusicPlayer.swift`
- Test: `Daily MusicTests/PlaybackTests.swift`

- [ ] **Step 1: Write the failing tests.** Replace the `placeholder` test in `PlaybackTests.swift` with:

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct PlaybackTests {
    // A controllable engine so we can fire progress/finish on demand.
    final class FakeEngine: MusicEngine {
        var onProgress: ((TimeInterval, TimeInterval) -> Void)?
        var onFinish: (() -> Void)?
        func play(appleMusicID: String) async throws {}
        func pause() async {}
        func stop() async {}
        func addToDailyPlaylist(appleMusicID: String) async throws {}
    }

    private func sampleEntry() -> DailyEntry {
        DailyEntry(
            id: UUID(), date: Date(), title: "Nobody", artist: "Mitski",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "123",
            spotifyURI: "spotify:track:123"
        )
    }

    @Test func progressUpdatesElapsedAndDuration() async {
        let engine = FakeEngine()
        let player = MusicPlayer(engine: engine)
        let entry = sampleEntry()
        await player.toggle(entry)               // starts -> playing
        engine.onProgress?(9, 30)                // engine reports halfway-ish
        #expect(player.elapsed == 9)
        #expect(player.duration == 30)
        #expect(abs(player.progress - 0.3) < 0.001)
    }

    @Test func finishMovesToFinishedState() async {
        let engine = FakeEngine()
        let player = MusicPlayer(engine: engine)
        let entry = sampleEntry()
        await player.toggle(entry)
        engine.onFinish?()
        #expect(player.state == .finished)
    }

    @Test func tappingAFinishedTrackReplaysIt() async {
        let engine = FakeEngine()
        let player = MusicPlayer(engine: engine)
        let entry = sampleEntry()
        await player.toggle(entry)
        engine.onFinish?()
        #expect(player.state == .finished)
        await player.toggle(entry)               // replay
        #expect(player.state == .playing)
        #expect(player.elapsed == 0)
    }
}
```

- [ ] **Step 2: Run the tests, verify they fail**

Run the **Test** command.
Expected: FAIL — `MusicEngine` has no `onProgress`/`onFinish`, `PlaybackState` has no `.finished`, `MusicPlayer` has no `elapsed`/`duration`/`progress`.

- [ ] **Step 3: Implement the seam changes** in `MusicPlayer.swift`.

Add `.finished` to the state enum:

```swift
enum PlaybackState: Equatable {
    case idle        // nothing loaded
    case buffering   // loading / about to start
    case playing
    case paused
    case finished    // the preview played to its end
}
```

Make `MusicEngine` a class protocol and add the two callbacks:

```swift
protocol MusicEngine: AnyObject {
    func play(appleMusicID: String) async throws
    func pause() async
    func stop() async
    /// Find-or-create the "Daily Music" library playlist and add the track.
    func addToDailyPlaylist(appleMusicID: String) async throws

    /// Reported ~5×/sec while a preview plays: (elapsedSeconds, totalSeconds).
    var onProgress: ((TimeInterval, TimeInterval) -> Void)? { get set }
    /// Reported once when the current preview plays to its end.
    var onFinish: (() -> Void)? { get set }
}
```

In `MusicPlayer`, add the readouts and wire the callbacks in `init` (use `[weak self]` — the engine retains these closures and the player retains the engine):

```swift
    private(set) var state: PlaybackState = .idle
    private(set) var nowPlayingEntryID: UUID?   // which entry is loaded (nil = none)
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    /// 0…1 fraction for progress rings / bars.
    var progress: Double {
        duration > 0 ? min(1, max(0, elapsed / duration)) : 0
    }

    private let engine: MusicEngine

    init(engine: MusicEngine) {
        self.engine = engine
        engine.onProgress = { [weak self] elapsed, duration in
            self?.elapsed = elapsed
            self?.duration = duration
        }
        engine.onFinish = { [weak self] in
            guard let self else { return }
            self.elapsed = self.duration
            self.state = .finished
        }
    }
```

Handle `.finished` in `toggle` (tapping a finished track replays it) — update the inner `switch`:

```swift
            switch state {
            case .playing:
                await engine.pause()
                state = .paused
            case .paused:
                await resume(entry)
            case .finished:
                await resume(entry)   // replay from the start
            case .idle, .buffering:
                break   // ignore taps mid-transition
            }
```

Reset `elapsed` when (re)starting, in `resume`:

```swift
    private func resume(_ entry: DailyEntry) async {
        nowPlayingEntryID = entry.id
        elapsed = 0
        state = .buffering
        do {
            try await engine.play(appleMusicID: entry.appleMusicID)
            state = .playing
        } catch {
            state = .idle
            nowPlayingEntryID = nil
        }
    }
```

Reset both in `stop`:

```swift
    func stop() async {
        await engine.stop()
        state = .idle
        nowPlayingEntryID = nil
        elapsed = 0
        duration = 0
    }
```

Make `MockMusicEngine` conform to the new protocol and simulate progress + finish (so the ceremony flow is fully testable in the mock environment, which has no real audio). Replace the class:

```swift
final class MockMusicEngine: MusicEngine {
    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onFinish: (() -> Void)?

    // A brisk simulated clip so dev/sim testing of the ceremony is quick.
    private let simulatedDuration: TimeInterval = 6
    private var ticker: Task<Void, Never>?

    func play(appleMusicID: String) async throws {
        try? await Task.sleep(for: .milliseconds(500)) // mimic buffering
        ticker?.cancel()
        ticker = Task { [weak self] in
            guard let self else { return }
            let step = 0.2
            var t = 0.0
            while t < self.simulatedDuration {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .seconds(step))
                t += step
                await MainActor.run { self.onProgress?(t, self.simulatedDuration) }
            }
            await MainActor.run { self.onFinish?() }
        }
    }
    func pause() async { ticker?.cancel() }
    func stop() async { ticker?.cancel() }
    func addToDailyPlaylist(appleMusicID: String) async throws {
        try? await Task.sleep(for: .milliseconds(400))
    }
}
```

- [ ] **Step 4: Run the tests, verify they pass**

Run the **Test** command. Expected: PASS (the three new `PlaybackTests` + all existing tests).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/MusicPlayer.swift" "Daily MusicTests/PlaybackTests.swift"
git commit -m "feat(audio): add progress + finished to the music player seam"
```

---

### Task 4: Build the `PreviewMusicEngine` (AVPlayer + iTunes preview)

A real engine that resolves the preview URL via the existing catalog lookup and streams it, reporting progress + finish, with a gentle volume fade in the final 2 seconds.

**Files:**
- Create: `Daily Music/Services/Music/PreviewMusicEngine.swift`
- Modify: `Daily Music/Services/Music/MusicKitMusicEngine.swift` (add an error case + the two new protocol members)

- [ ] **Step 1: Add the new error case + protocol members to `MusicKitMusicEngine.swift`.**

Add the case to the `MusicEngineError` enum and its copy:

```swift
enum MusicEngineError: LocalizedError {
    case notAuthorized
    case songNotFound
    case noPreviewAvailable
    case addToPlaylistUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:    "Apple Music access wasn't granted."
        case .songNotFound:     "Couldn't find this song in the Apple Music catalog."
        case .noPreviewAvailable: "No preview is available for this song."
        case .addToPlaylistUnavailable: "Saving to your library needs Apple Music. Use “Open in…” for now."
        }
    }
}
```

`MusicKitMusicEngine` now must satisfy the new protocol members. Add stored callbacks (it doesn't drive them yet — that's fine until MusicKit is activated):

```swift
final class MusicKitMusicEngine: MusicEngine {
    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onFinish: (() -> Void)?

    private static let playlistName = "Daily Music"
```

- [ ] **Step 2: Create `Daily Music/Services/Music/PreviewMusicEngine.swift`:**

```swift
//
//  PreviewMusicEngine.swift
//  Daily Music
//
//  Plays free 30-second previews with no paid Apple account. It resolves each
//  track's previewUrl through the existing iTunes lookup (CatalogInfoService),
//  then streams it with AVPlayer — reporting elapsed time and an end event, with
//  a 2-second volume fade so the clip ends like a movement, not a cut.
//
//  At launch (paid account), AppEnvironment can swap this for MusicKitMusicEngine
//  behind the same MusicEngine protocol.
//

import Foundation
import AVFoundation

final class PreviewMusicEngine: MusicEngine {
    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onFinish: (() -> Void)?

    private let catalog: CatalogInfoService
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(catalog: CatalogInfoService) {
        self.catalog = catalog
    }

    func play(appleMusicID: String) async throws {
        let info = try await catalog.info(appleMusicID: appleMusicID)
        guard let previewURL = info.previewURL else {
            throw MusicEngineError.noPreviewAvailable
        }
        await start(url: previewURL)
    }

    @MainActor
    private func start(url: URL) {
        teardown()

        // Play through the silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let player = AVPlayer(url: url)
        player.volume = 1
        self.player = player

        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, let item = player.currentItem else { return }
            let raw = item.duration.seconds
            let duration = raw.isFinite && raw > 0 ? raw : 30
            let elapsed = max(0, time.seconds)
            let remaining = duration - elapsed
            if remaining <= 2 {                       // fade, don't cut
                player.volume = Float(max(0, remaining / 2))
            }
            self.onProgress?(elapsed, duration)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.onFinish?()
        }

        player.play()
    }

    func pause() async {
        await MainActor.run { player?.pause() }
    }

    func stop() async {
        await MainActor.run { teardown() }
    }

    func addToDailyPlaylist(appleMusicID: String) async throws {
        // Library writes require MusicKit (paid account). Surface clearly.
        throw MusicEngineError.addToPlaylistUnavailable
    }

    @MainActor
    private func teardown() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player?.pause()
        player = nil
    }
}
```

- [ ] **Step 3: Build**

Run the **Build** command. Expected: BUILD SUCCEEDED (no unit test — AVPlayer playback is verified in the simulator in Task 9).

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Services/Music/PreviewMusicEngine.swift" "Daily Music/Services/Music/MusicKitMusicEngine.swift"
git commit -m "feat(audio): add PreviewMusicEngine (iTunes preview via AVPlayer)"
```

---

### Task 5: Pure ceremony decision (`ListeningCeremony`)

Whether to auto-open the immersive listen depends only on whether the user has already heard today's entry. Keep that decision pure and tested.

**Files:**
- Create: `Daily Music/Models/ListeningCeremony.swift`
- Test: `Daily MusicTests/PlaybackTests.swift`

- [ ] **Step 1: Write the failing tests.** Add to `PlaybackTests` (inside the struct):

```swift
    @Test func autoOpensWhenTodayNotYetHeard() {
        let id = UUID()
        #expect(ListeningCeremony.shouldAutoOpen(todayEntryID: id, heardEntryID: nil))
    }

    @Test func doesNotAutoOpenWhenTodayAlreadyHeard() {
        let id = UUID()
        #expect(!ListeningCeremony.shouldAutoOpen(todayEntryID: id, heardEntryID: id.uuidString))
    }

    @Test func autoOpensWhenHeardWasADifferentDay() {
        #expect(ListeningCeremony.shouldAutoOpen(todayEntryID: UUID(), heardEntryID: UUID().uuidString))
    }
```

- [ ] **Step 2: Run the tests, verify they fail**

Run the **Test** command. Expected: FAIL — `ListeningCeremony` is undefined.

- [ ] **Step 3: Create `Daily Music/Models/ListeningCeremony.swift`:**

```swift
//
//  ListeningCeremony.swift
//  Daily Music
//
//  Pure rule for the "first-listen ceremony": auto-open the immersive Listening
//  screen only the first time a user encounters today's drop. Once they've heard
//  it, opening the app lands on Today (with a manual "Listen" toggle still there).
//

import Foundation

enum ListeningCeremony {
    /// `heardEntryID` is the stored uuidString of the last entry the user listened
    /// to (nil if none yet). Auto-open unless it already equals today's entry.
    static func shouldAutoOpen(todayEntryID: UUID, heardEntryID: String?) -> Bool {
        heardEntryID != todayEntryID.uuidString
    }
}
```

- [ ] **Step 4: Run the tests, verify they pass**

Run the **Test** command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/ListeningCeremony.swift" "Daily MusicTests/PlaybackTests.swift"
git commit -m "feat(audio): add pure ListeningCeremony auto-open rule"
```

---

### Task 6: Wire `PreviewMusicEngine` into `AppEnvironment.live()`

Share one `LiveCatalogInfoService` between the catalog slot and the engine.

**Files:**
- Modify: `Daily Music/App/AppEnvironment.swift`

- [ ] **Step 1: Update `live()`** to build a shared catalog and pass the preview engine:

```swift
    static func live() -> AppEnvironment {
        let catalog = LiveCatalogInfoService()
        return AppEnvironment(
            auth: SupabaseAuthService(),
            entries: SupabaseEntryService(),
            favorites: SupabaseFavouritesService(),
            checkIns: SupabaseCheckInService(),
            sharedStats: SupabaseSharedStatsService(),
            reactions: SupabaseReactionsService(),
            ratings: SupabaseRatingService(),
            catalogInfo: catalog,
            settings: SupabaseSettingsService(),
            profiles: SupabaseProfileService(),
            friends: SupabaseFriendService(),
            friendNudges: SupabaseFriendNudgeService(),
            notifications: LocalNotificationService(),
            pushRegistration: SupabasePushRegistrationService(),
            // Free 30-sec previews via the iTunes lookup — no paid account.
            // At launch, swap to MusicKitMusicEngine() once MusicKit is enabled.
            musicEngine: PreviewMusicEngine(catalog: catalog)
        )
    }
```

(`mock()` is unchanged — it keeps `MockCatalogInfoService()` + `MockMusicEngine()`.)

- [ ] **Step 2: Build**

Run the **Build** command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/App/AppEnvironment.swift"
git commit -m "feat(audio): wire PreviewMusicEngine into live environment"
```

---

### Task 7: Create `ListeningView`

The immersive listening screen: blurred-art backdrop, big artwork, title/artist, a progress bar, a play/pause control with the equalizer animation while playing, and a "Read today's story" button. Plays on appear; flows to Today on finish.

**Files:**
- Create: `Daily Music/Views/ListeningView.swift`

- [ ] **Step 1: Create the file:**

```swift
//
//  ListeningView.swift
//  Daily Music
//
//  The immersive "listen first" screen. Plays today's 30-sec preview over a
//  blurred-art backdrop, then calls onAdvance() when the preview finishes (or
//  when the listener taps "Read today's story"). Presentational only — it drives
//  playback through the shared MusicPlayer in AppEnvironment.
//

import SwiftUI

struct ListeningView: View {
    let entry: DailyEntry
    var onAdvance: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var player: MusicPlayer { env.musicPlayer }

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                artwork
                titleBlock
                progressBar
                controls
                Spacer()
                readStoryButton
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .preferredColorScheme(.dark)
        .task {
            if !player.isPlaying(entry) && player.state != .finished {
                await player.toggle(entry)
            }
            pulse = !reduceMotion
        }
        .onChange(of: player.state) { _, newValue in
            guard newValue == .finished else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.8))  // a beat, then the story
                onAdvance()
            }
        }
    }

    private var backdrop: some View {
        AsyncImage(url: entry.albumArtURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Color.black
        }
        .ignoresSafeArea()
        .blur(radius: 55)
        .overlay(Color.black.opacity(0.5).ignoresSafeArea())
    }

    private var artwork: some View {
        let breathing = player.state == .playing && pulse
        return AlbumArtView(url: entry.albumArtURL, cornerRadius: 24)
            .frame(maxWidth: 300)
            .scaleEffect(breathing ? 1.0 : 0.97)
            .animation(
                breathing ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .default,
                value: breathing
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(entry.title)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            Text(entry.artist)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(.white).frame(width: geo.size.width * player.progress)
            }
        }
        .frame(height: 4)
        .padding(.horizontal)
    }

    @ViewBuilder private var controls: some View {
        if player.state == .playing && !reduceMotion {
            MusicLoadingView(title: nil, tint: .white)
                .frame(height: 42)
        } else {
            Color.clear.frame(height: 42)
        }
        Button {
            Task { await player.toggle(entry) }
        } label: {
            Image(systemName: playPauseIcon)
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
        }
        .accessibilityLabel(player.state == .playing ? "Pause" : "Play")
    }

    private var readStoryButton: some View {
        Button(action: onAdvance) {
            Label("Read today's story", systemImage: "arrow.down")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white.opacity(0.18))
        .foregroundStyle(.white)
    }

    private var playPauseIcon: String {
        switch player.state {
        case .playing:  "pause.circle.fill"
        case .finished: "arrow.counterclockwise.circle.fill"
        default:        "play.circle.fill"
        }
    }
}
```

- [ ] **Step 2: Build**

Run the **Build** command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/ListeningView.swift"
git commit -m "feat(audio): add immersive ListeningView"
```

---

### Task 8: Present `ListeningView` from `TodayView` (ceremony + toggle)

Auto-open the listen the first time today's drop is encountered; flow to Today on advance; keep a "Listen" toolbar button so the user can go back any time.

**Files:**
- Modify: `Daily Music/Views/TodayView.swift`

- [ ] **Step 1: Add state** to `TodayView` (near the existing `@State` lines):

```swift
    @State private var showingSettings = false   // drives the Settings sheet
    @State private var showingListening = false  // drives the immersive listen cover
    @AppStorage("heardEntryID") private var heardEntryID = ""  // last entry the user listened to
```

- [ ] **Step 2: Add a computed `loadedEntry`** (place it among the other private computed properties):

```swift
    private var loadedEntry: DailyEntry? {
        if case .loaded(let entry) = model?.state { return entry }
        return nil
    }
```

- [ ] **Step 3: Attach the cover + auto-open + the "Listen" toolbar button** to the `NavigationStack`'s `Group`. After the existing `.sheet(isPresented: $showingSettings) { SettingsView() }` modifier, add:

```swift
            .fullScreenCover(isPresented: $showingListening) {
                if let entry = loadedEntry {
                    ListeningView(entry: entry) {
                        heardEntryID = entry.id.uuidString
                        showingListening = false
                    }
                }
            }
            .onChange(of: loadedEntry?.id) { _, _ in
                guard let entry = loadedEntry else { return }
                let heard = heardEntryID.isEmpty ? nil : heardEntryID
                if ListeningCeremony.shouldAutoOpen(todayEntryID: entry.id, heardEntryID: heard) {
                    showingListening = true
                }
            }
```

Add a "Listen" button to the toolbar. Inside the existing `.toolbar { ... }`, alongside the trailing live badge item, add another trailing item:

```swift
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingListening = true
                    } label: {
                        Image(systemName: "headphones")
                    }
                    .accessibilityLabel("Listen")
                    .disabled(loadedEntry == nil)
                }
```

- [ ] **Step 4: Build**

Run the **Build** command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/TodayView.swift"
git commit -m "feat(audio): first-listen ceremony + Listen toggle in TodayView"
```

---

### Task 9: Full verification (tests + simulator walkthrough)

**Files:** none (verification only)

- [ ] **Step 1: Run the whole test suite**

Run the **Test** command. Expected: PASS — all `PlaybackTests`, `CatalogInfoTests`, and the existing suite green.

- [ ] **Step 2: Mock-environment ceremony (no network/audio needed)**

Launch the app in the simulator with the DEBUG mock environment (`dev_useMock` ON via the SignInView DEBUG toggle, or the `@AppStorage("dev_useMock")` switch). Sign in / continue. Expected:
- On first reach of Today, the immersive **ListeningView** auto-presents and the progress bar advances (the mock simulates a ~6s clip).
- After ~6s it reports finished; ~0.8s later it dismisses into the **Today** journal screen.
- Re-open the app or tap the **headphones** toolbar button → ListeningView shows again; the play/pause control toggles state. (Reset by signing out, or clearing the `heardEntryID` default, to re-trigger the auto-open.)

- [ ] **Step 3: Live-environment real audio (device or sim with network)**

Switch to the live environment (`dev_useMock` OFF). Ensure today's `daily_entries` row has a real `apple_music_id` (a numeric iTunes/Apple catalog ID). Expected:
- ListeningView plays an audible 30-second preview, the progress bar tracks it, the audio fades out over the final ~2s, then it flows into Today.
- An entry whose ID has no preview surfaces no crash (playback fails gracefully; user can still read Today via the cover's "Read today's story").

- [ ] **Step 4: Reduce Motion pass**

Enable Settings → Accessibility → Motion → Reduce Motion. Expected: the equalizer/breathing animations are suppressed in ListeningView; playback + auto-advance still work.

- [ ] **Step 5: Commit (if any tweaks were needed)**

```bash
git add -A
git commit -m "test(audio): verify listening ceremony + preview playback"
```

---

## Self-review notes (author)

- **Spec coverage:** Implements the spec's "iTunes preview audio bridge" (Phase 0) and the "snippet-as-taste / fade-not-cut" audio reframe (volume fade + the immersive moment). The Listening ceremony realizes the "first-listen ceremony, then your choice" decision. Onboarding taste-seed and the optional daily reflection remain separate Phase-0 plans (noted in scope) — intentionally out of this plan.
- **Type consistency:** `MusicEngine` (now `AnyObject`) gains `onProgress: ((TimeInterval, TimeInterval) -> Void)?` and `onFinish: (() -> Void)?`, implemented by `MockMusicEngine`, `MusicKitMusicEngine`, `PreviewMusicEngine`, and the test `FakeEngine`. `PlaybackState.finished`, `MusicPlayer.elapsed/duration/progress`, and `ListeningCeremony.shouldAutoOpen(todayEntryID:heardEntryID:)` are referenced consistently across tasks. `CatalogInfo.previewURL` is added with a default so existing call sites are unaffected.
- **Known limitation:** `PreviewMusicEngine.addToDailyPlaylist` throws `addToPlaylistUnavailable` — library writes need MusicKit (paid account). The existing "Add to Daily Playlist" UI already surfaces thrown errors; full support returns when `MusicKitMusicEngine` is activated at launch (swap one line in `live()`).
