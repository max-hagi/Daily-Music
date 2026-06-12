# Spotify Connect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spotify users connect via OAuth (PKCE) and save the daily song to a private "Daily Music" playlist — live immediately, no feature flag — with library saves refactored off the playback engines onto the connection layer so Apple Music and Spotify are symmetric.

**Architecture:** Three focused units behind the existing `MusicServiceConnection` protocol: `SpotifyAuthenticator` (PKCE + Keychain tokens, behind a `SpotifyAuthenticating` seam), `SpotifyLibraryAPI` (Web API with injectable transport), `SpotifySession` (@Observable state machine). Task 1 first moves `addToDailyPlaylist` from `MusicEngine`/`MusicPlayer` onto `MusicServiceConnection.saveToLibrary`. Spec: `docs/superpowers/specs/2026-06-11-spotify-connect-design.md`.

**Tech Stack:** SwiftUI, AuthenticationServices (`ASWebAuthenticationSession`), CryptoKit (SHA256 for PKCE), Security (Keychain), URLSession, Swift Testing.

**Branch:** `feature/spotify-connect` (already created; spec committed).

---

## Build & test commands

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|✘|TEST|tests in" | head
# Single suite:
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/SpotifySessionTests" 2>&1 | grep -E "error:|✔|✘|TEST" | head -20
```

**Environment gotchas (learned during the Apple Music build):**
- App-target folders are file-system-synchronized — new `.swift` files under `Daily Music/` are picked up automatically. **`Daily MusicTests/` is NOT** — every new test file needs manual registration in `Daily Music.xcodeproj/project.pbxproj` in FOUR places (PBXBuildFile, PBXFileReference, the `Daily MusicTests` PBXGroup children, the test target's Sources phase). Task 0 below registers all four new test files at once with placeholder files, exactly as done for the Apple Music suites (grep `0A0A0A0A` in the pbxproj to see the pattern).
- A `-only-testing:` filter that matches nothing reports **TEST SUCCEEDED** — always confirm a new test actually compiled/failed before trusting green.
- Tests are Swift Testing (`import Testing`, `@Test`, `#expect`), `@MainActor struct` suites.
- If Xcode (the app) is open it may delete `Package.resolved` from the working copy — restore with `git checkout -- "Daily Music.xcodeproj"`, never commit the deletion.

## File structure

| File | Action | Responsibility |
|---|---|---|
| `Daily Music.xcodeproj/project.pbxproj` | Modify | Register 4 new test files |
| `Daily Music/Services/Music/MusicServiceConnection.swift` | Modify | + `saveToLibrary(_:)` requirement |
| `Daily Music/Services/Music/AppleMusicSession.swift` | Modify | Implement `saveToLibrary` via new `AppleMusicLibraryWriting` seam (MusicKit code moves here from the engine) |
| `Daily Music/Services/Music/FullTrackMusicEngine.swift` | Modify | Drop `addToDailyPlaylist` + `addToPlaylistUnavailable` |
| `Daily Music/Services/Music/PreviewMusicEngine.swift` | Modify | Drop throwing `addToDailyPlaylist` stub |
| `Daily Music/Services/MusicPlayer.swift` | Modify | Drop `addToDailyPlaylist` from protocol, player, `MockMusicEngine` |
| `Daily Music/Views/EntryActionCluster.swift` | Modify | Save button routes via `env.librarySaveService` |
| `Daily Music/Views/EntryDetailView.swift` | Modify | Rename save-error state |
| `Daily Music/App/AppEnvironment.swift` | Modify | `spotify` session, `musicServices`, `librarySaveService` |
| `Daily Music/App/SpotifyConfig.swift` | Create | Client ID, redirect URI, scopes (committed — all public values) |
| `Daily Music/Services/Music/Spotify/SpotifyPKCE.swift` | Create | Pure PKCE helpers (verifier, S256 challenge) |
| `Daily Music/Services/Music/Spotify/KeychainStore.swift` | Create | Generic-password Keychain wrapper |
| `Daily Music/Services/Music/Spotify/SpotifyAuthenticator.swift` | Create | `SpotifyAuthenticating` seam, tokens model, live PKCE/refresh impl, mock |
| `Daily Music/Services/Music/Spotify/SpotifyLibraryAPI.swift` | Create | Web API client (find-or-create playlist, add track) |
| `Daily Music/Services/Music/Spotify/SpotifySession.swift` | Create | `MusicServiceConnection` state machine |
| `Daily Music/Models/DailyEntry.swift` | Modify | + `spotifyTrackID` computed (DRY with `spotifyURL`) |
| `Daily Music/App/RootView.swift` | Modify | `spotify.restore()` on launch |
| `Daily Music/Views/SettingsView.swift` | Modify | Spotify row; section always visible |
| `Daily Music/Views/Onboarding/OnboardingListenStep.swift` | Modify | Generalized connect prompt |
| `docs/ARCHITECTURE.md` | Modify | Connection layer + saves routing |
| `Daily MusicTests/SpotifyPKCETests.swift` | Create | RFC 7636 vectors |
| `Daily MusicTests/KeychainStoreTests.swift` | Create | Round-trip/delete |
| `Daily MusicTests/SpotifySessionTests.swift` | Create | State machine via mock authenticator |
| `Daily MusicTests/SpotifyLibraryAPITests.swift` | Create | Request shapes via stub transport |

---

### Task 0: Register the four new test files in the pbxproj

**Files:**
- Modify: `Daily Music.xcodeproj/project.pbxproj`
- Create: `Daily MusicTests/SpotifyPKCETests.swift`, `Daily MusicTests/KeychainStoreTests.swift`, `Daily MusicTests/SpotifySessionTests.swift`, `Daily MusicTests/SpotifyLibraryAPITests.swift` (placeholders)

- [ ] **Step 1: Create four placeholder files** so the build doesn't fail on missing inputs. Each contains only:

```swift
// Placeholder — filled in by its task.
import Testing
```

- [ ] **Step 2: Add pbxproj entries.** Use IDs `0B0B0B0B0B0B0B0B0B0B00B1`–`B4` (build files) and `…00F1`–`F4` (file refs), mirroring the existing `0A0A…` Apple Music entries:

In the `PBXBuildFile` section (after the `0A0A…00B4` line):

```
		0B0B0B0B0B0B0B0B0B0B00B1 /* SpotifyPKCETests.swift in Sources */ = {isa = PBXBuildFile; fileRef = 0B0B0B0B0B0B0B0B0B0B00F1 /* SpotifyPKCETests.swift */; };
		0B0B0B0B0B0B0B0B0B0B00B2 /* KeychainStoreTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = 0B0B0B0B0B0B0B0B0B0B00F2 /* KeychainStoreTests.swift */; };
		0B0B0B0B0B0B0B0B0B0B00B3 /* SpotifySessionTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = 0B0B0B0B0B0B0B0B0B0B00F3 /* SpotifySessionTests.swift */; };
		0B0B0B0B0B0B0B0B0B0B00B4 /* SpotifyLibraryAPITests.swift in Sources */ = {isa = PBXBuildFile; fileRef = 0B0B0B0B0B0B0B0B0B0B00F4 /* SpotifyLibraryAPITests.swift */; };
```

In `PBXFileReference` (after `0A0A…00F4`):

```
		0B0B0B0B0B0B0B0B0B0B00F1 /* SpotifyPKCETests.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = SpotifyPKCETests.swift; sourceTree = "<group>"; };
		0B0B0B0B0B0B0B0B0B0B00F2 /* KeychainStoreTests.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = KeychainStoreTests.swift; sourceTree = "<group>"; };
		0B0B0B0B0B0B0B0B0B0B00F3 /* SpotifySessionTests.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = SpotifySessionTests.swift; sourceTree = "<group>"; };
		0B0B0B0B0B0B0B0B0B0B00F4 /* SpotifyLibraryAPITests.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = SpotifyLibraryAPITests.swift; sourceTree = "<group>"; };
```

In the `474DB509253B3672F8A852C1 /* Daily MusicTests */` group's `children` (after the `0A0A…00F4` line) — the four `…00F1`–`F4` lines; and in the test target's Sources build phase (after `0A0A…00B4`) — the four `…00B1`–`B4` lines.

- [ ] **Step 3: Build to verify** (placeholders compile): `xcodebuild build …` → BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music.xcodeproj/project.pbxproj" "Daily MusicTests/"
git commit -m "chore(tests): register Spotify test files in pbxproj"
```

---

### Task 1: Saves altitude fix — `saveToLibrary` moves to the connection layer

**Files:**
- Modify: `Daily Music/Services/Music/MusicServiceConnection.swift`
- Modify: `Daily Music/Services/Music/AppleMusicSession.swift`
- Modify: `Daily Music/Services/Music/FullTrackMusicEngine.swift`
- Modify: `Daily Music/Services/Music/PreviewMusicEngine.swift`
- Modify: `Daily Music/Services/MusicPlayer.swift`
- Modify: `Daily Music/App/AppEnvironment.swift`
- Modify: `Daily Music/Views/EntryActionCluster.swift`, `Daily Music/Views/EntryDetailView.swift`
- Modify: `Daily MusicTests/PlaybackTests.swift`, `Daily MusicTests/MusicPlayerRoutingTests.swift` (FakeEngines drop the method)

This is a refactor guarded by the existing suites — no new tests, but the full suite must stay green and the app must build.

- [ ] **Step 1: Add the protocol requirement** in `MusicServiceConnection.swift`:

```swift
@MainActor
protocol MusicServiceConnection: AnyObject {
    var service: StreamingService { get }
    var status: MusicConnectionStatus { get }
    func connect() async
    func disconnect()
    /// Save a track to this service's library presence for the app (the
    /// private "Daily Music" playlist). Only meaningful when capabilities
    /// contain .librarySave — callers gate on that.
    func saveToLibrary(_ entry: DailyEntry) async throws
}
```

- [ ] **Step 2: Give `AppleMusicSession` the save, behind a library seam** (so mock-mode saves don't hit real MusicKit). In `AppleMusicSession.swift` add:

```swift
/// Seam over MusicKit library writes, so the session is testable and the
/// mock environment can fake saves without the entitlement.
protocol AppleMusicLibraryWriting: Sendable {
    func addToDailyPlaylist(appleMusicID: String) async throws
}

/// Live MusicKit implementation — find-or-create the "Daily Music" playlist.
/// (Moved here from FullTrackMusicEngine: saving is a connection concern.)
struct MusicKitLibraryWriter: AppleMusicLibraryWriting {
    private static let playlistName = "Daily Music"

    func addToDailyPlaylist(appleMusicID: String) async throws {
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(appleMusicID))
        guard let song = try await request.response().items.first else {
            throw MusicEngineError.songNotFound
        }
        let existing = try await MusicLibraryRequest<Playlist>().response().items
        if let playlist = existing.first(where: { $0.name == Self.playlistName }) {
            try await MusicLibrary.shared.add(song, to: playlist)
        } else {
            _ = try await MusicLibrary.shared.createPlaylist(name: Self.playlistName, items: [song])
        }
    }
}

/// Dev/sim stand-in: pretends the save worked.
struct MockAppleMusicLibraryWriter: AppleMusicLibraryWriting {
    func addToDailyPlaylist(appleMusicID: String) async throws {
        try? await Task.sleep(for: .milliseconds(400))
    }
}
```

Update the session: add a stored `private let library: AppleMusicLibraryWriting`, extend the init to `init(authorizer: AppleMusicAuthorizing, library: AppleMusicLibraryWriting = MusicKitLibraryWriter(), defaults: UserDefaults = .standard)`, and add:

```swift
    func saveToLibrary(_ entry: DailyEntry) async throws {
        try await library.addToDailyPlaylist(appleMusicID: entry.appleMusicID)
    }
```

- [ ] **Step 3: Delete the playback-layer save path.** Remove:
  - `MusicEngine.addToDailyPlaylist` requirement and the doc line above it (`MusicPlayer.swift`)
  - `MusicPlayer.addToDailyPlaylist(_:)` and its comment (`MusicPlayer.swift`)
  - `MockMusicEngine.addToDailyPlaylist` (`MusicPlayer.swift`)
  - `PreviewMusicEngine.addToDailyPlaylist` (the throwing stub)
  - `FullTrackMusicEngine.addToDailyPlaylist`, its `playlistName` constant, and the now-unused `fetchSong`? — **no**: `fetchSong` is still used by `play()`. Only remove the playlist method + constant.
  - `MusicEngineError.addToPlaylistUnavailable` case and its `errorDescription` line.
  - `addToDailyPlaylist` from `FakeEngine` in BOTH `PlaybackTests.swift` and `MusicPlayerRoutingTests.swift`.

- [ ] **Step 4: Route the save button through the environment.** In `AppEnvironment.swift` add (below the stored properties):

```swift
    /// Every connectable service, in priority order. (Spotify joins in a
    /// later task.)
    var musicServices: [any MusicServiceConnection] { [appleMusic] }

    /// The connected service that can take a library save right now, if any —
    /// drives the save button's visibility and routing.
    var librarySaveService: (any MusicServiceConnection)? {
        musicServices.first { $0.status.capabilities.contains(.librarySave) }
    }
```

Also pass the mock library writer in `mock()`: change `appleMusicAuthorizer: MockAppleMusicAuthorizer()` wiring — the session is built inside the init, so extend the init with `appleMusicLibrary: AppleMusicLibraryWriting = MusicKitLibraryWriter()` and use it in `AppleMusicSession(authorizer:library:defaults:)`; `mock()` passes `appleMusicLibrary: MockAppleMusicLibraryWriter()`.

In `EntryDetailView.swift` rename the state: `@State var saveToAppleMusicFailed = false` → `@State var saveFailed = false`.

In `EntryActionCluster.swift` replace `canSaveToLibrary`, `saveToAppleMusic()`, and the alert/labels in `saveButton`:

```swift
    /// Save is offered when ANY connected service can write to its library
    /// (Apple Music needs a subscription; Spotify needs a linked account).
    private var canSaveToLibrary: Bool {
        env.librarySaveService != nil
    }

    private func saveToLibrary() {
        guard let service = env.librarySaveService,
              !env.savedTracks.isSaved(entry) else { return }
        Haptics.tap()
        Task {
            do {
                try await service.saveToLibrary(entry)
                env.savedTracks.markSaved(entry)
            } catch {
                saveFailed = true
            }
        }
    }
```

In `saveButton`, the action becomes `saveToLibrary()`, the alert becomes service-neutral:

```swift
        .alert("Couldn't save this song", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connected service in Settings and try again.")
        }
```

and the accessibility labels become "Added to your Daily Music playlist" / "Save to your Daily Music playlist" (unchanged first, drop "Apple" from the second if present).

- [ ] **Step 5: Run the FULL suite + build** — all existing tests must pass unmodified except the two FakeEngine deletions. Expected: 177 tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A "Daily Music" "Daily MusicTests"
git commit -m "refactor(music): move library saves from playback engines to MusicServiceConnection"
```

---

### Task 2: PKCE helpers + KeychainStore (TDD)

**Files:**
- Create: `Daily Music/Services/Music/Spotify/SpotifyPKCE.swift`, `Daily Music/Services/Music/Spotify/KeychainStore.swift`
- Test: `Daily MusicTests/SpotifyPKCETests.swift`, `Daily MusicTests/KeychainStoreTests.swift`

- [ ] **Step 1: Write the failing tests.** `SpotifyPKCETests.swift`:

```swift
import Testing
import Foundation
@testable import Daily_Music

struct SpotifyPKCETests {
    @Test func verifierIsWithinRFCLengthAndCharset() {
        let verifier = SpotifyPKCE.codeVerifier()
        #expect(verifier.count >= 43 && verifier.count <= 128)
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        #expect(verifier.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    @Test func verifiersAreUnique() {
        #expect(SpotifyPKCE.codeVerifier() != SpotifyPKCE.codeVerifier())
    }

    // RFC 7636 Appendix B test vector.
    @Test func challengeMatchesRFCTestVector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        #expect(SpotifyPKCE.codeChallenge(for: verifier)
                == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }
}
```

`KeychainStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import Daily_Music

struct KeychainStoreTests {
    private func freshStore() -> KeychainStore {
        KeychainStore(service: "tests.spotify-\(UUID().uuidString)")
    }

    @Test func roundTripsData() throws {
        let store = freshStore()
        let payload = Data("hello".utf8)
        try store.set(payload, for: "tokens")
        #expect(store.data(for: "tokens") == payload)
    }

    @Test func overwritesExistingValue() throws {
        let store = freshStore()
        try store.set(Data("one".utf8), for: "tokens")
        try store.set(Data("two".utf8), for: "tokens")
        #expect(store.data(for: "tokens") == Data("two".utf8))
    }

    @Test func deleteRemovesValueAndMissingReadsAreNil() throws {
        let store = freshStore()
        #expect(store.data(for: "tokens") == nil)
        try store.set(Data("x".utf8), for: "tokens")
        store.delete("tokens")
        #expect(store.data(for: "tokens") == nil)
    }
}
```

- [ ] **Step 2: Run both suites — expect compile failure** (`cannot find 'SpotifyPKCE'`, `cannot find 'KeychainStore'`). The placeholders are being replaced, so a real RED must appear.

- [ ] **Step 3: Implement.** `SpotifyPKCE.swift`:

```swift
//
//  SpotifyPKCE.swift
//  Daily Music
//
//  Pure PKCE (RFC 7636) helpers for the Spotify OAuth flow. No secret is
//  involved anywhere — the code challenge proves the same client that started
//  the login finishes it.
//

import Foundation
import CryptoKit

enum SpotifyPKCE {
    /// 64 random bytes → 86-char base64url string (within RFC's 43–128).
    static func codeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    /// S256: base64url(SHA256(verifier)).
    static func codeChallenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

`KeychainStore.swift`:

```swift
//
//  KeychainStore.swift
//  Daily Music
//
//  Minimal generic-password Keychain wrapper for credential storage (Spotify
//  tokens). UserDefaults is wrong for credentials — it's plaintext on disk.
//

import Foundation
import Security

struct KeychainStore {
    enum KeychainError: Error { case unhandled(OSStatus) }

    let service: String

    func set(_ data: Data, for key: String) throws {
        delete(key)   // add fails on duplicates; replace semantics are what we want
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    func data(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 4: Run both suites — expect 6 passes.** (Keychain works in simulator test runs because tests host in the app process.)

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/Music/Spotify/" "Daily MusicTests/SpotifyPKCETests.swift" "Daily MusicTests/KeychainStoreTests.swift"
git commit -m "feat(spotify): PKCE helpers and Keychain token store"
```

---

### Task 3: `SpotifyConfig` + `SpotifyAuthenticating` seam + live authenticator

**Files:**
- Create: `Daily Music/App/SpotifyConfig.swift`
- Create: `Daily Music/Services/Music/Spotify/SpotifyAuthenticator.swift`

The live authenticator's interactive flow can't be unit-tested (real browser + network); the session state machine around it is tested in Task 4. Build-verified here.

- [ ] **Step 1: Create `SpotifyConfig.swift`:**

```swift
//
//  SpotifyConfig.swift
//  Daily Music
//
//  Spotify app registration values. ALL PUBLIC — the client ID ships in the
//  binary by design (PKCE needs no secret; the secret stays in the Spotify
//  dashboard and must never enter this repo).
//

import Foundation

enum SpotifyConfig {
    static let clientID = "af09508c18cf406e963ed6fc82be10ba"
    /// Must match the dashboard registration character-exactly.
    static let redirectURI = "dailymusic://spotify-callback"
    static let callbackScheme = "dailymusic"
    /// Minimal ask: find/create + write our private playlist. No Liked Songs,
    /// no profile data beyond the id (which any token can read).
    static let scopes = "playlist-modify-private playlist-read-private"
}
```

- [ ] **Step 2: Create `SpotifyAuthenticator.swift`:**

```swift
//
//  SpotifyAuthenticator.swift
//  Daily Music
//
//  The PKCE OAuth dance + token lifecycle for Spotify. SpotifySession talks
//  to the SpotifyAuthenticating protocol so the state machine is unit-testable;
//  this file holds the live implementation (ASWebAuthenticationSession +
//  accounts.spotify.com) and the mock.
//

import Foundation
import AuthenticationServices

struct SpotifyTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

enum SpotifyAuthError: Error, Equatable {
    case cancelled          // user closed the login sheet — not an error to surface
    case stateMismatch      // callback state didn't match; treat as failed login
    case needsReconnect     // refresh token rejected — user must connect again
    case invalidResponse
}

protocol SpotifyAuthenticating: Sendable {
    /// Whether tokens are stored (drives silent restore — no network).
    var hasStoredTokens: Bool { get }
    /// Run the full interactive PKCE flow. Throws SpotifyAuthError.cancelled
    /// if the user dismisses the sheet.
    func authorize() async throws
    /// A fresh access token — refreshes (and rotates) behind the scenes.
    /// Throws .needsReconnect when the refresh token is rejected.
    func validAccessToken() async throws -> String
    func clearTokens()
}

final class SpotifyAuthenticator: NSObject, SpotifyAuthenticating, @unchecked Sendable {
    private let keychain = KeychainStore(service: "daily-music.spotify")
    private static let tokensKey = "tokens"
    /// Refresh 5 min early so a token never expires mid-request.
    private static let expirySkew: TimeInterval = 300

    var hasStoredTokens: Bool { storedTokens() != nil }

    func clearTokens() {
        keychain.delete(Self.tokensKey)
    }

    // MARK: Interactive flow

    @MainActor
    func authorize() async throws {
        let verifier = SpotifyPKCE.codeVerifier()
        let state = UUID().uuidString

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            .init(name: "client_id", value: SpotifyConfig.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            .init(name: "scope", value: SpotifyConfig.scopes),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: SpotifyPKCE.codeChallenge(for: verifier)),
            .init(name: "state", value: state),
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: SpotifyConfig.callbackScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    continuation.resume(throwing: SpotifyAuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? SpotifyAuthError.invalidResponse)
                }
            }
            session.presentationContextProvider = self
            session.start()
        }

        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
        guard items?.first(where: { $0.name == "state" })?.value == state else {
            throw SpotifyAuthError.stateMismatch
        }
        guard let code = items?.first(where: { $0.name == "code" })?.value else {
            throw SpotifyAuthError.invalidResponse   // includes ?error=access_denied
        }

        let tokens = try await exchange(form: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConfig.redirectURI,
            "client_id": SpotifyConfig.clientID,
            "code_verifier": verifier,
        ], existingRefreshToken: nil)
        try persist(tokens)
    }

    // MARK: Token lifecycle

    func validAccessToken() async throws -> String {
        guard let tokens = storedTokens() else { throw SpotifyAuthError.needsReconnect }
        if tokens.expiresAt.timeIntervalSinceNow > Self.expirySkew {
            return tokens.accessToken
        }
        // Token-endpoint rejection (400/401) is mapped to .needsReconnect inside
        // exchange(); plain network errors rethrow untouched so a dead wifi
        // moment never wipes a healthy connection.
        let refreshed = try await exchange(form: [
            "grant_type": "refresh_token",
            "refresh_token": tokens.refreshToken,
            "client_id": SpotifyConfig.clientID,
        ], existingRefreshToken: tokens.refreshToken)
        try persist(refreshed)
        return refreshed.accessToken
    }

    // MARK: Helpers

    private func storedTokens() -> SpotifyTokens? {
        keychain.data(for: Self.tokensKey).flatMap { try? JSONDecoder().decode(SpotifyTokens.self, from: $0) }
    }

    private func persist(_ tokens: SpotifyTokens) throws {
        try keychain.set(try JSONEncoder().encode(tokens), for: Self.tokensKey)
    }

    /// POST accounts.spotify.com/api/token. Spotify rotates refresh tokens —
    /// when the response omits one (refresh grant sometimes does), keep the
    /// existing token.
    private func exchange(form: [String: String], existingRefreshToken: String?) async throws -> SpotifyTokens {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyAuthError.invalidResponse }
        guard http.statusCode == 200 else {
            // 400/401 from the token endpoint = grant rejected (revoked/expired).
            throw (400...401).contains(http.statusCode)
                ? SpotifyAuthError.needsReconnect
                : SpotifyAuthError.invalidResponse
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let expires_in: Double
            let refresh_token: String?
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let refresh = decoded.refresh_token ?? existingRefreshToken else {
            throw SpotifyAuthError.invalidResponse
        }
        return SpotifyTokens(
            accessToken: decoded.access_token,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(decoded.expires_in)
        )
    }
}

extension SpotifyAuthenticator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

/// Test/sim stand-in: connects instantly, hands out a fixed token.
final class MockSpotifyAuthenticator: SpotifyAuthenticating, @unchecked Sendable {
    var hasStoredTokens: Bool
    var authorizeError: SpotifyAuthError?
    var tokenError: SpotifyAuthError?
    private(set) var clearCount = 0

    init(hasStoredTokens: Bool = false) {
        self.hasStoredTokens = hasStoredTokens
    }

    func authorize() async throws {
        if let authorizeError { throw authorizeError }
        hasStoredTokens = true
    }

    func validAccessToken() async throws -> String {
        if let tokenError { throw tokenError }
        return "mock-access-token"
    }

    func clearTokens() {
        hasStoredTokens = false
        clearCount += 1
    }
}
```

- [ ] **Step 3: Build** → BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/App/SpotifyConfig.swift" "Daily Music/Services/Music/Spotify/SpotifyAuthenticator.swift"
git commit -m "feat(spotify): PKCE authenticator with Keychain token lifecycle"
```

---

### Task 4: `SpotifyLibraryAPI` + `DailyEntry.spotifyTrackID` (TDD)

**Files:**
- Create: `Daily Music/Services/Music/Spotify/SpotifyLibraryAPI.swift`
- Modify: `Daily Music/Models/DailyEntry.swift` (factor `spotifyTrackID` out of `spotifyURL`)
- Test: `Daily MusicTests/SpotifyLibraryAPITests.swift`

- [ ] **Step 1: Write the failing tests:**

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct SpotifyLibraryAPITests {
    /// Scripted transport: returns queued responses, records every request.
    final class StubTransport: @unchecked Sendable {
        private(set) var requests: [URLRequest] = []
        var responses: [(Data, Int)] = []   // (body, statusCode), consumed in order

        func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
            requests.append(request)
            let (data, status) = responses.isEmpty ? (Data("{}".utf8), 200) : responses.removeFirst()
            let http = HTTPURLResponse(url: request.url!, statusCode: status,
                                       httpVersion: nil, headerFields: nil)!
            return (data, http)
        }
    }

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SpotifyLibraryAPITests-\(UUID().uuidString)")!
    }

    private func api(_ transport: StubTransport, defaults: UserDefaults) -> SpotifyLibraryAPI {
        SpotifyLibraryAPI(defaults: defaults, transport: transport.send)
    }

    @Test func reusesExistingPlaylistAndAddsTrack() async throws {
        let transport = StubTransport()
        transport.responses = [
            (Data(#"{"id":"user1"}"#.utf8), 200),                                     // GET /me
            (Data(#"{"items":[{"id":"pl9","name":"Daily Music"}]}"#.utf8), 200),      // GET /me/playlists
            (Data("{}".utf8), 201),                                                   // POST tracks
        ]
        try await api(transport, defaults: freshDefaults())
            .saveToDailyPlaylist(trackID: "track123", accessToken: "tok")

        #expect(transport.requests.count == 3)
        #expect(transport.requests[0].url?.path == "/v1/me")
        #expect(transport.requests[2].url?.path == "/v1/playlists/pl9/tracks")
        #expect(transport.requests[2].httpMethod == "POST")
        let body = String(data: transport.requests[2].httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(body.contains("spotify:track:track123"))
        #expect(transport.requests.allSatisfy {
            $0.value(forHTTPHeaderField: "Authorization") == "Bearer tok"
        })
    }

    @Test func createsPlaylistWhenMissing() async throws {
        let transport = StubTransport()
        transport.responses = [
            (Data(#"{"id":"user1"}"#.utf8), 200),                  // GET /me
            (Data(#"{"items":[]}"#.utf8), 200),                    // GET /me/playlists — none
            (Data(#"{"id":"plNew"}"#.utf8), 201),                  // POST create playlist
            (Data("{}".utf8), 201),                                // POST tracks
        ]
        try await api(transport, defaults: freshDefaults())
            .saveToDailyPlaylist(trackID: "t", accessToken: "tok")

        #expect(transport.requests[2].url?.path == "/v1/users/user1/playlists")
        let createBody = String(data: transport.requests[2].httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(createBody.contains(#""name":"Daily Music""#))
        #expect(createBody.contains(#""public":false"#))
        #expect(transport.requests[3].url?.path == "/v1/playlists/plNew/tracks")
    }

    @Test func cachedPlaylistSkipsLookupOnSecondSave() async throws {
        let defaults = freshDefaults()
        let transport = StubTransport()
        transport.responses = [
            (Data(#"{"id":"user1"}"#.utf8), 200),
            (Data(#"{"items":[{"id":"pl9","name":"Daily Music"}]}"#.utf8), 200),
            (Data("{}".utf8), 201),
        ]
        try await api(transport, defaults: defaults).saveToDailyPlaylist(trackID: "a", accessToken: "tok")

        let second = StubTransport()
        second.responses = [(Data("{}".utf8), 201)]                // just the add
        try await api(second, defaults: defaults).saveToDailyPlaylist(trackID: "b", accessToken: "tok")
        #expect(second.requests.count == 1)
        #expect(second.requests[0].url?.path == "/v1/playlists/pl9/tracks")
    }

    @Test func staleCachedPlaylistReresolvesOn404() async throws {
        let defaults = freshDefaults()
        defaults.set("deadPlaylist", forKey: "spotify.dailyPlaylistID")
        let transport = StubTransport()
        transport.responses = [
            (Data("{}".utf8), 404),                                // add → playlist gone
            (Data(#"{"id":"user1"}"#.utf8), 200),                  // re-resolve
            (Data(#"{"items":[]}"#.utf8), 200),
            (Data(#"{"id":"plNew"}"#.utf8), 201),
            (Data("{}".utf8), 201),                                // retry add
        ]
        try await api(transport, defaults: defaults).saveToDailyPlaylist(trackID: "t", accessToken: "tok")
        #expect(transport.requests.last?.url?.path == "/v1/playlists/plNew/tracks")
    }

    @Test func spotifyTrackIDParsesURIAndBareForms() {
        let entry = DailyEntry(
            id: UUID(), date: Date(), title: "T", artist: "A",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "1",
            spotifyURI: "spotify:track:abc123"
        )
        #expect(entry.spotifyTrackID == "abc123")
    }
}
```

- [ ] **Step 2: Run — expect compile failure** (`SpotifyLibraryAPI`, `spotifyTrackID` not found).

- [ ] **Step 3: Implement.** In `DailyEntry.swift`, factor the ID parse out of `spotifyURL` (keep that property working):

```swift
    /// The bare Spotify track ID — "spotify:track:X" → "X" (already-bare IDs
    /// pass through).
    var spotifyTrackID: String {
        spotifyURI.split(separator: ":").last.map(String.init) ?? spotifyURI
    }
```

and change `spotifyURL`'s `let trackID = …` line to `let trackID = spotifyTrackID`.

Create `SpotifyLibraryAPI.swift`:

```swift
//
//  SpotifyLibraryAPI.swift
//  Daily Music
//
//  Thin Spotify Web API client for one job: get the daily song into a private
//  "Daily Music" playlist. The playlist ID is cached after first resolution so
//  the steady-state save is a single request. Transport is injected so request
//  shapes are unit-testable offline.
//

import Foundation

struct SpotifyLibraryAPI {
    enum APIError: Error, Equatable {
        case http(Int)          // non-success status (after retries)
        case notAllowlisted     // 403 — Spotify dev-mode user cap
        case invalidResponse
    }

    private static let playlistName = "Daily Music"
    private static let cacheKey = "spotify.dailyPlaylistID"

    let defaults: UserDefaults
    var transport: (URLRequest) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(for: $0) }

    func saveToDailyPlaylist(trackID: String, accessToken: String) async throws {
        if let cached = defaults.string(forKey: Self.cacheKey) {
            do {
                try await addTrack(trackID, to: cached, token: accessToken)
                return
            } catch APIError.http(404) {
                defaults.removeObject(forKey: Self.cacheKey)   // user deleted it — re-resolve
            }
        }
        let playlistID = try await findOrCreatePlaylist(token: accessToken)
        defaults.set(playlistID, forKey: Self.cacheKey)
        try await addTrack(trackID, to: playlistID, token: accessToken)
    }

    // MARK: Requests

    private func addTrack(_ trackID: String, to playlistID: String, token: String) async throws {
        var request = makeRequest("POST", path: "/v1/playlists/\(playlistID)/tracks", token: token)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["uris": ["spotify:track:\(trackID)"]])
        _ = try await send(request)
    }

    private func findOrCreatePlaylist(token: String) async throws -> String {
        struct Me: Decodable { let id: String }
        struct Playlists: Decodable {
            struct Item: Decodable { let id: String; let name: String }
            let items: [Item]
        }

        let me = try JSONDecoder().decode(Me.self, from: try await send(makeRequest("GET", path: "/v1/me", token: token)))
        let lists = try JSONDecoder().decode(
            Playlists.self,
            from: try await send(makeRequest("GET", path: "/v1/me/playlists", query: "limit=50", token: token))
        )
        if let existing = lists.items.first(where: { $0.name == Self.playlistName }) {
            return existing.id
        }

        var create = makeRequest("POST", path: "/v1/users/\(me.id)/playlists", token: token)
        create.httpBody = Data(#"{"name":"Daily Music","public":false,"description":"Your daily songs from Daily Music"}"#.utf8)
        struct Created: Decodable { let id: String }
        return try JSONDecoder().decode(Created.self, from: try await send(create)).id
    }

    // MARK: Plumbing

    private func makeRequest(_ method: String, path: String, query: String? = nil, token: String) -> URLRequest {
        var components = URLComponents(string: "https://api.spotify.com")!
        components.path = path
        components.query = query
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    /// One 429 retry honoring Retry-After; everything else maps to APIError.
    private func send(_ request: URLRequest, isRetry: Bool = false) async throws -> Data {
        let (data, response) = try await transport(request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch http.statusCode {
        case 200...299:
            return data
        case 403:
            throw APIError.notAllowlisted
        case 429 where !isRetry:
            let delay = Double(http.value(forHTTPHeaderField: "Retry-After") ?? "1") ?? 1
            try await Task.sleep(for: .seconds(delay))
            return try await send(request, isRetry: true)
        default:
            throw APIError.http(http.statusCode)
        }
    }
}
```

- [ ] **Step 4: Run the suite — expect 5 passes.** Also run `StreamingServiceTests` (touches `spotifyURL`) — must stay green.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/Music/Spotify/SpotifyLibraryAPI.swift" "Daily Music/Models/DailyEntry.swift" "Daily MusicTests/SpotifyLibraryAPITests.swift"
git commit -m "feat(spotify): Web API client for find-or-create playlist saves"
```

---

### Task 5: `SpotifySession` (TDD)

**Files:**
- Create: `Daily Music/Services/Music/Spotify/SpotifySession.swift`
- Test: `Daily MusicTests/SpotifySessionTests.swift`

- [ ] **Step 1: Write the failing tests:**

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct SpotifySessionTests {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SpotifySessionTests-\(UUID().uuidString)")!
    }

    private func sampleEntry() -> DailyEntry {
        DailyEntry(
            id: UUID(), date: Date(), title: "Nobody", artist: "Mitski",
            albumArtURL: nil, journalMarkdown: "", appleMusicID: "123",
            spotifyURI: "spotify:track:abc"
        )
    }

    /// Records save calls so tests can assert what reached the API layer.
    @MainActor
    final class SaveRecorder {
        var trackIDs: [String] = []
        var error: Error?
    }

    private func makeSession(
        auth: MockSpotifyAuthenticator,
        recorder: SaveRecorder = SaveRecorder()
    ) -> SpotifySession {
        SpotifySession(authenticator: auth, defaults: freshDefaults()) { trackID, _ in
            if let error = recorder.error { throw error }
            recorder.trackIDs.append(trackID)
        }
    }

    @Test func startsNotConnected() {
        let session = makeSession(auth: MockSpotifyAuthenticator())
        #expect(session.status == .notConnected)
    }

    @Test func connectGrantsLibrarySave() async {
        let session = makeSession(auth: MockSpotifyAuthenticator())
        await session.connect()
        #expect(session.status == .connected([.librarySave]))
    }

    @Test func cancelledLoginStaysNotConnectedQuietly() async {
        let auth = MockSpotifyAuthenticator()
        auth.authorizeError = .cancelled
        let session = makeSession(auth: auth)
        await session.connect()
        #expect(session.status == .notConnected)
    }

    @Test func restoreConnectsWhenTokensStored() async {
        let session = makeSession(auth: MockSpotifyAuthenticator(hasStoredTokens: true))
        await session.restore()
        #expect(session.status == .connected([.librarySave]))
    }

    @Test func restoreStaysDisconnectedWithoutTokens() async {
        let session = makeSession(auth: MockSpotifyAuthenticator(hasStoredTokens: false))
        await session.restore()
        #expect(session.status == .notConnected)
    }

    @Test func disconnectClearsTokens() async {
        let auth = MockSpotifyAuthenticator()
        let session = makeSession(auth: auth)
        await session.connect()
        session.disconnect()
        #expect(session.status == .notConnected)
        #expect(auth.clearCount == 1)
        #expect(!auth.hasStoredTokens)
    }

    @Test func saveSendsParsedTrackID() async throws {
        let recorder = SaveRecorder()
        let session = makeSession(auth: MockSpotifyAuthenticator(hasStoredTokens: true), recorder: recorder)
        await session.restore()
        try await session.saveToLibrary(sampleEntry())
        #expect(recorder.trackIDs == ["abc"])
    }

    @Test func revokedRefreshDowngradesAndRethrows() async {
        let auth = MockSpotifyAuthenticator(hasStoredTokens: true)
        auth.tokenError = .needsReconnect
        let session = makeSession(auth: auth)
        await session.restore()
        #expect(session.status == .connected([.librarySave]))

        await #expect(throws: SpotifyAuthError.needsReconnect) {
            try await session.saveToLibrary(sampleEntry())
        }
        #expect(session.status == .notConnected)
        #expect(auth.clearCount == 1)   // dead tokens wiped
    }
}
```

- [ ] **Step 2: Run — expect compile failure** (`SpotifySession` not found).

- [ ] **Step 3: Implement `SpotifySession.swift`:**

```swift
//
//  SpotifySession.swift
//  Daily Music
//
//  Spotify's MusicServiceConnection: capabilities are [.librarySave] only —
//  Spotify offers third-party apps no in-app playback and no rich metadata.
//  Composes the authenticator (tokens) and the library API (saves); the save
//  closure is injected so the state machine tests run without HTTP.
//

import Foundation

@MainActor
@Observable
final class SpotifySession: MusicServiceConnection {
    let service: StreamingService = .spotify
    private(set) var status: MusicConnectionStatus = .notConnected
    private(set) var isConnecting = false

    private let authenticator: SpotifyAuthenticating
    private let defaults: UserDefaults
    /// (trackID, accessToken) → performs the playlist save.
    private let save: (String, String) async throws -> Void

    init(
        authenticator: SpotifyAuthenticating,
        defaults: UserDefaults = .standard,
        save: ((String, String) async throws -> Void)? = nil
    ) {
        self.authenticator = authenticator
        self.defaults = defaults
        let api = SpotifyLibraryAPI(defaults: defaults)
        self.save = save ?? { trackID, token in
            try await api.saveToDailyPlaylist(trackID: trackID, accessToken: token)
        }
    }

    /// Launch path: tokens in the Keychain = connected. No network — the
    /// first save exercises refresh if the access token is stale.
    func restore() async {
        guard authenticator.hasStoredTokens else { return }
        status = .connected([.librarySave])
    }

    func connect() async {
        isConnecting = true
        defer { isConnecting = false }
        do {
            try await authenticator.authorize()
            status = .connected([.librarySave])
        } catch SpotifyAuthError.cancelled {
            // User closed the sheet — quiet, not an error.
        } catch {
            // Failed login (state mismatch, network) — stay disconnected.
        }
    }

    /// Wipes our tokens + cached playlist. Full revocation lives at
    /// spotify.com/account/apps.
    func disconnect() {
        authenticator.clearTokens()
        defaults.removeObject(forKey: "spotify.dailyPlaylistID")
        status = .notConnected
    }

    func saveToLibrary(_ entry: DailyEntry) async throws {
        do {
            let token = try await authenticator.validAccessToken()
            try await save(entry.spotifyTrackID, token)
        } catch SpotifyAuthError.needsReconnect {
            // Refresh token revoked — drop to disconnected so the Settings row
            // offers Connect again, and let the save button show its alert.
            authenticator.clearTokens()
            status = .notConnected
            throw SpotifyAuthError.needsReconnect
        }
    }
}
```

- [ ] **Step 4: Run — expect 8 passes.**

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/Music/Spotify/SpotifySession.swift" "Daily MusicTests/SpotifySessionTests.swift"
git commit -m "feat(spotify): connection session with quiet-cancel and revocation downgrade"
```

---

### Task 6: Wire into `AppEnvironment` + launch restore

**Files:**
- Modify: `Daily Music/App/AppEnvironment.swift`
- Modify: `Daily Music/App/RootView.swift`

- [ ] **Step 1: `AppEnvironment` changes:**

Stored property (after `savedTracks`): `let spotify: SpotifySession`

Init: add param `spotify: SpotifySession` (after `appleMusicLibrary`); init body just assigns `self.spotify = spotify`. The factories build it pre-wired — this matches how `catalogInfo` is passed pre-built, and lets `mock()` stub the save path so simulator saves never hit HTTP:

```swift
        // mock():
        spotify: SpotifySession(
            authenticator: MockSpotifyAuthenticator(),
            save: { _, _ in try? await Task.sleep(for: .milliseconds(400)) }
        ),
        // live():
        spotify: SpotifySession(authenticator: SpotifyAuthenticator()),
```

Update `musicServices`:

```swift
    /// Every connectable service, in priority order (Apple Music first; both
    /// can't grant saves simultaneously today — its flag is off).
    var musicServices: [any MusicServiceConnection] { [appleMusic, spotify] }
```

- [ ] **Step 2: `RootView` restore** — extend the existing launch task line:

```swift
            await env.appleMusic.restore()
            await env.spotify.restore()
```

- [ ] **Step 3: Full suite + build** → all green.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/App/AppEnvironment.swift" "Daily Music/App/RootView.swift"
git commit -m "feat(spotify): wire SpotifySession into AppEnvironment and launch restore"
```

---

### Task 7: Surfaces — Settings row + onboarding prompt

**Files:**
- Modify: `Daily Music/Views/SettingsView.swift`
- Modify: `Daily Music/Views/Onboarding/OnboardingListenStep.swift`

- [ ] **Step 1: Settings.** In `musicSection`, the section is now always "Connected services" with the Spotify row unconditional:

```swift
    private var musicSection: some View {
        Section {
            spotifyRow
            if FeatureFlags.appleMusicConnect {
                appleMusicRow
            }
            Picker("Default streaming service", selection: $model.preferredStreamingService) {
                ForEach(StreamingService.allCases) { service in
                    Text(service.displayName).tag(service)
                }
            }
        } header: {
            Text("Connected services")
        } footer: {
            Text("Disconnecting removes Daily Music's access on this device. To fully revoke it, visit spotify.com/account/apps.")
        }
    }

    @ViewBuilder
    private var spotifyRow: some View {
        let session = env.spotify
        switch session.status {
        case .connected:
            VStack(alignment: .leading, spacing: 4) {
                Label("Spotify connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saves songs to your Daily Music playlist.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Disconnect Spotify", role: .destructive) {
                session.disconnect()
            }
        case .notConnected:
            Button {
                Task { await session.connect() }
            } label: {
                HStack {
                    Label { Text("Connect Spotify") } icon: { ServiceLogo(service: .spotify) }
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

(The existing `appleMusicRow` is unchanged; its Disconnect button label becomes "Disconnect Apple Music" for symmetry.)

- [ ] **Step 2: Onboarding.** In `OnboardingListenStep.swift`, generalize the prompt block in `body`:

```swift
            if settings.preferredStreamingService == .spotify {
                ServiceConnectPrompt(service: .spotify, accent: accent,
                                     title: "Connect Spotify to save songs")
            } else if FeatureFlags.appleMusicConnect,
                      settings.preferredStreamingService == .appleMusic {
                ServiceConnectPrompt(service: .appleMusic, accent: accent,
                                     title: "Connect Apple Music for full songs")
            }
```

Rename/replace the private `AppleMusicConnectPrompt` with a service-generic version (same file, same visual treatment):

```swift
/// Optional, skippable connect nudge for the picked service.
/// Never blocks onboarding — it's an upgrade, not a gate.
private struct ServiceConnectPrompt: View {
    let service: StreamingService
    var accent: Color
    let title: String
    @Environment(AppEnvironment.self) private var env

    private var session: (any MusicServiceConnection)? {
        env.musicServices.first { $0.service == service }
    }

    var body: some View {
        if let session {
            switch session.status {
            case .connected:
                Label("\(service.displayName) connected", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            case .notConnected:
                Button {
                    Task { await session.connect() }
                } label: {
                    HStack(spacing: 8) {
                        ServiceLogo(service: service)
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 10)
                    .glassCard()
                }
                .buttonStyle(.plain)
                .tint(accent)
            }
        }
    }
}
```

**Note:** `isConnecting` lives on the concrete sessions, not the protocol — the generic prompt drops the spinner/disable (acceptable; the sheet itself shows progress). If the spinner matters, add `var isConnecting: Bool { get }` to `MusicServiceConnection` and keep the disable.

- [ ] **Step 3: 403 dev-mode message in the save alert** (spec error-table row). In `EntryActionCluster.swift`, add `@State`-driven message — change `EntryDetailView.swift`'s state to also hold `@State var saveErrorMessage = ""`, and in `saveToLibrary()`'s catch:

```swift
            } catch {
                if case SpotifyLibraryAPI.APIError.notAllowlisted = error {
                    saveErrorMessage = "This Spotify app is in development mode — your account needs to be allowlisted in the Spotify dashboard first."
                } else {
                    saveErrorMessage = "Check your connected service in Settings and try again."
                }
                saveFailed = true
            }
```

and the alert's `message:` becomes `Text(saveErrorMessage)`.

- [ ] **Step 4: Build + full suite** → green. Then mock-mode visual check: Settings shows "Connected services" with a live Spotify row; tapping Connect flips to connected (mock authenticator); save button appears on entry detail and "saves" (mock save closure); onboarding listen step shows the Spotify prompt when Spotify is picked.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/SettingsView.swift" "Daily Music/Views/Onboarding/OnboardingListenStep.swift" \
  "Daily Music/Views/EntryActionCluster.swift" "Daily Music/Views/EntryDetailView.swift"
git commit -m "feat(spotify): Settings connect row, onboarding nudge, and dev-mode save message"
```

---

### Task 8: Docs + final verification + device test checklist

**Files:**
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Update `docs/ARCHITECTURE.md`:**
  - §3.7 connection paragraph: add `SpotifySession` ([.librarySave] only, PKCE via `SpotifyAuthenticating` seam, Keychain tokens, live immediately — no flag) and note saves moved off the engines onto `MusicServiceConnection.saveToLibrary` routed by `AppEnvironment.librarySaveService`.
  - §4 table: add `SpotifySession` row (Spotify accounts + Web API; Keychain `daily-music.spotify`; UserDefaults `spotify.dailyPlaylistID`).
  - §6 rows: "Spotify connect fails / row stuck" → `SpotifyAuthenticator` (redirect URI must match dashboard exactly) · "Spotify save fails with 403" → dev-mode allowlist in the Spotify dashboard.

- [ ] **Step 2: Full suite + build with a clean tree** → expected ~195+ tests green.

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs(architecture): map Spotify connection and saves routing"
```

- [ ] **Step 4: REAL-DEVICE ACCEPTANCE TEST (the user runs this — it needs their Spotify login):**
  1. Run the app on an iPhone in `live()` mode.
  2. Settings → Connected services → Connect Spotify → real Spotify login sheet → approve.
  3. Open today's entry → save button appears → tap → check the Spotify app: private "Daily Music" playlist exists with the track.
  4. Save a second entry → lands in the same playlist; button shows "Added ✓" states correctly after relaunch.
  5. Disconnect in Settings → row returns to Connect; save button disappears.

---

## Post-implementation

- Dev-mode reminder: only the dashboard owner + allowlisted users (max ~25) can connect until Spotify's extended-quota review — add testers in the dashboard under User Management.
- Out of scope (per spec): playback, Liked Songs, quota-extension prep, other services.
