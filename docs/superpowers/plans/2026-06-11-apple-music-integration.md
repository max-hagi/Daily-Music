# Apple Music Deep Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apple Music subscribers get full-track playback, save-to-playlist, and richer metadata — shipped dormant behind a feature flag (no paid dev account yet) — while everyone else keeps today's preview experience untouched.

**Architecture:** A connection layer (`MusicServiceConnection` protocol + `AppleMusicSession` @Observable) reports capabilities. `MusicPlayer` gains a second optional engine (`FullTrackMusicEngine`, `ApplicationMusicPlayer`-based) and routes per `PlaybackContext` (`.standard` → full track when capable, `.sample` → always preview), falling back to previews on any failure. Spec: `docs/superpowers/specs/2026-06-11-apple-music-integration-design.md`.

**Tech Stack:** SwiftUI, MusicKit, AVFoundation, Swift Testing (`import Testing`, `@Test`, `#expect`), UserDefaults persistence.

**Branch:** `feature/apple-music-integration` (already created; spec committed).

---

## Build & test commands

The system `xcode-select` points at CommandLineTools, so every `xcodebuild` needs `DEVELOPER_DIR`:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Full test suite
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20

# One suite only (faster inner loop)
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/AppleMusicSessionTests" 2>&1 | tail -20

# Build only
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

The Xcode project uses file-system-synchronized groups — **new `.swift` files dropped into the source folders are picked up automatically**, no pbxproj editing.

**Important environment caveats:**
- MusicKit code **compiles** without the entitlement; it only fails at **runtime**. `FullTrackMusicEngine` and `MusicKitAuthorizer` therefore get build verification, not runtime verification — that's explicitly deferred until the paid account exists.
- If Xcode (the app) is open, it may delete `Daily Music.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` from the working copy. It's committed; `git checkout -- "Daily Music.xcodeproj"` restores it. Don't commit its deletion.
- Tests are Swift Testing style (NOT XCTest): `import Testing`, `@MainActor struct XTests`, `@Test func …`, `#expect(…)`.

## File structure

| File | Action | Responsibility |
|---|---|---|
| `Daily Music/App/FeatureFlags.swift` | Create | Compile-time flags; `appleMusicConnect = false` gates all Connect UI |
| `Daily Music/Services/Music/MusicServiceConnection.swift` | Create | `MusicServiceCapabilities` OptionSet, `MusicConnectionStatus`, `MusicServiceConnection` protocol |
| `Daily Music/Services/Music/AppleMusicSession.swift` | Create | `AppleMusicAuthorizing` seam, `MusicKitAuthorizer` (live), `AppleMusicSession` state machine, `MockAppleMusicAuthorizer` |
| `Daily Music/Models/SavedTracksLog.swift` | Create | UserDefaults-backed set of saved entry IDs (mirrors `CatchUpLog`) |
| `Daily Music/Services/MusicPlayer.swift` | Modify | `PlaybackContext`, two-engine routing, fallback, `isPlayingFullTrack` |
| `Daily Music/Services/Music/MusicKitMusicEngine.swift` | Delete (replaced) | — |
| `Daily Music/Services/Music/FullTrackMusicEngine.swift` | Create | `ApplicationMusicPlayer` full-track engine + playlist add + `MusicEngineError` |
| `Daily Music/Services/CatalogInfoService.swift` | Modify | `CatalogInfo` gains `editorialNotes` / `hiResArtworkURL`; add `EnrichedCatalogInfoService` decorator |
| `Daily Music/App/AppEnvironment.swift` | Modify | Own `AppleMusicSession` + `SavedTracksLog`; wire full engine + enriched catalog |
| `Daily Music/App/RootView.swift` | Modify | Silent `appleMusic.restore()` on launch |
| `Daily Music/Info.plist` | Modify | `NSAppleMusicUsageDescription` |
| `Daily Music/Views/Onboarding/TasteSeedView.swift` | Modify | Pass `.sample` context to all 4 `player.toggle` calls |
| `Daily Music/Views/EntryDetailView.swift` | Modify | `@State var saveToAppleMusicFailed` |
| `Daily Music/Views/EntryActionCluster.swift` | Modify | Save button (capability-gated, "Added ✓" state) |
| `Daily Music/Views/SongInfoSheet.swift` | Modify | Editorial-notes section when present |
| `Daily Music/Views/SettingsView.swift` | Modify | Connected-services UI driven by `env.appleMusic`, behind flag |
| `Daily Music/ViewModels/SettingsViewModel.swift` | Modify | Delete the stub `appleMusicConnected` / `connectAppleMusic()` |
| `Daily Music/Views/Onboarding/OnboardingListenStep.swift` | Modify | Optional Connect button, behind flag |
| `docs/ARCHITECTURE.md` | Modify | Player/services sections + tables |
| `Daily MusicTests/AppleMusicSessionTests.swift` | Create | Session state machine tests |
| `Daily MusicTests/MusicPlayerRoutingTests.swift` | Create | Routing policy + fallback tests |
| `Daily MusicTests/SavedTracksLogTests.swift` | Create | Persistence/idempotency tests |
| `Daily MusicTests/CatalogEnrichmentTests.swift` | Create | Decorator gating/merge tests |

---

### Task 1: Feature flag + connection types + `AppleMusicSession`

**Files:**
- Create: `Daily Music/App/FeatureFlags.swift`
- Create: `Daily Music/Services/Music/MusicServiceConnection.swift`
- Create: `Daily Music/Services/Music/AppleMusicSession.swift`
- Test: `Daily MusicTests/AppleMusicSessionTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Daily MusicTests/AppleMusicSessionTests.swift`:

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct AppleMusicSessionTests {
    /// Isolated defaults per test so persistence can't leak between tests.
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AppleMusicSessionTests-\(UUID().uuidString)")!
    }

    @Test func startsNotConnected() {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(), defaults: freshDefaults()
        )
        #expect(session.status == .notConnected)
    }

    @Test func connectWithSubscriptionGrantsAllCapabilities() async {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(subscribed: true), defaults: freshDefaults()
        )
        await session.connect()
        #expect(session.status == .connected([.fullPlayback, .librarySave, .richMetadata]))
    }

    // Library writes, like full playback, require an active subscription —
    // authorized-but-unsubscribed users only get richer metadata.
    @Test func connectWithoutSubscriptionGrantsMetadataOnly() async {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(subscribed: false), defaults: freshDefaults()
        )
        await session.connect()
        #expect(session.status == .connected([.richMetadata]))
    }

    @Test func deniedAuthorizationLeavesNotConnected() async {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(status: .denied), defaults: freshDefaults()
        )
        await session.connect()
        #expect(session.status == .notConnected)
    }

    // The launch path must never show a permission prompt.
    @Test func restoreNeverPromptsWhenUserNeverConnected() async {
        let authorizer = MockAppleMusicAuthorizer()
        let session = AppleMusicSession(authorizer: authorizer, defaults: freshDefaults())
        await session.restore()
        #expect(authorizer.requestCount == 0)
        #expect(session.status == .notConnected)
    }

    @Test func restoreRederivesStatusAfterPriorConnect() async {
        let defaults = freshDefaults()
        let authorizer = MockAppleMusicAuthorizer(subscribed: true)
        let first = AppleMusicSession(authorizer: authorizer, defaults: defaults)
        await first.connect()

        // "Next launch": new session, same defaults, already-authorized system state.
        let second = AppleMusicSession(authorizer: authorizer, defaults: defaults)
        await second.restore()
        #expect(authorizer.requestCount == 1)   // only the original connect prompted
        #expect(second.status == .connected([.fullPlayback, .librarySave, .richMetadata]))
    }

    @Test func disconnectClearsStatusAndPersistedFlag() async {
        let defaults = freshDefaults()
        let authorizer = MockAppleMusicAuthorizer(subscribed: true)
        let session = AppleMusicSession(authorizer: authorizer, defaults: defaults)
        await session.connect()
        session.disconnect()
        #expect(session.status == .notConnected)

        let next = AppleMusicSession(authorizer: authorizer, defaults: defaults)
        await next.restore()
        #expect(next.status == .notConnected)
    }

    @Test func subscriptionLapseDowngradesCapabilitiesLive() async {
        let authorizer = MockAppleMusicAuthorizer(subscribed: true)
        let session = AppleMusicSession(authorizer: authorizer, defaults: freshDefaults())
        await session.connect()
        #expect(session.status.capabilities.contains(.fullPlayback))

        authorizer.sendSubscriptionUpdate(false)
        try? await Task.sleep(for: .milliseconds(100))   // let the watcher task run
        #expect(session.status == .connected([.richMetadata]))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail to compile**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/AppleMusicSessionTests" 2>&1 | tail -20
```

Expected: build FAILS — `AppleMusicSession`, `MockAppleMusicAuthorizer` not found.

- [ ] **Step 3: Create `Daily Music/App/FeatureFlags.swift`**

```swift
//
//  FeatureFlags.swift
//  Daily Music
//
//  Compile-time switches for features that ship dormant.
//

enum FeatureFlags {
    /// Gates every "Connect Apple Music" surface (Settings, onboarding) and the
    /// live full-track engine. Flip to true once the paid Apple Developer
    /// account provisions the MusicKit entitlement — see the activation
    /// checklist in FullTrackMusicEngine.swift.
    static let appleMusicConnect = false
}
```

- [ ] **Step 4: Create `Daily Music/Services/Music/MusicServiceConnection.swift`**

```swift
//
//  MusicServiceConnection.swift
//  Daily Music
//
//  The "connected services" shape: what a linked streaming account can do for
//  us. AppleMusicSession is the only implementation today; a future
//  SpotifySession would report just .librarySave (Spotify offers no
//  third-party in-app playback).
//

import Foundation

struct MusicServiceCapabilities: OptionSet, Equatable {
    let rawValue: Int

    /// Full songs in-app (Apple Music: requires an active subscription).
    static let fullPlayback = MusicServiceCapabilities(rawValue: 1 << 0)
    /// Save tracks to the user's library / our playlist (also subscription-gated).
    static let librarySave  = MusicServiceCapabilities(rawValue: 1 << 1)
    /// Editorial notes, hi-res artwork, and other catalog extras.
    static let richMetadata = MusicServiceCapabilities(rawValue: 1 << 2)
}

enum MusicConnectionStatus: Equatable {
    case notConnected
    case connected(MusicServiceCapabilities)

    /// Convenience so call sites read `status.capabilities.contains(.x)`.
    var capabilities: MusicServiceCapabilities {
        if case .connected(let caps) = self { return caps }
        return []
    }
}

@MainActor
protocol MusicServiceConnection: AnyObject {
    var service: StreamingService { get }
    var status: MusicConnectionStatus { get }
    func connect() async
    func disconnect()
}
```

- [ ] **Step 5: Create `Daily Music/Services/Music/AppleMusicSession.swift`**

```swift
//
//  AppleMusicSession.swift
//  Daily Music
//
//  Connection state machine for Apple Music. MusicKit's static APIs are
//  wrapped behind AppleMusicAuthorizing so the machine is unit-testable and
//  the simulator/mock environment can fake any state without the entitlement.
//
//  The persisted "user connected" flag means: the user explicitly tapped
//  Connect at some point. On launch, restore() silently re-derives status —
//  it never triggers the system permission prompt.
//

import Foundation
import MusicKit

enum AppleMusicAuthStatus {
    case notDetermined
    case authorized
    case denied
}

/// Seam over MusicKit's statics (MusicAuthorization / MusicSubscription).
protocol AppleMusicAuthorizing: Sendable {
    func currentStatus() -> AppleMusicAuthStatus
    func requestAuthorization() async -> AppleMusicAuthStatus
    func hasActiveSubscription() async -> Bool
    /// Emits whenever subscription state may have changed
    /// (true = can play full catalog tracks).
    func subscriptionUpdates() -> AsyncStream<Bool>
}

/// Live MusicKit-backed implementation. Compiles without the entitlement;
/// at runtime, authorization simply fails until the paid account enables it.
struct MusicKitAuthorizer: AppleMusicAuthorizing {
    func currentStatus() -> AppleMusicAuthStatus {
        map(MusicAuthorization.currentStatus)
    }

    func requestAuthorization() async -> AppleMusicAuthStatus {
        map(await MusicAuthorization.request())
    }

    func hasActiveSubscription() async -> Bool {
        (try? await MusicSubscription.current)?.canPlayCatalogContent ?? false
    }

    func subscriptionUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task {
                for await subscription in MusicSubscription.subscriptionUpdates {
                    continuation.yield(subscription.canPlayCatalogContent)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func map(_ status: MusicAuthorization.Status) -> AppleMusicAuthStatus {
        switch status {
        case .authorized:    .authorized
        case .notDetermined: .notDetermined
        default:             .denied
        }
    }
}

@MainActor
@Observable
final class AppleMusicSession: MusicServiceConnection {
    let service: StreamingService = .appleMusic
    private(set) var status: MusicConnectionStatus = .notConnected
    private(set) var isConnecting = false

    private let authorizer: AppleMusicAuthorizing
    private let defaults: UserDefaults
    private static let connectedKey = "appleMusic.userConnected"
    private var updatesTask: Task<Void, Never>?

    init(authorizer: AppleMusicAuthorizing, defaults: UserDefaults = .standard) {
        self.authorizer = authorizer
        self.defaults = defaults
    }

    /// Launch path: re-derive status ONLY if the user connected before and iOS
    /// still reports us authorized. Never prompts.
    func restore() async {
        guard defaults.bool(forKey: Self.connectedKey),
              authorizer.currentStatus() == .authorized else { return }
        await refreshCapabilities()
        watchSubscription()
    }

    func connect() async {
        isConnecting = true
        defer { isConnecting = false }
        guard await authorizer.requestAuthorization() == .authorized else {
            status = .notConnected
            defaults.set(false, forKey: Self.connectedKey)
            return
        }
        defaults.set(true, forKey: Self.connectedKey)
        await refreshCapabilities()
        watchSubscription()
    }

    /// Stops the app using Apple Music. (It can't revoke the iOS permission —
    /// only Settings can — it just clears our flag and state.)
    func disconnect() {
        defaults.set(false, forKey: Self.connectedKey)
        status = .notConnected
        updatesTask?.cancel()
        updatesTask = nil
    }

    private func refreshCapabilities() async {
        apply(subscribed: await authorizer.hasActiveSubscription())
    }

    private func apply(subscribed: Bool) {
        // Library writes, like full playback, need an active subscription.
        status = .connected(subscribed
            ? [.fullPlayback, .librarySave, .richMetadata]
            : [.richMetadata])
    }

    /// A lapsed/renewed subscription downgrades/upgrades capabilities live.
    private func watchSubscription() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await canPlay in authorizer.subscriptionUpdates() {
                if Task.isCancelled { return }
                self.apply(subscribed: canPlay)
            }
        }
    }
}

/// Dev/sim/test stand-in: configurable auth + subscription, drivable
/// subscription updates, and a prompt counter for the no-silent-prompt tests.
final class MockAppleMusicAuthorizer: AppleMusicAuthorizing, @unchecked Sendable {
    var status: AppleMusicAuthStatus
    var subscribed: Bool
    private(set) var requestCount = 0
    private var subscriptionContinuation: AsyncStream<Bool>.Continuation?

    init(status: AppleMusicAuthStatus = .notDetermined, subscribed: Bool = true) {
        self.status = status
        self.subscribed = subscribed
    }

    func currentStatus() -> AppleMusicAuthStatus { status }

    func requestAuthorization() async -> AppleMusicAuthStatus {
        requestCount += 1
        if status == .notDetermined { status = .authorized }
        return status
    }

    func hasActiveSubscription() async -> Bool { subscribed }

    func subscriptionUpdates() -> AsyncStream<Bool> {
        AsyncStream { self.subscriptionContinuation = $0 }
    }

    /// Test hook: simulate a subscription change notification.
    func sendSubscriptionUpdate(_ canPlay: Bool) {
        subscriptionContinuation?.yield(canPlay)
    }
}
```

- [ ] **Step 6: Run the tests, verify they pass**

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/AppleMusicSessionTests" 2>&1 | tail -20
```

Expected: all 8 tests PASS. If `subscriptionLapseDowngradesCapabilitiesLive` flakes, bump the sleep to 200ms — the watcher task needs a beat to receive the yield.

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/App/FeatureFlags.swift" "Daily Music/Services/Music/MusicServiceConnection.swift" \
  "Daily Music/Services/Music/AppleMusicSession.swift" "Daily MusicTests/AppleMusicSessionTests.swift"
git commit -m "feat(music): add Apple Music connection layer behind feature flag"
```

---

### Task 2: `SavedTracksLog`

**Files:**
- Create: `Daily Music/Models/SavedTracksLog.swift`
- Test: `Daily MusicTests/SavedTracksLogTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Daily MusicTests/SavedTracksLogTests.swift`:

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct SavedTracksLogTests {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SavedTracksLogTests-\(UUID().uuidString)")!
    }

    private func sampleEntry() -> DailyEntry {
        DailyEntry(
            id: UUID(), date: Date(), title: "Nobody", artist: "Mitski",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "123",
            spotifyURI: "spotify:track:123"
        )
    }

    @Test func entriesStartUnsaved() {
        let log = SavedTracksLog(defaults: freshDefaults())
        #expect(!log.isSaved(sampleEntry()))
    }

    @Test func markSavedSticksAndPersistsAcrossInstances() {
        let defaults = freshDefaults()
        let entry = sampleEntry()
        let log = SavedTracksLog(defaults: defaults)
        log.markSaved(entry)
        #expect(log.isSaved(entry))

        let reloaded = SavedTracksLog(defaults: defaults)
        #expect(reloaded.isSaved(entry))
    }

    @Test func markSavedIsIdempotent() {
        let defaults = freshDefaults()
        let entry = sampleEntry()
        let log = SavedTracksLog(defaults: defaults)
        log.markSaved(entry)
        log.markSaved(entry)
        let stored = defaults.stringArray(forKey: "appleMusic.savedEntryIDs") ?? []
        #expect(stored.count == 1)
    }
}
```

- [ ] **Step 2: Run, verify compile failure** (same `-only-testing:"Daily MusicTests/SavedTracksLogTests"` invocation). Expected: FAIL — `SavedTracksLog` not found.

- [ ] **Step 3: Create `Daily Music/Models/SavedTracksLog.swift`**

Mirrors `CatchUpLog` (`Daily Music/Models/CatchUp.swift:46`):

```swift
//
//  SavedTracksLog.swift
//  Daily Music
//
//  Which entries the user already saved to their Apple Music playlist, so the
//  save button shows "Added" and we never double-add. UserDefaults-backed,
//  same pattern as CatchUpLog.
//

import Foundation

@MainActor
@Observable
final class SavedTracksLog {
    private(set) var savedEntryIDs: Set<UUID>

    private let defaults: UserDefaults
    private static let key = "appleMusic.savedEntryIDs"
    /// One save per daily entry — a year of daily saves fits comfortably.
    private static let maxStored = 400

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Self.key) ?? []
        savedEntryIDs = Set(stored.compactMap(UUID.init(uuidString:)))
    }

    func isSaved(_ entry: DailyEntry) -> Bool {
        savedEntryIDs.contains(entry.id)
    }

    func markSaved(_ entry: DailyEntry) {
        guard !savedEntryIDs.contains(entry.id) else { return }
        savedEntryIDs.insert(entry.id)
        var stored = defaults.stringArray(forKey: Self.key) ?? []
        stored.append(entry.id.uuidString)
        if stored.count > Self.maxStored {
            stored.removeFirst(stored.count - Self.maxStored)
        }
        defaults.set(stored, forKey: Self.key)
    }
}
```

- [ ] **Step 4: Run tests, verify PASS.**

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/SavedTracksLog.swift" "Daily MusicTests/SavedTracksLogTests.swift"
git commit -m "feat(music): add SavedTracksLog for playlist-save state"
```

---

### Task 3: `PlaybackContext` + two-engine routing in `MusicPlayer`

**Files:**
- Modify: `Daily Music/Services/MusicPlayer.swift`
- Modify: `Daily Music/Views/Onboarding/TasteSeedView.swift` (4 call sites: lines ~76, ~88, ~287, ~294)
- Test: `Daily MusicTests/MusicPlayerRoutingTests.swift`

Existing behavior must not change: `MusicPlayer(engine:)` with no full engine routes everything to that engine, and all existing `PlaybackTests` keep passing unmodified.

- [ ] **Step 1: Write the failing tests**

Create `Daily MusicTests/MusicPlayerRoutingTests.swift`:

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct MusicPlayerRoutingTests {
    final class FakeEngine: MusicEngine {
        var onProgress: ((TimeInterval, TimeInterval) -> Void)?
        var onFinish: (() -> Void)?
        var shouldThrowOnPlay = false
        private(set) var playCalls = 0
        private(set) var pauseCalls = 0
        private(set) var resumeCalls = 0
        func play(appleMusicID: String) async throws {
            playCalls += 1
            if shouldThrowOnPlay { throw MusicEngineError.songNotFound }
        }
        func pause() async { pauseCalls += 1 }
        func resume() async { resumeCalls += 1 }
        func stop() async {}
        func seek(to seconds: TimeInterval) async {}
        func addToDailyPlaylist(appleMusicID: String) async throws {}
    }

    private func sampleEntry() -> DailyEntry {
        DailyEntry(
            id: UUID(), date: Date(), title: "Nobody", artist: "Mitski",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "123",
            spotifyURI: "spotify:track:123"
        )
    }

    private func session(subscribed: Bool) async -> AppleMusicSession {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(subscribed: subscribed),
            defaults: UserDefaults(suiteName: "MusicPlayerRoutingTests-\(UUID().uuidString)")!
        )
        await session.connect()
        return session
    }

    @Test func standardContextUsesFullEngineWhenSubscribed() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: true))
        await player.toggle(sampleEntry(), context: .standard)
        #expect(full.playCalls == 1)
        #expect(preview.playCalls == 0)
        #expect(player.isPlayingFullTrack)
    }

    @Test func sampleContextAlwaysUsesPreviewEngine() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: true))
        await player.toggle(sampleEntry(), context: .sample)
        #expect(preview.playCalls == 1)
        #expect(full.playCalls == 0)
        #expect(!player.isPlayingFullTrack)
    }

    @Test func previewEngineUsedWithoutConnection() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: nil)
        await player.toggle(sampleEntry(), context: .standard)
        #expect(preview.playCalls == 1)
        #expect(full.playCalls == 0)
    }

    @Test func previewEngineUsedWhenConnectedWithoutSubscription() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: false))
        await player.toggle(sampleEntry(), context: .standard)
        #expect(preview.playCalls == 1)
        #expect(full.playCalls == 0)
    }

    // Region gaps / network / revoked auth: the SAME call lands on previews.
    @Test func fullEngineFailureFallsBackToPreviewInSameCall() async {
        let preview = FakeEngine(); let full = FakeEngine()
        full.shouldThrowOnPlay = true
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: true))
        await player.toggle(sampleEntry(), context: .standard)
        #expect(full.playCalls == 1)
        #expect(preview.playCalls == 1)
        #expect(player.state == .playing)
        #expect(!player.isPlayingFullTrack)
    }

    @Test func pauseAndResumeTargetTheActiveEngine() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: true))
        let entry = sampleEntry()
        await player.toggle(entry, context: .standard)   // full engine plays
        await player.toggle(entry, context: .standard)   // pause
        #expect(full.pauseCalls == 1)
        #expect(preview.pauseCalls == 0)
        await player.toggle(entry, context: .standard)   // resume
        #expect(full.resumeCalls == 1)
        #expect(preview.resumeCalls == 0)
    }

    // Progress/finish callbacks must work whichever engine is active.
    @Test func fullEngineCallbacksDriveState() async {
        let preview = FakeEngine(); let full = FakeEngine()
        let player = MusicPlayer(engine: preview, fullEngine: full, appleMusic: await session(subscribed: true))
        await player.toggle(sampleEntry(), context: .standard)
        full.onProgress?(60, 240)
        #expect(player.elapsed == 60)
        #expect(player.duration == 240)
        full.onFinish?()
        #expect(player.state == .finished)
    }
}
```

- [ ] **Step 2: Run, verify compile failure** (`-only-testing:"Daily MusicTests/MusicPlayerRoutingTests"`). Expected: FAIL — no `fullEngine:`/`appleMusic:` init params, no `context:` param.

- [ ] **Step 3: Modify `Daily Music/Services/MusicPlayer.swift`**

Add the context enum above `MusicPlayer` (after the `MusicEngine` protocol):

```swift
/// Which experience a play request belongs to — the routing key for full
/// tracks vs previews. Policy lives here (in the player), mechanism in engines.
enum PlaybackContext {
    /// Ceremony, entry detail, vault replays: full track when available.
    case standard
    /// Taste-seed swipe deck: always a snappy 30-sec preview.
    case sample
}
```

Replace `MusicPlayer`'s stored engine, init, `toggle`, `restart`, `startFresh`, and engine-touching methods:

```swift
@MainActor
@Observable
final class MusicPlayer {
    private(set) var state: PlaybackState = .idle
    private(set) var nowPlayingEntryID: UUID?
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    /// True while the active clip is a full track (vs a 30-sec preview), so
    /// player UI can set expectations.
    private(set) var isPlayingFullTrack = false

    var progress: Double {
        duration > 0 ? min(1, max(0, elapsed / duration)) : 0
    }

    private let previewEngine: MusicEngine
    private let fullEngine: MusicEngine?
    private let appleMusic: (any MusicServiceConnection)?
    /// Whichever engine the current clip is on; pause/resume/seek/stop target it.
    private var activeEngine: MusicEngine

    init(
        engine: MusicEngine,
        fullEngine: MusicEngine? = nil,
        appleMusic: (any MusicServiceConnection)? = nil
    ) {
        self.previewEngine = engine
        self.fullEngine = fullEngine
        self.appleMusic = appleMusic
        self.activeEngine = engine
        for candidate in [engine, fullEngine].compactMap({ $0 }) {
            candidate.onProgress = { [weak self] elapsed, duration in
                self?.elapsed = elapsed
                self?.duration = duration
            }
            candidate.onFinish = { [weak self] in
                guard let self else { return }
                self.elapsed = self.duration
                self.state = .finished
            }
        }
    }

    func isPlaying(_ entry: DailyEntry) -> Bool {
        nowPlayingEntryID == entry.id && state == .playing
    }

    func toggle(_ entry: DailyEntry, context: PlaybackContext = .standard) async {
        if nowPlayingEntryID == entry.id {
            switch state {
            case .playing:
                await activeEngine.pause()
                state = .paused
            case .paused:
                await activeEngine.resume()
                state = .playing
            case .finished:
                await startFresh(entry, context: context)
            case .idle, .buffering:
                break
            }
        } else {
            await startFresh(entry, context: context)
        }
    }

    func restart(_ entry: DailyEntry, context: PlaybackContext = .standard) async {
        switch state {
        case .playing:
            await seek(to: 0)
        case .paused:
            await seek(to: 0)
            await activeEngine.resume()
            state = .playing
        default:
            await startFresh(entry, context: context)
        }
    }

    /// Routing policy: full engine only for .standard when the connected
    /// service grants .fullPlayback; ANY full-engine failure falls back to the
    /// preview engine in the same call. Previews are the universal floor.
    private func startFresh(_ entry: DailyEntry, context: PlaybackContext) async {
        nowPlayingEntryID = entry.id
        elapsed = 0
        state = .buffering

        if let fullEngine, context == .standard,
           appleMusic?.status.capabilities.contains(.fullPlayback) == true {
            await previewEngine.stop()   // never two engines audible at once
            do {
                try await fullEngine.play(appleMusicID: entry.appleMusicID)
                activeEngine = fullEngine
                isPlayingFullTrack = true
                state = .playing
                return
            } catch {
                // Fall through to previews — silent by design.
            }
        }

        await fullEngine?.stop()
        do {
            try await previewEngine.play(appleMusicID: entry.appleMusicID)
            activeEngine = previewEngine
            isPlayingFullTrack = false
            state = .playing
        } catch {
            state = .idle
            nowPlayingEntryID = nil
        }
    }

    func stop() async {
        await activeEngine.stop()
        state = .idle
        nowPlayingEntryID = nil
        elapsed = 0
        duration = 0
        isPlayingFullTrack = false
    }

    func seek(to seconds: TimeInterval) async {
        guard duration > 0 else { return }
        let clamped = min(max(0, seconds), duration)
        elapsed = clamped
        await activeEngine.seek(to: clamped)
    }

    /// Library writes go to the full engine when wired (it owns MusicKit);
    /// otherwise the preview engine's clear "needs Apple Music" error surfaces.
    func addToDailyPlaylist(_ entry: DailyEntry) async throws {
        try await (fullEngine ?? previewEngine).addToDailyPlaylist(appleMusicID: entry.appleMusicID)
    }
}
```

Keep the existing header comment, `PlaybackState`, `MusicEngine` protocol, and `MockMusicEngine` in the file unchanged.

- [ ] **Step 4: Update the 4 taste-seed call sites in `Daily Music/Views/Onboarding/TasteSeedView.swift`**

Each `await player.toggle(song)` / `await player.toggle(next)` becomes `await player.toggle(song, context: .sample)` / `await player.toggle(next, context: .sample)` (lines ~76, ~88, ~287, ~294 — grep `player.toggle` to find them all).

- [ ] **Step 5: Run BOTH playback suites, verify all pass**

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/MusicPlayerRoutingTests" \
  -only-testing:"Daily MusicTests/PlaybackTests" 2>&1 | tail -20
```

Expected: all PASS — including the untouched `PlaybackTests` (regression guard: single-engine behavior identical).

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Services/MusicPlayer.swift" "Daily Music/Views/Onboarding/TasteSeedView.swift" \
  "Daily MusicTests/MusicPlayerRoutingTests.swift"
git commit -m "feat(music): route playback across preview/full engines by context"
```

---

### Task 4: `FullTrackMusicEngine` (replaces `MusicKitMusicEngine`)

**Files:**
- Delete: `Daily Music/Services/Music/MusicKitMusicEngine.swift`
- Create: `Daily Music/Services/Music/FullTrackMusicEngine.swift`

No unit tests — MusicKit can't run without the entitlement; verification is build-only here, runtime verification is deferred to the activation checklist. `MusicEngineError` moves to the new file (PreviewMusicEngine references it).

- [ ] **Step 1: Delete the old file, create `Daily Music/Services/Music/FullTrackMusicEngine.swift`**

```bash
git rm "Daily Music/Services/Music/MusicKitMusicEngine.swift"
```

```swift
//
//  FullTrackMusicEngine.swift
//  Daily Music
//
//  The real Apple Music engine: full-track playback via ApplicationMusicPlayer
//  (which gives lock-screen + Control Center transport for free) and saving
//  tracks to a "Daily Music" library playlist. Both require the user to hold
//  an active Apple Music subscription — AppleMusicSession gates that via
//  capabilities, and MusicPlayer falls back to previews on any throw here.
//
//  ──────────────────────────────────────────────────────────────────────────
//  ACTIVATION CHECKLIST (needs the paid Apple Developer account):
//   1. Xcode → target "Daily Music" → Signing & Capabilities → + MusicKit.
//   2. FeatureFlags.appleMusicConnect = true.
//   3. Verify NSAppleMusicUsageDescription is in Daily Music/Info.plist.
//   4. Test on a REAL iPhone signed into an Apple ID with a subscription
//      (Simulator can't play Apple Music): connect flow, full playback,
//      pause/resume/seek, playlist add, lock-screen controls.
//  ──────────────────────────────────────────────────────────────────────────
//

import Foundation
import MusicKit

final class FullTrackMusicEngine: MusicEngine {
    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onFinish: (() -> Void)?

    private static let playlistName = "Daily Music"
    private var progressTask: Task<Void, Never>?
    private var trackDuration: TimeInterval = 0
    private var reportedFinish = false

    private var player: ApplicationMusicPlayer { .shared }

    // MARK: MusicEngine

    func play(appleMusicID: String) async throws {
        try await ensureAuthorized()
        let song = try await fetchSong(id: appleMusicID)
        trackDuration = song.duration ?? 0
        player.queue = ApplicationMusicPlayer.Queue(for: [song])
        try await player.play()
        startProgressTask()
    }

    func pause() async {
        player.pause()
        progressTask?.cancel()
    }

    func resume() async {
        try? await player.play()   // resumes the queued item from its position
        startProgressTask()
    }

    func stop() async {
        progressTask?.cancel()
        progressTask = nil
        player.stop()
        trackDuration = 0
    }

    func seek(to seconds: TimeInterval) async {
        player.playbackTime = seconds
    }

    func addToDailyPlaylist(appleMusicID: String) async throws {
        try await ensureAuthorized()
        let song = try await fetchSong(id: appleMusicID)
        let existing = try await MusicLibraryRequest<Playlist>().response().items
        if let playlist = existing.first(where: { $0.name == Self.playlistName }) {
            try await MusicLibrary.shared.add(song, to: playlist)
        } else {
            _ = try await MusicLibrary.shared.createPlaylist(name: Self.playlistName, items: [song])
        }
    }

    // MARK: Helpers

    /// ApplicationMusicPlayer exposes no progress callback — poll playbackTime
    /// ~5×/sec (same cadence the preview engine reports at) and synthesize the
    /// finish event when we reach the end of the track.
    private func startProgressTask() {
        progressTask?.cancel()
        reportedFinish = false
        progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = self.player.playbackTime
                let duration = self.trackDuration
                if duration > 0 {
                    self.onProgress?(elapsed, duration)
                    if elapsed >= duration - 0.25, !self.reportedFinish {
                        self.reportedFinish = true
                        self.onFinish?()
                        return
                    }
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func ensureAuthorized() async throws {
        if MusicAuthorization.currentStatus == .authorized { return }
        let status = await MusicAuthorization.request()
        guard status == .authorized else { throw MusicEngineError.notAuthorized }
    }

    private func fetchSong(id: String) async throws -> Song {
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(id))
        let response = try await request.response()
        guard let song = response.items.first else { throw MusicEngineError.songNotFound }
        return song
    }
}

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
        case .addToPlaylistUnavailable: "Saving to your library needs Apple Music. Use \"Open in…\" for now."
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED. (If `ApplicationMusicPlayer.Queue(for:)` or `player.stop()` signatures mismatch the SDK, fix to the compiler's suggestion — e.g. `player.queue = [song]` also works; `pause()` + clearing queue replaces `stop()` if unavailable.)

- [ ] **Step 3: Commit**

```bash
git add -A "Daily Music/Services/Music/"
git commit -m "feat(music): replace dormant MusicKit engine with full-track ApplicationMusicPlayer engine"
```

---

### Task 5: Catalog enrichment (`CatalogInfo` + decorator)

**Files:**
- Modify: `Daily Music/Services/CatalogInfoService.swift`
- Test: `Daily MusicTests/CatalogEnrichmentTests.swift`

The MusicKit fetch is injected as a closure so the decorator's gating + merge logic is fully testable without MusicKit.

- [ ] **Step 1: Write the failing tests**

Create `Daily MusicTests/CatalogEnrichmentTests.swift`:

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct CatalogEnrichmentTests {
    struct StubBase: CatalogInfoService {
        func info(appleMusicID: String) async throws -> CatalogInfo {
            CatalogInfo(album: "Puberty 2", releaseYear: "2016", durationSeconds: 193,
                        genre: "Alternative", albumURL: nil, previewURL: nil)
        }
    }

    private func session(connected: Bool) async -> AppleMusicSession {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(subscribed: false),  // .richMetadata only
            defaults: UserDefaults(suiteName: "CatalogEnrichmentTests-\(UUID().uuidString)")!
        )
        if connected { await session.connect() }
        return session
    }

    @Test func notConnectedReturnsBaseInfoAndSkipsExtras() async throws {
        var extrasCalls = 0
        let service = EnrichedCatalogInfoService(
            base: StubBase(), session: await session(connected: false),
            fetchExtras: { _ in extrasCalls += 1; return nil }
        )
        let info = try await service.info(appleMusicID: "123")
        #expect(extrasCalls == 0)
        #expect(info.editorialNotes == nil)
        #expect(info.album == "Puberty 2")   // base facts untouched
    }

    @Test func connectedMergesExtrasOntoBaseInfo() async throws {
        let service = EnrichedCatalogInfoService(
            base: StubBase(), session: await session(connected: true),
            fetchExtras: { _ in
                CatalogExtras(editorialNotes: "A fuzzed-out meditation on joy.",
                              hiResArtworkURL: URL(string: "https://example.com/art.jpg"))
            }
        )
        let info = try await service.info(appleMusicID: "123")
        #expect(info.editorialNotes == "A fuzzed-out meditation on joy.")
        #expect(info.hiResArtworkURL == URL(string: "https://example.com/art.jpg"))
        #expect(info.album == "Puberty 2")
    }

    @Test func extrasFailureStillReturnsBaseInfo() async throws {
        let service = EnrichedCatalogInfoService(
            base: StubBase(), session: await session(connected: true),
            fetchExtras: { _ in nil }   // MusicKit fetch failed
        )
        let info = try await service.info(appleMusicID: "123")
        #expect(info.editorialNotes == nil)
        #expect(info.album == "Puberty 2")
    }
}
```

- [ ] **Step 2: Run, verify compile failure** (`-only-testing:"Daily MusicTests/CatalogEnrichmentTests"`). Expected: FAIL — `EnrichedCatalogInfoService` / `CatalogExtras` not found.

- [ ] **Step 3: Modify `Daily Music/Services/CatalogInfoService.swift`**

Add two optional fields to `CatalogInfo` (after `previewURL`):

```swift
    // MusicKit-only extras — nil on the universal iTunes path, so the info
    // sheet renders identically for non-connected users. The `= nil` defaults
    // keep every existing memberwise-init call site compiling unchanged.
    var editorialNotes: String? = nil
    var hiResArtworkURL: URL? = nil
```

(`CatalogInfo.parse` is unchanged — the new fields stay nil on the iTunes path. `CatalogInfoTests` and `MockCatalogInfoService` need no edits.)

Append the extras model + decorator at the end of the file:

```swift
/// The MusicKit-only facts layered onto the free iTunes lookup.
struct CatalogExtras {
    var editorialNotes: String?
    var hiResArtworkURL: URL?
}

/// Decorates the universal iTunes lookup with MusicKit extras when the user's
/// Apple Music connection grants .richMetadata. The MusicKit call is injected
/// so the gating/merge logic is testable without the entitlement.
struct EnrichedCatalogInfoService: CatalogInfoService {
    let base: CatalogInfoService
    let session: AppleMusicSession
    var fetchExtras: (String) async -> CatalogExtras? = EnrichedCatalogInfoService.musicKitExtras

    func info(appleMusicID: String) async throws -> CatalogInfo {
        var info = try await base.info(appleMusicID: appleMusicID)
        guard await MainActor.run(body: { session.status.capabilities.contains(.richMetadata) })
        else { return info }
        if let extras = await fetchExtras(appleMusicID) {
            info.editorialNotes = extras.editorialNotes
            info.hiResArtworkURL = extras.hiResArtworkURL
        }
        return info
    }
}
```

Add the live MusicKit fetch in the same file (top needs `import MusicKit` — add it below `import Foundation`):

```swift
extension EnrichedCatalogInfoService {
    /// Live MusicKit fetch. Any failure returns nil — the base info stands alone.
    static func musicKitExtras(appleMusicID: String) async -> CatalogExtras? {
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(appleMusicID))
        guard let song = try? await request.response().items.first else { return nil }
        return CatalogExtras(
            editorialNotes: song.editorialNotes?.standard ?? song.editorialNotes?.short,
            hiResArtworkURL: song.artwork?.url(width: 1200, height: 1200)
        )
    }
}
```

- [ ] **Step 4: Run the new suite + the existing `CatalogInfoTests`, verify all pass.**

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/CatalogInfoService.swift" "Daily MusicTests/CatalogEnrichmentTests.swift"
git commit -m "feat(music): enrich catalog info with MusicKit extras when connected"
```

---

### Task 6: Wire it all in `AppEnvironment` + launch restore + Info.plist

**Files:**
- Modify: `Daily Music/App/AppEnvironment.swift`
- Modify: `Daily Music/App/RootView.swift`
- Modify: `Daily Music/Info.plist`

- [ ] **Step 1: Modify `AppEnvironment`**

Add stored properties (after `catchUpLog`):

```swift
    let appleMusic: AppleMusicSession
    let savedTracks: SavedTracksLog
```

Change the init signature — add two params after `musicEngine: MusicEngine`:

```swift
        musicEngine: MusicEngine,
        fullMusicEngine: MusicEngine? = nil,
        appleMusicAuthorizer: AppleMusicAuthorizing
```

In the init body, build the session BEFORE the player and pass it in (replace the current `self.musicPlayer = MusicPlayer(engine: musicEngine)` line):

```swift
        self.appleMusic = AppleMusicSession(authorizer: appleMusicAuthorizer)
        self.savedTracks = SavedTracksLog()
        self.musicPlayer = MusicPlayer(
            engine: musicEngine,
            fullEngine: fullMusicEngine,
            appleMusic: appleMusic
        )
```

In `mock()`, add to the call (full connected experience explorable in the simulator — mock authorizer auto-authorizes + subscribes on connect):

```swift
            musicEngine: MockMusicEngine(),
            fullMusicEngine: MockMusicEngine(),
            appleMusicAuthorizer: MockAppleMusicAuthorizer()
```

In `live()`, the session must exist before the container to feed the enriched catalog — restructure the factory:

```swift
    static func live() -> AppEnvironment {
        let catalog = LiveCatalogInfoService()
        let appleMusicAuthorizer = MusicKitAuthorizer()
        return AppEnvironment(
            …existing args…,
            catalogInfo: catalog,
            …existing args…,
            // Free 30-sec previews via the iTunes lookup — the universal floor.
            musicEngine: PreviewMusicEngine(catalog: catalog),
            // Dormant until FeatureFlags.appleMusicConnect: no full engine means
            // routing can never leave the preview path.
            fullMusicEngine: FeatureFlags.appleMusicConnect ? FullTrackMusicEngine() : nil,
            appleMusicAuthorizer: appleMusicAuthorizer
        )
    }
```

Then, for enriched catalog info when the flag is on, change the `catalogInfo:` line. Because `EnrichedCatalogInfoService` needs the session (built inside the init), wire it INSIDE the init instead: change the init body's `self.catalogInfo = catalogInfo` to:

```swift
        // Enriched lookup decorates the base when the flag is on; the session's
        // capabilities gate it per-call, so non-connected users hit the base path.
        self.catalogInfo = FeatureFlags.appleMusicConnect
            ? EnrichedCatalogInfoService(base: catalogInfo, session: appleMusic)
            : catalogInfo
```

(Move this assignment AFTER `self.appleMusic = …` in the init body — Swift requires `appleMusic` initialized first.)

- [ ] **Step 2: Add silent restore on launch in `RootView.swift`**

Find `RootView`'s existing launch `.task` (the one calling `resolveLaunchState`) and add as its first line:

```swift
            await env.appleMusic.restore()
```

If the task's structure makes that awkward, an additional `.task { await env.appleMusic.restore() }` modifier on the root view body is equally fine — restore is idempotent and never prompts.

- [ ] **Step 3: Add the privacy string to `Daily Music/Info.plist`** (inside the top-level `<dict>`):

```xml
	<key>NSAppleMusicUsageDescription</key>
	<string>Daily Music plays your daily song and can save tracks to an Apple Music playlist for you.</string>
```

- [ ] **Step 4: Build + run the FULL test suite, verify green**

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/App/AppEnvironment.swift" "Daily Music/App/RootView.swift" "Daily Music/Info.plist"
git commit -m "feat(music): wire Apple Music session, saved-tracks log, and full engine into AppEnvironment"
```

---

### Task 7: Save-to-Apple-Music action in the entry action cluster

**Files:**
- Modify: `Daily Music/Views/EntryDetailView.swift` (state, ~line 34 by `showingInfo`)
- Modify: `Daily Music/Views/EntryActionCluster.swift`

UI task — no unit tests (consistent with the codebase; views are untested). Verification is build + mock-mode visual check.

- [ ] **Step 1: Add state to `EntryDetailView.swift`** next to `@State var showingInfo = false`:

```swift
    @State var saveToAppleMusicFailed = false
```

- [ ] **Step 2: Add the save button to `EntryActionCluster.swift`**

Add inside the `extension EntryDetailView`:

```swift
    /// Save is only offered when the connected service can write to the
    /// library (Apple Music + active subscription).
    private var canSaveToLibrary: Bool {
        env.appleMusic.status.capabilities.contains(.librarySave)
    }

    private func saveToAppleMusic() {
        guard !env.savedTracks.isSaved(entry) else { return }
        Haptics.tap()
        Task {
            do {
                try await env.musicPlayer.addToDailyPlaylist(entry)
                env.savedTracks.markSaved(entry)
            } catch {
                saveToAppleMusicFailed = true
            }
        }
    }

    private func saveButton(controlSize: CGFloat, symbolSize: CGFloat) -> some View {
        let saved = env.savedTracks.isSaved(entry)
        return Button {
            saveToAppleMusic()
        } label: {
            Image(systemName: saved ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: symbolSize, weight: .bold))
                .foregroundStyle(saved ? .green : palette.accent)
                .frame(width: controlSize, height: controlSize)
                .symbolEffect(.bounce, value: saved)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(saved)
        .accessibilityLabel(saved ? "Added to your Daily Music playlist" : "Add to your Daily Music playlist")
        .alert("Couldn't save to Apple Music", isPresented: $saveToAppleMusicFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your Apple Music connection in Settings and try again.")
        }
    }
```

(`saveToAppleMusicFailed` is `@State` on `EntryDetailView`; extensions of the view type can use its `$` projection directly — the existing cluster file does the same with `$showingReactions`.)

Insert the button into both clusters, capability-gated:

In `actionCluster` (after `heartButton`):

```swift
            heartButton
            if canSaveToLibrary {
                saveButton(controlSize: 52, symbolSize: 20)
            }
```

In `compactActions` (after `compactHeartButton`):

```swift
            compactHeartButton
            if canSaveToLibrary {
                saveButton(controlSize: 46, symbolSize: 18)
            }
```

- [ ] **Step 3: Build, then visual check in mock mode**

Build must succeed. For the visual check: `Daily_MusicApp` selects `mock()` vs `live()` — in mock mode the `MockAppleMusicAuthorizer` is wired but **not yet connected**, so the button is hidden until you tap Connect in Settings (Task 8) or temporarily pass `MockAppleMusicAuthorizer(status: .authorized)` + add `await session.connect()`. Simplest check now: build green + confirm the button hides when `status == .notConnected` (default), which is the current state. Full visual pass happens after Task 8.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/EntryDetailView.swift" "Daily Music/Views/EntryActionCluster.swift"
git commit -m "feat(music): add capability-gated save-to-playlist action to entry detail"
```

---

### Task 8: Settings — real Connected-services UI (replace the stub)

**Files:**
- Modify: `Daily Music/ViewModels/SettingsViewModel.swift` (delete stub at lines ~86-87 and ~237-242)
- Modify: `Daily Music/Views/SettingsView.swift` (`musicSection`, ~line 255)

- [ ] **Step 1: Delete the stub from `SettingsViewModel.swift`**

Remove these two blocks entirely (the real state now lives on `AppleMusicSession`):

```swift
    private(set) var appleMusicConnected = false
    private(set) var connectingAppleMusic = false
```

```swift
    func connectAppleMusic() async {
        connectingAppleMusic = true
        defer { connectingAppleMusic = false }
        try? await Task.sleep(for: .milliseconds(500))
        appleMusicConnected = true
    }
```

- [ ] **Step 2: Rewrite `musicSection` in `SettingsView.swift`**

Replace the whole `private var musicSection` with:

```swift
    private var musicSection: some View {
        @Bindable var model = model
        return Section {
            if FeatureFlags.appleMusicConnect {
                appleMusicRow
            }
            Picker("Default streaming service", selection: $model.preferredStreamingService) {
                ForEach(StreamingService.allCases) { service in
                    Text(service.displayName).tag(service)
                }
            }
        } header: {
            Text(FeatureFlags.appleMusicConnect ? "Connected services" : "Music")
        }
    }

    @ViewBuilder
    private var appleMusicRow: some View {
        let session = env.appleMusic
        switch session.status {
        case .connected(let capabilities):
            VStack(alignment: .leading, spacing: 4) {
                Label("Apple Music connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(capabilities.contains(.fullPlayback)
                     ? "Full songs, playlist saves, and richer song info."
                     : "Richer song info. Full playback needs an active subscription.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Disconnect", role: .destructive) {
                session.disconnect()
            }
        case .notConnected:
            Button {
                Task { await session.connect() }
            } label: {
                HStack {
                    Label("Connect Apple Music", systemImage: "applelogo")
                    if session.isConnecting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(session.isConnecting)
        }
    }
```

**Check:** `SettingsView` must already have `@Environment(AppEnvironment.self) private var env` (it reads `env` elsewhere — confirm with grep; if missing, add it). The old `footer:` text about MusicKit is dropped. If `model` in `musicSection` was already bindable in the existing code (check how the current Picker binds), keep the existing binding style instead of the `@Bindable` line.

- [ ] **Step 3: Build + full test suite, verify green.** Also flip `FeatureFlags.appleMusicConnect` to `true` LOCALLY (do not commit), run the app in mock mode, and verify: Connect row appears → tap → mock authorizer connects → status row shows green + capabilities line → save button appears in entry detail → Disconnect returns everything to hidden. Flip the flag back to `false`.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/ViewModels/SettingsViewModel.swift" "Daily Music/Views/SettingsView.swift"
git commit -m "feat(settings): real Apple Music connect flow behind feature flag"
```

---

### Task 9: Onboarding listen step — optional Connect button

**Files:**
- Modify: `Daily Music/Views/Onboarding/OnboardingListenStep.swift`

- [ ] **Step 1: Add the connect prompt**

In `OnboardingListenStep.swift`, locate the streaming-service selection UI (it binds `preferredStreamingService` on the shared `SettingsViewModel`). Directly below it, add:

```swift
            if FeatureFlags.appleMusicConnect,
               model.preferredStreamingService == .appleMusic {
                AppleMusicConnectPrompt()
            }
```

Add this component at the bottom of the same file:

```swift
/// Optional, skippable connect nudge for users who picked Apple Music.
/// Never blocks onboarding — it's an upgrade, not a gate.
private struct AppleMusicConnectPrompt: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let session = env.appleMusic
        Group {
            switch session.status {
            case .connected:
                Label("Apple Music connected", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            case .notConnected:
                Button {
                    Task { await session.connect() }
                } label: {
                    HStack(spacing: 8) {
                        if session.isConnecting {
                            ProgressView()
                        } else {
                            Image(systemName: "applelogo")
                        }
                        Text("Connect Apple Music for full songs")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(session.isConnecting)
            }
        }
    }
}
```

Match the step's existing visual rhythm: if surrounding controls sit on `glassCard()` or use specific paddings/foreground styles, mirror them rather than the plain styles above.

- [ ] **Step 2: Build + verify in mock mode** (flag flipped locally as in Task 8): onboarding listen step shows the prompt only when Apple Music is the picked service; connecting flips it to the green label; Finish works with and without connecting. Flip flag back.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Onboarding/OnboardingListenStep.swift"
git commit -m "feat(onboarding): optional Apple Music connect on listen step"
```

---

### Task 10: SongInfoSheet editorial notes

**Files:**
- Modify: `Daily Music/Views/SongInfoSheet.swift`

The PREVIEW pill in `ListeningView` needs **no change**: `isPreviewClip` is duration-based (`< 45s`), so full tracks naturally drop the label.

- [ ] **Step 1: Add the editorial-notes section**

In `SongInfoSheet`'s body `VStack` (currently `hero` / `quickFacts` / `curatedTags`), insert after `quickFacts`:

```swift
                    if let notes = info?.editorialNotes {
                        editorialNotes(notes)
                    }
```

Add the section view alongside the other private views, matching the sheet's card styling (mirror however `quickFacts` frames itself — if it uses `glassCard()` or a material background, copy that):

```swift
    private func editorialNotes(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("From Apple Music")
                .font(.caption.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(palette.accent)
                .textCase(.uppercase)
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .glassCard()
    }
```

(If `glassCard()` isn't directly applicable here, use the same background treatment `quickFacts` uses.)

- [ ] **Step 2: Build; visual check in mock mode** — `MockCatalogInfoService` returns no editorial notes, so to preview the section temporarily add `editorialNotes: "Long-form editorial copy…"` to `MockCatalogInfoService`'s returned `CatalogInfo`, check the sheet, then EITHER keep it (nice for mock-mode demos) or revert. Keeping it is recommended — commit it as part of this task if kept.

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/SongInfoSheet.swift" "Daily Music/Services/CatalogInfoService.swift"
git commit -m "feat(info): show Apple Music editorial notes when connected"
```

---

### Task 11: Architecture doc + final verification

**Files:**
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Update `docs/ARCHITECTURE.md`** (project rule: the map tracks code changes):

1. **§3.7 Player diagram + prose:** add `FullTrackMusicEngine` (replacing the `MusicKitMusicEngine` "future" node), `PlaybackContext` routing (`.standard` vs `.sample`), `AppleMusicSession` feeding the routing decision, fallback-to-preview behavior, and `isPlayingFullTrack`.
2. **§4 service table:** add rows — `AppleMusicSession` (MusicKit auth + subscription, UserDefaults flag), `EnrichedCatalogInfoService` (MusicKit extras over iTunes lookup), `SavedTracksLog` (UserDefaults). Note `FeatureFlags.appleMusicConnect` gating.
3. **§3.6 Entry detail:** mention the capability-gated save action + `SavedTracksLog`.
4. **§6 "where do I look?" table:** add rows —
   - "Full tracks not playing for a subscriber" → `MusicPlayer` routing + `AppleMusicSession` capabilities + `FeatureFlags.appleMusicConnect`
   - "Save button missing on entry detail" → `.librarySave` capability (needs subscription) + flag
   - "Editorial notes missing in info sheet" → `EnrichedCatalogInfoService` gating

- [ ] **Step 2: Full test suite + build, verify everything green**

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs(architecture): map Apple Music connection layer and playback routing"
```

---

## Post-implementation

- The feature is **invisible** in release builds until `FeatureFlags.appleMusicConnect = true`; flipping it requires the activation checklist in `FullTrackMusicEngine.swift` (MusicKit capability, real-device testing).
- Out of scope (per spec): album/artist actions, Spotify/Tidal connections, animated artwork, widget changes.
