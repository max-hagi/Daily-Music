# Friend Nudges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build manual per-friend nudges that send a fixed push notification to an accepted friend.

**Architecture:** Add a focused `FriendNudgeService` + `FriendNudgeStore` so nudge state stays separate from friend-list loading. The iOS app first ships with a mock/testable nudge path, then wires live Supabase Edge Function sending. Remote push token registration is a separate service from the existing local daily reminder service.

**Tech Stack:** SwiftUI, Swift Testing, Supabase Swift, Supabase Postgres/RLS/RPC, Supabase Edge Functions on Deno, APNs HTTP/2 token auth.

---

## Current State Notes

- Branch at plan time: `codex/friends-share-layout`.
- Existing uncommitted change: `Daily Music/Views/Friends/FriendsView.swift` has a `shareButtonLabel(_:)` helper. Preserve it and build around it.
- Main app source files live under a file-system synchronized Xcode group, so new app `.swift` files are picked up automatically.
- Test files are in a normal `PBXGroup`, so a new `Daily MusicTests/FriendNudgeTests.swift` requires editing `Daily Music.xcodeproj/project.pbxproj`.
- Use this simulator destination for local verification unless a newer booted simulator is chosen:
  `platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4`.

## File Structure

| File | Responsibility |
|------|----------------|
| `Daily Music/Services/FriendNudgeService.swift` | Nudge result model, user-facing error model, service protocol, mock actor |
| `Daily Music/ViewModels/FriendNudgeStore.swift` | MainActor UI state for sending/disabled labels per friend |
| `Daily MusicTests/FriendNudgeTests.swift` | Mock service and store behavior tests |
| `Daily Music.xcodeproj/project.pbxproj` | Register the new test file in the test target |
| `Daily Music/App/AppEnvironment.swift` | Own and inject nudge + push-registration services/stores |
| `Daily Music/Views/Friends/FriendsView.swift` | Add compact Nudge button to accepted friend rows |
| `Daily Music/Views/Friends/FriendInsightsView.swift` | Add the same Nudge action to the friend-insights header |
| `Daily Music/Services/PushRegistrationService.swift` | Device-token registration protocol, token formatting, mock/live implementations |
| `Daily Music/Daily_MusicApp.swift` | App delegate bridge for APNs device token and notification tap handling |
| `Daily Music/App/RootView.swift` | Accept `dailymusic://today` in the existing URL routing |
| `Daily Music/Services/Supabase/SupabaseFriendNudgeService.swift` | Live nudge service invoking `send-friend-nudge` |
| `docs/superpowers/specs/friend-nudges.sql` | SQL schema, RLS, and token-registration RPCs |
| `supabase/functions/send-friend-nudge/index.ts` | Authenticated Edge Function that validates friendship/cooldown and sends APNs |
| `supabase/functions/send-friend-nudge/README.md` | Deployment and manual test notes |

---

### Task 1: Nudge Service, Store Tests, and Test Target Registration

**Files:**
- Create: `Daily MusicTests/FriendNudgeTests.swift`
- Modify: `Daily Music.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create failing tests**

Create `Daily MusicTests/FriendNudgeTests.swift`:

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct FriendNudgeTests {
    @Test func mockRateLimitsDeliveredNudgeForSameFriend() async throws {
        let friendID = UUID(uuidString: "00000000-0000-0000-0000-00000000A101")!
        let service = MockFriendNudgeService(now: Date(timeIntervalSince1970: 1_000))

        let first = try await service.sendNudge(to: friendID)
        let second = try await service.sendNudge(to: friendID)

        #expect(first == .sent)
        guard case .rateLimited(let nextAllowedAt) = second else {
            Issue.record("Expected second nudge to be rate limited")
            return
        }
        #expect(nextAllowedAt == Date(timeIntervalSince1970: 1_000 + 86_400))
    }

    @Test func mockDoesNotRateLimitNoTokenAttempt() async throws {
        let friendID = UUID(uuidString: "00000000-0000-0000-0000-00000000A102")!
        let service = MockFriendNudgeService(
            now: Date(timeIntervalSince1970: 1_000),
            recipientsWithoutTokens: [friendID]
        )

        let first = try await service.sendNudge(to: friendID)
        let second = try await service.sendNudge(to: friendID)

        #expect(first == .noRecipientToken)
        #expect(second == .noRecipientToken)
    }

    @Test func mockAllowsSameFriendAfterTwentyFourHours() async throws {
        let friendID = UUID(uuidString: "00000000-0000-0000-0000-00000000A103")!
        let service = MockFriendNudgeService(now: Date(timeIntervalSince1970: 1_000))

        _ = try await service.sendNudge(to: friendID)
        await service.setNow(Date(timeIntervalSince1970: 1_000 + 86_401))
        let result = try await service.sendNudge(to: friendID)

        #expect(result == .sent)
    }

    @Test func storeMapsSuccessAndRateLimitStates() async {
        let friend = makeFriend(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A104")!)
        let service = MockFriendNudgeService(now: Date(timeIntervalSince1970: 2_000))
        let store = FriendNudgeStore(service: service)

        await store.send(to: friend)
        #expect(store.state(for: friend) == .sent)
        #expect(store.buttonTitle(for: friend) == "Nudged")
        #expect(store.isDisabled(for: friend))

        await store.resetTransientState(for: friend)
        await store.send(to: friend)

        guard case .rateLimited(let nextAllowedAt) = store.state(for: friend) else {
            Issue.record("Expected store state to be rate limited")
            return
        }
        #expect(nextAllowedAt == Date(timeIntervalSince1970: 2_000 + 86_400))
        #expect(store.buttonTitle(for: friend) == "Nudged today")
        #expect(store.isDisabled(for: friend))
    }

    @Test func storeMapsNoRecipientToken() async {
        let friendID = UUID(uuidString: "00000000-0000-0000-0000-00000000A105")!
        let friend = makeFriend(id: friendID)
        let service = MockFriendNudgeService(
            now: Date(timeIntervalSince1970: 3_000),
            recipientsWithoutTokens: [friendID]
        )
        let store = FriendNudgeStore(service: service)

        await store.send(to: friend)

        #expect(store.state(for: friend) == .noRecipientToken)
        #expect(store.message(for: friend) == "They need notifications enabled first.")
        #expect(!store.isDisabled(for: friend))
    }

    @Test func storeKeepsDifferentFriendsIndependent() async {
        let alex = makeFriend(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A106")!, name: "Alex")
        let sam = makeFriend(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A107")!, name: "Sam")
        let service = MockFriendNudgeService(now: Date(timeIntervalSince1970: 4_000))
        let store = FriendNudgeStore(service: service)

        await store.send(to: alex)

        #expect(store.state(for: alex) == .sent)
        #expect(store.state(for: sam) == .idle)
        #expect(!store.isDisabled(for: sam))
    }

    private func makeFriend(id: UUID, name: String = "Friend") -> Friend {
        Friend(
            friendshipID: UUID(),
            profile: UserProfile(id: id, displayName: name, avatarURL: nil)
        )
    }
}
```

- [ ] **Step 2: Register `FriendNudgeTests.swift` in the test target**

Modify `Daily Music.xcodeproj/project.pbxproj`:

In `PBXBuildFile section`, add:

```pbxproj
		ABCD00112233445566778899 /* FriendNudgeTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = ABCD0011223344556677889A /* FriendNudgeTests.swift */; };
```

In `PBXFileReference section`, add:

```pbxproj
		ABCD0011223344556677889A /* FriendNudgeTests.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = FriendNudgeTests.swift; sourceTree = "<group>"; };
```

In the `474DB509253B3672F8A852C1 /* Daily MusicTests */` children list, add the new file after `FriendsStoreTests.swift`:

```pbxproj
				ABCD0011223344556677889A /* FriendNudgeTests.swift */,
```

In the `6789B102B0603D9006D93D6A /* Sources */` files list, add:

```pbxproj
				ABCD00112233445566778899 /* FriendNudgeTests.swift in Sources */,
```

- [ ] **Step 3: Run the new tests and verify they fail**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4' \
  -only-testing:"Daily MusicTests/FriendNudgeTests"
```

Expected: FAIL with errors such as `Cannot find 'MockFriendNudgeService' in scope` and `Cannot find 'FriendNudgeStore' in scope`.

- [ ] **Step 4: Commit failing tests**

```bash
git add "Daily MusicTests/FriendNudgeTests.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "test(friends): cover friend nudge states"
```

---

### Task 2: Friend Nudge Service and Store

**Files:**
- Create: `Daily Music/Services/FriendNudgeService.swift`
- Create: `Daily Music/ViewModels/FriendNudgeStore.swift`

- [ ] **Step 1: Add the nudge service**

Create `Daily Music/Services/FriendNudgeService.swift`:

```swift
//
//  FriendNudgeService.swift
//  Daily Music
//
//  Sends small, fixed friend-to-friend nudges. The mock is fully deterministic
//  for tests; the live implementation invokes a Supabase Edge Function.
//

import Foundation

enum FriendNudgeResult: Equatable, Sendable {
    case sent
    case noRecipientToken
    case rateLimited(nextAllowedAt: Date?)
}

enum FriendNudgeError: LocalizedError, Sendable {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}

protocol FriendNudgeService: Sendable {
    func sendNudge(to friendID: UUID) async throws -> FriendNudgeResult
}

actor MockFriendNudgeService: FriendNudgeService {
    static let cooldown: TimeInterval = 86_400

    private var now: Date
    private var sentAt: [UUID: Date] = [:]
    private var recipientsWithoutTokens: Set<UUID>

    init(
        now: Date = Date(),
        recipientsWithoutTokens: Set<UUID> = []
    ) {
        self.now = now
        self.recipientsWithoutTokens = recipientsWithoutTokens
    }

    func setNow(_ date: Date) {
        now = date
    }

    func setRecipientWithoutToken(_ friendID: UUID, enabled: Bool) {
        if enabled {
            recipientsWithoutTokens.insert(friendID)
        } else {
            recipientsWithoutTokens.remove(friendID)
        }
    }

    func sendNudge(to friendID: UUID) async throws -> FriendNudgeResult {
        if let lastSent = sentAt[friendID],
           now.timeIntervalSince(lastSent) < Self.cooldown {
            return .rateLimited(nextAllowedAt: lastSent.addingTimeInterval(Self.cooldown))
        }

        if recipientsWithoutTokens.contains(friendID) {
            return .noRecipientToken
        }

        sentAt[friendID] = now
        return .sent
    }
}
```

- [ ] **Step 2: Add the nudge store**

Create `Daily Music/ViewModels/FriendNudgeStore.swift`:

```swift
//
//  FriendNudgeStore.swift
//  Daily Music
//
//  View-facing state for per-friend nudge buttons.
//

import Foundation

enum FriendNudgeState: Equatable, Sendable {
    case idle
    case sending
    case sent
    case noRecipientToken
    case rateLimited(nextAllowedAt: Date?)
    case failed(String)
}

@MainActor
@Observable
final class FriendNudgeStore {
    private let service: FriendNudgeService
    private(set) var states: [UUID: FriendNudgeState] = [:]

    init(service: FriendNudgeService) {
        self.service = service
    }

    func state(for friend: Friend) -> FriendNudgeState {
        states[friend.profile.id] ?? .idle
    }

    func send(to friend: Friend) async {
        let friendID = friend.profile.id
        guard !isDisabled(for: friend) else { return }

        states[friendID] = .sending
        do {
            let result = try await service.sendNudge(to: friendID)
            switch result {
            case .sent:
                states[friendID] = .sent
            case .noRecipientToken:
                states[friendID] = .noRecipientToken
            case .rateLimited(let nextAllowedAt):
                states[friendID] = .rateLimited(nextAllowedAt: nextAllowedAt)
            }
        } catch {
            states[friendID] = .failed(error.localizedDescription)
        }
    }

    func resetTransientState(for friend: Friend) async {
        let friendID = friend.profile.id
        switch states[friendID] {
        case .sent, .noRecipientToken, .failed:
            states[friendID] = .idle
        case .idle, .sending, .rateLimited, nil:
            break
        }
    }

    func buttonTitle(for friend: Friend) -> String {
        switch state(for: friend) {
        case .idle, .failed:
            "Nudge"
        case .sending:
            "Sending"
        case .sent:
            "Nudged"
        case .noRecipientToken:
            "Nudge"
        case .rateLimited:
            "Nudged today"
        }
    }

    func iconName(for friend: Friend) -> String {
        switch state(for: friend) {
        case .idle, .failed, .noRecipientToken:
            "bell.badge"
        case .sending:
            "hourglass"
        case .sent, .rateLimited:
            "checkmark.circle.fill"
        }
    }

    func message(for friend: Friend) -> String? {
        switch state(for: friend) {
        case .noRecipientToken:
            "They need notifications enabled first."
        case .failed(let message):
            message
        case .rateLimited:
            "You already nudged them today."
        case .idle, .sending, .sent:
            nil
        }
    }

    func isDisabled(for friend: Friend) -> Bool {
        switch state(for: friend) {
        case .sending, .sent, .rateLimited:
            true
        case .idle, .noRecipientToken, .failed:
            false
        }
    }
}
```

- [ ] **Step 3: Run the new tests and verify they pass**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4' \
  -only-testing:"Daily MusicTests/FriendNudgeTests"
```

Expected: PASS for all tests in `FriendNudgeTests`.

- [ ] **Step 4: Commit service and store**

```bash
git add "Daily Music/Services/FriendNudgeService.swift" "Daily Music/ViewModels/FriendNudgeStore.swift"
git commit -m "feat(friends): add friend nudge service and store"
```

---

### Task 3: Wire Nudge Dependencies Into AppEnvironment

**Files:**
- Modify: `Daily Music/App/AppEnvironment.swift`

- [ ] **Step 1: Add properties and init parameters**

In `AppEnvironment`, add stored properties next to `friends` and `friendsStore`:

```swift
    let friendNudges: FriendNudgeService
    let friendNudgeStore: FriendNudgeStore
```

Add an init parameter after `friends: FriendService`:

```swift
        friendNudges: FriendNudgeService,
```

Assign the service after `self.friends = friends`:

```swift
        self.friendNudges = friendNudges
```

Create the store after `self.friendsStore = FriendsStore(service: friends)`:

```swift
        self.friendNudgeStore = FriendNudgeStore(service: friendNudges)
```

- [ ] **Step 2: Wire mock and live factories**

In `static func mock()`, add:

```swift
            friendNudges: MockFriendNudgeService(),
```

immediately after:

```swift
            friends: MockFriendService(),
```

In `static func live()`, add the mock service for this checkpoint:

```swift
            friendNudges: MockFriendNudgeService(),
```

immediately after:

```swift
            friends: SupabaseFriendService(),
```

The live factory intentionally uses the mock nudge service until Task 8 adds `SupabaseFriendNudgeService`.

- [ ] **Step 3: Build**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4'
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit environment wiring**

```bash
git add "Daily Music/App/AppEnvironment.swift"
git commit -m "feat(friends): wire nudge store into environment"
```

---

### Task 4: Friends UI Nudge Buttons

**Files:**
- Modify: `Daily Music/Views/Friends/FriendsView.swift`
- Modify: `Daily Music/Views/Friends/FriendInsightsView.swift`

- [ ] **Step 1: Add a nudge helper to `FriendsView`**

In `FriendsView`, add this helper above `shareButtonLabel(_:)`:

```swift
    private func nudgeButton(_ friend: Friend) -> some View {
        let nudgeStore = env.friendNudgeStore

        return VStack(alignment: .trailing, spacing: 4) {
            Button {
                Task { await nudgeStore.send(to: friend) }
            } label: {
                Label(
                    nudgeStore.buttonTitle(for: friend),
                    systemImage: nudgeStore.iconName(for: friend)
                )
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(nudgeStore.isDisabled(for: friend))
            .accessibilityHint("Send a push notification encouraging them to check Daily Music")

            if let message = nudgeStore.message(for: friend) {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140, alignment: .trailing)
            }
        }
    }
```

- [ ] **Step 2: Replace the friend-row `NavigationLink` label**

In `friendsSection`, replace the `ForEach(store.friends) { friend in ... }` body with this structure:

```swift
                ForEach(store.friends) { friend in
                    HStack(spacing: 10) {
                        NavigationLink {
                            FriendInsightsView(friend: friend, onOpenEntry: onOpenEntry)
                        } label: {
                            HStack(spacing: 12) {
                                avatar(friend.profile, size: 48)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(friend.profile.displayName ?? "Friend")
                                        .font(.headline)
                                    Text("Open their taste mirror")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 8)
                        nudgeButton(friend)
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) { Task { await store.remove(friend) } }
                    }
                }
```

This keeps row navigation on the profile/name area and prevents the Nudge button from opening the friend screen.

- [ ] **Step 3: Add the nudge action to the friend-insights header**

In `FriendInsightsView.header`, replace:

```swift
            Spacer(minLength: 0)
```

with:

```swift
            Spacer(minLength: 0)
            headerNudgeButton
```

Then add this computed view below `header`:

```swift
    private var headerNudgeButton: some View {
        let nudgeStore = env.friendNudgeStore

        return Button {
            Task { await nudgeStore.send(to: friend) }
        } label: {
            Label(
                nudgeStore.buttonTitle(for: friend),
                systemImage: nudgeStore.iconName(for: friend)
            )
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(nudgeStore.isDisabled(for: friend))
        .accessibilityHint("Send a push notification encouraging them to check Daily Music")
    }
```

- [ ] **Step 4: Build and manually inspect**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4'
```

Expected: `BUILD SUCCEEDED`.

Manual check in the simulator or in-app browser-backed app view:

- Friends tab with accepted friends shows compact `Nudge` buttons.
- Empty friends state has no nudge controls.
- Request rows have no nudge controls.
- Tapping the profile/name area opens friend insights.
- Tapping Nudge changes the button to `Nudged`.

- [ ] **Step 5: Commit UI**

```bash
git add "Daily Music/Views/Friends/FriendsView.swift" "Daily Music/Views/Friends/FriendInsightsView.swift"
git commit -m "feat(friends): add nudge controls"
```

---

### Task 5: Push Registration Service and App Lifecycle Bridge

**Files:**
- Create: `Daily Music/Services/PushRegistrationService.swift`
- Modify: `Daily Music/Daily_MusicApp.swift`
- Modify: `Daily Music/App/AppEnvironment.swift`
- Modify: `Daily Music/App/RootView.swift`
- Modify: `Daily MusicTests/FriendNudgeTests.swift`

- [ ] **Step 1: Add token-format test**

Append this test to `FriendNudgeTests`:

```swift
    @Test func deviceTokenFormatsAsLowercaseHex() {
        let token = Data([0x00, 0x0f, 0xa1, 0xff])
        #expect(token.apnsHexString == "000fa1ff")
    }
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4' \
  -only-testing:"Daily MusicTests/FriendNudgeTests/deviceTokenFormatsAsLowercaseHex"
```

Expected: FAIL with `Value of type 'Data' has no member 'apnsHexString'`.

- [ ] **Step 3: Create push registration service**

Create `Daily Music/Services/PushRegistrationService.swift`:

```swift
//
//  PushRegistrationService.swift
//  Daily Music
//
//  Registers APNs device tokens with Supabase. This is separate from
//  NotificationService, which only owns local daily reminders.
//

import Foundation
import Supabase

protocol PushRegistrationService: Sendable {
    func registerDeviceToken(_ token: Data) async throws
    func unregisterCurrentDevice() async throws
}

extension Data {
    var apnsHexString: String {
        map { String(format: "%02.2hhx", $0) }.joined()
    }
}

actor MockPushRegistrationService: PushRegistrationService {
    private(set) var registeredToken: String?

    func registerDeviceToken(_ token: Data) async throws {
        registeredToken = token.apnsHexString
    }

    func unregisterCurrentDevice() async throws {
        registeredToken = nil
    }
}

actor SupabasePushRegistrationService: PushRegistrationService {
    private let client = Supa.client
    private var currentToken: String?

    func registerDeviceToken(_ token: Data) async throws {
        let value = token.apnsHexString
        currentToken = value
        try await client.rpc(
            "register_push_token",
            params: RegisterPushTokenParams(
                p_token: value,
                p_platform: "ios",
                p_environment: Self.apnsEnvironment
            )
        )
        .execute()
    }

    func unregisterCurrentDevice() async throws {
        guard let currentToken else { return }
        try await client.rpc("unregister_push_token", params: ["p_token": currentToken]).execute()
        self.currentToken = nil
    }

    private static var apnsEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}

private struct RegisterPushTokenParams: Encodable {
    let p_token: String
    let p_platform: String
    let p_environment: String
}
```

- [ ] **Step 4: Wire push registration into `AppEnvironment`**

Add a property after `notifications`:

```swift
    let pushRegistration: PushRegistrationService
```

Add an init parameter after `notifications: NotificationService`:

```swift
        pushRegistration: PushRegistrationService,
```

Assign it after `self.notifications = notifications`:

```swift
        self.pushRegistration = pushRegistration
```

In `mock()`, add after `notifications: LocalNotificationService(),`:

```swift
            pushRegistration: MockPushRegistrationService(),
```

In `live()`, add after `notifications: LocalNotificationService(),`:

```swift
            pushRegistration: SupabasePushRegistrationService(),
```

- [ ] **Step 5: Add app delegate bridge**

In `Daily Music/Daily_MusicApp.swift`, add UIKit and UserNotifications imports below `import SwiftUI`:

```swift
import SwiftUI
import UIKit
import UserNotifications
```

Add this class above `@main`:

```swift
final class AppPushDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var registration: PushRegistrationService?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { try? await Self.registration?.registerDeviceToken(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("Remote notification registration failed: \(error.localizedDescription)")
        #endif
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard
            let value = response.notification.request.content.userInfo["url"] as? String,
            let url = URL(string: value)
        else { return }

        await MainActor.run {
            UIApplication.shared.open(url)
        }
    }
}
```

Inside `Daily_MusicApp`, add an app delegate property above the existing environment state:

```swift
    @UIApplicationDelegateAdaptor(AppPushDelegate.self) private var pushDelegate
```

Add this helper inside `Daily_MusicApp` below `body`:

```swift
    private func installPushRegistration(for env: AppEnvironment) {
        AppPushDelegate.registration = env.pushRegistration
        Task {
            let status = await env.notifications.authorizationStatus()
            guard status == .authorized || status == .provisional || status == .ephemeral else { return }
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
```

In both DEBUG and release `RootView()` chains, add:

```swift
                .onAppear { installPushRegistration(for: env) }
```

In the DEBUG `.onChange(of: useMock)` block, after `env = mock ? .mock() : .live()`, add:

```swift
                    installPushRegistration(for: env)
```

- [ ] **Step 6: Route `dailymusic://today`**

In `RootView.onOpenURL`, replace the existing friend-only guard with:

```swift
            guard url.scheme == "dailymusic" else { return }
            if url.host == "friend" {
                let code = url.lastPathComponent
                if !code.isEmpty { UserDefaults.standard.set(code, forKey: "pendingFriendCode") }
            } else if url.host == "today" {
                UserDefaults.standard.set(true, forKey: "pendingTodayRoute")
            }
```

The `pendingTodayRoute` flag intentionally does not need UI handling yet because opening the app root already lands the signed-in user in `MainTabView`, whose first tab is Today.

- [ ] **Step 7: Run tests and build**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4' \
  -only-testing:"Daily MusicTests/FriendNudgeTests"
```

Expected: PASS.

Then run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4'
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit push-registration bridge**

```bash
git add \
  "Daily Music/Services/PushRegistrationService.swift" \
  "Daily Music/Daily_MusicApp.swift" \
  "Daily Music/App/AppEnvironment.swift" \
  "Daily Music/App/RootView.swift" \
  "Daily MusicTests/FriendNudgeTests.swift"
git commit -m "feat(push): register friend nudge device tokens"
```

---

### Task 6: Supabase SQL for Tokens and Nudge Audit

**Files:**
- Create: `docs/superpowers/specs/friend-nudges.sql`

- [ ] **Step 1: Create SQL script**

Create `docs/superpowers/specs/friend-nudges.sql`:

```sql
-- Friend nudges schema and RPCs
-- Apply manually in Supabase SQL editor or via psql.

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios')),
  token text not null,
  environment text not null check (environment in ('sandbox', 'production')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, token)
);

alter table public.push_tokens enable row level security;

drop policy if exists "push tokens select own" on public.push_tokens;
create policy "push tokens select own" on public.push_tokens
  for select using (user_id = auth.uid());

drop policy if exists "push tokens insert own" on public.push_tokens;
create policy "push tokens insert own" on public.push_tokens
  for insert with check (user_id = auth.uid());

drop policy if exists "push tokens update own" on public.push_tokens;
create policy "push tokens update own" on public.push_tokens
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "push tokens delete own" on public.push_tokens;
create policy "push tokens delete own" on public.push_tokens
  for delete using (user_id = auth.uid());

create table if not exists public.friend_nudges (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('sent', 'no_tokens', 'rate_limited', 'failed')),
  apns_id text,
  error text,
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

alter table public.friend_nudges enable row level security;

create index if not exists friend_nudges_pair_created_idx
  on public.friend_nudges (sender_id, recipient_id, created_at desc);

drop policy if exists "friend nudges select own" on public.friend_nudges;
create policy "friend nudges select own" on public.friend_nudges
  for select using (sender_id = auth.uid() or recipient_id = auth.uid());

create or replace function public.register_push_token(
  p_token text,
  p_platform text,
  p_environment text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  if p_platform <> 'ios' then
    raise exception 'Unsupported push platform';
  end if;

  if p_environment not in ('sandbox', 'production') then
    raise exception 'Unsupported push environment';
  end if;

  insert into public.push_tokens (user_id, platform, token, environment, last_seen_at)
  values (auth.uid(), p_platform, p_token, p_environment, now())
  on conflict (user_id, token) do update
    set platform = excluded.platform,
        environment = excluded.environment,
        last_seen_at = excluded.last_seen_at;
end;
$$;

create or replace function public.unregister_push_token(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.push_tokens
  where user_id = auth.uid()
    and token = p_token;
$$;

grant execute on function public.register_push_token(text, text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;
```

- [ ] **Step 2: Validate SQL locally by inspection**

Run:

```bash
rg -n "push_tokens|friend_nudges|register_push_token|unregister_push_token|friend nudges select own" docs/superpowers/specs/friend-nudges.sql
```

Expected: output includes both tables, both RPC names, and all RLS policies.

- [ ] **Step 3: Commit SQL**

```bash
git add docs/superpowers/specs/friend-nudges.sql
git commit -m "docs: add friend nudges sql"
```

---

### Task 7: Supabase Edge Function for Sending Nudges

**Files:**
- Create: `supabase/functions/send-friend-nudge/index.ts`
- Create: `supabase/functions/send-friend-nudge/README.md`

- [ ] **Step 1: Add Edge Function**

Create `supabase/functions/send-friend-nudge/index.ts`:

```ts
// send-friend-nudge - validates a one-to-one friend nudge and sends APNs.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type PushToken = {
  token: string;
  environment: "sandbox" | "production";
};

type NudgeStatus = "sent" | "no_tokens" | "rate_limited" | "failed";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function base64url(input: string | ArrayBuffer): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll("\\n", "")
    .replaceAll("\n", "")
    .trim();
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function apnsJWT(): Promise<string> {
  const header = {
    alg: "ES256",
    kid: requiredEnv("APNS_KEY_ID"),
  };
  const claims = {
    iss: requiredEnv("APNS_TEAM_ID"),
    iat: Math.floor(Date.now() / 1000),
  };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(requiredEnv("APNS_PRIVATE_KEY")),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(signature)}`;
}

function apnsHost(environment: string): string {
  return environment === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
}

function notificationBody(senderName: string): string {
  return `${senderName} nudged you to check Daily Music.`;
}

function apnsPayload(senderName: string): Record<string, unknown> {
  return {
    aps: {
      alert: {
        title: "Daily Music",
        body: notificationBody(senderName),
      },
      sound: "default",
    },
    url: "dailymusic://today",
    type: "friend_nudge",
  };
}

async function insertAudit(
  admin: ReturnType<typeof createClient>,
  senderID: string,
  recipientID: string,
  status: NudgeStatus,
  apnsID: string | null = null,
  error: string | null = null,
) {
  await admin.from("friend_nudges").insert({
    sender_id: senderID,
    recipient_id: recipientID,
    status,
    apns_id: apnsID,
    error,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

    const body = await req.json().catch(() => ({}));
    const recipientID = String(body.recipient_id ?? "");
    if (!recipientID) return json({ error: "Missing recipient_id" }, 400);

    const userClient = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_ANON_KEY"),
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return json({ error: "Invalid or expired session" }, 401);

    const senderID = user.id;
    if (senderID === recipientID) return json({ error: "You cannot nudge yourself." }, 400);

    const admin = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    );

    const { data: areFriends, error: friendError } = await admin.rpc("are_friends", {
      a: senderID,
      b: recipientID,
    });
    if (friendError) return json({ error: friendError.message }, 500);
    if (!areFriends) return json({ error: "You can only nudge accepted friends." }, 403);

    const cooldownStart = new Date(Date.now() - 86_400_000).toISOString();
    const { data: recentSent, error: recentError } = await admin
      .from("friend_nudges")
      .select("created_at")
      .eq("sender_id", senderID)
      .eq("recipient_id", recipientID)
      .eq("status", "sent")
      .gte("created_at", cooldownStart)
      .limit(1);
    if (recentError) return json({ error: recentError.message }, 500);
    if (recentSent && recentSent.length > 0) {
      const lastSentAt = new Date(recentSent[0].created_at).getTime();
      const nextAllowedAt = new Date(lastSentAt + 86_400_000).toISOString();
      await insertAudit(admin, senderID, recipientID, "rate_limited");
      return json({ status: "rate_limited", next_allowed_at: nextAllowedAt }, 200);
    }

    const { data: profile } = await admin
      .from("profiles")
      .select("display_name")
      .eq("id", senderID)
      .maybeSingle();
    const senderName = (profile?.display_name as string | undefined)?.trim() || "A friend";

    const configuredEnvironment = requiredEnv("APNS_ENVIRONMENT");
    if (configuredEnvironment !== "sandbox" && configuredEnvironment !== "production") {
      return json({ error: "APNS_ENVIRONMENT must be sandbox or production" }, 500);
    }

    const { data: tokens, error: tokenError } = await admin
      .from("push_tokens")
      .select("token,environment")
      .eq("user_id", recipientID)
      .eq("environment", configuredEnvironment);
    if (tokenError) return json({ error: tokenError.message }, 500);

    const pushTokens = (tokens ?? []) as PushToken[];
    if (pushTokens.length === 0) {
      await insertAudit(admin, senderID, recipientID, "no_tokens");
      return json({ status: "no_tokens" }, 200);
    }

    const jwt = await apnsJWT();
    const topic = requiredEnv("APNS_TOPIC");
    const payload = JSON.stringify(apnsPayload(senderName));
    const errors: string[] = [];
    const apnsIDs: string[] = [];

    for (const token of pushTokens) {
      const response = await fetch(`https://${apnsHost(configuredEnvironment)}/3/device/${token.token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": topic,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "content-type": "application/json",
        },
        body: payload,
      });

      const apnsID = response.headers.get("apns-id");
      if (apnsID) apnsIDs.push(apnsID);
      if (!response.ok) {
        const text = await response.text();
        errors.push(`${response.status}: ${text}`);
      }
    }

    if (apnsIDs.length > 0) {
      await insertAudit(admin, senderID, recipientID, "sent", apnsIDs.join(","));
      return json({ status: "sent" }, 200);
    }

    await insertAudit(admin, senderID, recipientID, "failed", null, errors.join(" | "));
    return json({ status: "failed", error: "APNs rejected every registered device." }, 502);
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
```

- [ ] **Step 2: Add Edge Function README**

Create `supabase/functions/send-friend-nudge/README.md`:

````markdown
# send-friend-nudge Edge Function

Sends a fixed friend-to-friend APNs notification after verifying the caller is
signed in, the recipient is an accepted friend, and the sender has not delivered
a nudge to the same recipient in the last 24 hours.

## Deploy

```bash
supabase functions deploy send-friend-nudge
```

## Required secrets

```bash
supabase secrets set APNS_TEAM_ID=<team-id>
supabase secrets set APNS_KEY_ID=<key-id>
supabase secrets set APNS_PRIVATE_KEY="$(cat AuthKey_<key-id>.p8)"
supabase secrets set APNS_TOPIC=maxhagi.Daily-Music
supabase secrets set APNS_ENVIRONMENT=sandbox
```

Set `APNS_ENVIRONMENT=production` for the App Store build. The function only
sends to device tokens registered for the configured environment.

## Manual test

```bash
curl -i -X POST \
  "https://jgzegntiwdrotkrswjba.supabase.co/functions/v1/send-friend-nudge" \
  -H "Authorization: Bearer <USER_ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"recipient_id":"<ACCEPTED_FRIEND_USER_ID>"}'
```

Expected successful response:

```json
{"status":"sent"}
```
````

- [ ] **Step 3: Check the function and docs by search**

Run:

```bash
rg -n "are_friends|friend_nudges|push_tokens|APNS_TOPIC|dailymusic://today|rate_limited|no_tokens" supabase/functions/send-friend-nudge docs/superpowers/specs/friend-nudges.sql
```

Expected: each key term appears in the Edge Function or SQL file.

- [ ] **Step 4: Commit Edge Function**

```bash
git add supabase/functions/send-friend-nudge
git commit -m "feat(functions): add friend nudge sender"
```

---

### Task 8: Live Supabase Nudge Service

**Files:**
- Create: `Daily Music/Services/Supabase/SupabaseFriendNudgeService.swift`
- Modify: `Daily Music/App/AppEnvironment.swift`

- [ ] **Step 1: Add live service**

Create `Daily Music/Services/Supabase/SupabaseFriendNudgeService.swift`:

```swift
//
//  SupabaseFriendNudgeService.swift
//  Daily Music
//
//  Live friend nudges via the send-friend-nudge Edge Function.
//

import Foundation
import Supabase

final class SupabaseFriendNudgeService: FriendNudgeService {
    private let client = Supa.client

    func sendNudge(to friendID: UUID) async throws -> FriendNudgeResult {
        let request = FriendNudgeRequest(recipient_id: friendID)
        let response: FriendNudgeResponse = try await client.functions.invoke(
            "send-friend-nudge",
            options: FunctionInvokeOptions(body: request)
        )

        switch response.status {
        case "sent":
            return .sent
        case "no_tokens":
            return .noRecipientToken
        case "rate_limited":
            return .rateLimited(nextAllowedAt: response.next_allowed_at)
        case "failed":
            throw FriendNudgeError.message(response.error ?? "The nudge could not be sent.")
        default:
            throw FriendNudgeError.message("The nudge response was not recognized.")
        }
    }
}

private struct FriendNudgeRequest: Encodable {
    let recipient_id: UUID
}

private struct FriendNudgeResponse: Decodable {
    let status: String
    let next_allowed_at: Date?
    let error: String?
}
```

- [ ] **Step 2: Wire live factory**

In `AppEnvironment.live()`, replace:

```swift
            friendNudges: MockFriendNudgeService(),
```

with:

```swift
            friendNudges: SupabaseFriendNudgeService(),
```

- [ ] **Step 3: Build**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4'
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit live service**

```bash
git add "Daily Music/Services/Supabase/SupabaseFriendNudgeService.swift" "Daily Music/App/AppEnvironment.swift"
git commit -m "feat(friends): send live friend nudges"
```

---

### Task 9: Final Verification

**Files:**
- No new files

- [ ] **Step 1: Run focused tests**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4' \
  -only-testing:"Daily MusicTests/FriendNudgeTests"
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 2: Run full test suite**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4'
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 3: Run full build**

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=14497FA6-E390-4582-8524-F7B12B1DC9E4'
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manual app checks**

Use the DEBUG mock environment first:

- Accepted friend row shows `Nudge`.
- Tapping `Nudge` changes the row button to `Nudged`.
- Tapping the same friend nudge again after resetting transient state returns `Nudged today`.
- Incoming request rows do not show `Nudge`.
- Empty friends state does not show `Nudge`.
- Friend insights header shows the same nudge state as the row.
- Share invite buttons still use the existing left-aligned label behavior.

Use a physical device for live APNs:

- Apply `docs/superpowers/specs/friend-nudges.sql` to Supabase.
- Deploy `send-friend-nudge`.
- Set APNs secrets.
- Install the app on two signed-in accounts that are accepted friends.
- Grant notifications on the recipient device.
- Send a nudge from the sender device.
- Confirm the recipient receives `Daily Music` with body `"<Display Name> nudged you to check Daily Music."`
- Tap the notification and confirm the app opens.

- [ ] **Step 5: Final status**

Run:

```bash
git status --short
```

Expected: no uncommitted nudge implementation files. If unrelated pre-existing files remain modified, call them out without reverting them.
