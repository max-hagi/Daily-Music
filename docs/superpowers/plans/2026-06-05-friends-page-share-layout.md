# Friends Page Share Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the Friends tab so friends are the main display and tapping Share invite opens the native iOS share sheet directly.

**Architecture:** Keep the existing `FriendsStore` contract unchanged. The implementation is a presentation-only refactor inside `Views/Friends/FriendsView.swift`: reorder the list, replace the intermediate share sheet with direct `ShareLink` controls, and extract small private view helpers so the send/respond/remove logic remains easy to audit.

**Tech Stack:** SwiftUI, existing `FriendsStore`, existing `FriendCode` normalization, existing `InitialsAvatar`, existing `FriendInsightsView`.

---

## File Structure

Modify only:
- `Daily Music/Views/Friends/FriendsView.swift`

Expected unchanged:
- `Daily Music/ViewModels/FriendsStore.swift`
- `Daily Music/Services/FriendService.swift`
- `Daily Music/Views/Components/QRCodeView.swift`
- `Daily Music/Views/Friends/FriendInsightsView.swift`

Do not add backend, service, or store logic. The point is to prove the screen still uses the same data flow:
- `store.load()`
- pending deep-link prefill from `UserDefaults.standard["pendingFriendCode"]`
- `store.send(code:)`
- `store.respond(_:accept:)`
- `store.remove(_:)`

## Task 1: Remove the redundant share sheet

**Files:**
- Modify: `Daily Music/Views/Friends/FriendsView.swift`

- [ ] **Step 1: Inspect the current share state**

Confirm this exact state exists near the top of `FriendsView`:

```swift
@State private var enteredCode = ""
@State private var showShare = false
@State private var sendError: String?
@FocusState private var isFriendCodeFocused: Bool
```

Confirm this sheet exists on the `List` chain:

```swift
.sheet(isPresented: $showShare) {
    ShareLink(item: friendLink) { Label("Share your invite", systemImage: "square.and.arrow.up") }
        .padding()
        .presentationDetents([.height(120)])
}
```

- [ ] **Step 2: Remove only the obsolete share state and sheet**

Delete `showShare`:

```swift
@State private var enteredCode = ""
@State private var sendError: String?
@FocusState private var isFriendCodeFocused: Bool
```

Delete the whole `.sheet(isPresented: $showShare) { ... }` modifier.

Do not change `friendLink`; it remains:

```swift
private var friendLink: String { "dailymusic://friend/\(store.myCode)" }
```

- [ ] **Step 3: Replace the old button with direct `ShareLink`**

The old button:

```swift
Button { showShare = true } label: {
    Label("Share invite", systemImage: "square.and.arrow.up")
}
.buttonStyle(.bordered)
```

must become:

```swift
ShareLink(item: friendLink) {
    Label("Share invite", systemImage: "square.and.arrow.up")
}
.buttonStyle(.bordered)
```

This preserves the existing payload and removes the second tap.

- [ ] **Step 4: Build-check this isolated change**

Run:

```bash
xcodebuild build -project "Daily Music.xcodeproj" -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: build succeeds. If the named simulator is unavailable, run:

```bash
xcrun simctl list devices available
```

then retry with an available iPhone simulator.

## Task 2: Reorder the Friends tab into a friends-first stack

**Files:**
- Modify: `Daily Music/Views/Friends/FriendsView.swift`

- [ ] **Step 1: Change the `List` ordering**

Replace the current list body:

```swift
List {
    addFriendSection
    if !store.requests.isEmpty { requestsSection }
    friendsSection
}
```

with:

```swift
List {
    friendsSection
    if !store.requests.isEmpty { requestsSection }
    addFriendSection
}
```

This is the smallest change that makes friends the first content without touching store logic.

- [ ] **Step 2: Update the friends section empty state**

Replace:

```swift
Text("No friends yet — share your code to get started.")
    .foregroundStyle(.secondary)
```

with a compact empty-state block that uses direct share:

```swift
VStack(alignment: .leading, spacing: 10) {
    Text("No friends yet")
        .font(.headline)
    Text("Share your invite to start comparing taste mirrors.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    ShareLink(item: friendLink) {
        Label("Share invite", systemImage: "square.and.arrow.up")
    }
    .buttonStyle(.borderedProminent)
}
.padding(.vertical, 6)
```

Do not move the manual code-entry row into this empty state; it stays in `addFriendSection` so there is still one source for send behavior.

- [ ] **Step 3: Make friend rows read as the hero repeated element**

Replace the friend row label:

```swift
HStack(spacing: 12) {
    avatar(friend.profile)
    Text(friend.profile.displayName ?? "Friend").font(.headline)
    Spacer()
}
```

with:

```swift
HStack(spacing: 12) {
    avatar(friend.profile, size: 48)
    VStack(alignment: .leading, spacing: 3) {
        Text(friend.profile.displayName ?? "Friend")
            .font(.headline)
        Text("Open their taste mirror")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    Spacer()
    Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)
}
.padding(.vertical, 6)
```

Keep the existing `NavigationLink` destination and `.swipeActions` exactly as they are.

- [ ] **Step 4: Update `avatar` to support the larger friend rows**

Replace:

```swift
@ViewBuilder private func avatar(_ profile: UserProfile) -> some View {
    if let s = profile.avatarURL, let url = URL(string: s) {
        AsyncImage(url: url) { img in img.resizable().scaledToFill() }
            placeholder: { InitialsAvatar(name: profile.displayName, size: 40) }
            .frame(width: 40, height: 40).clipShape(Circle())
    } else {
        InitialsAvatar(name: profile.displayName, size: 40)
    }
}
```

with:

```swift
@ViewBuilder private func avatar(_ profile: UserProfile, size: CGFloat = 40) -> some View {
    if let s = profile.avatarURL, let url = URL(string: s) {
        AsyncImage(url: url) { img in img.resizable().scaledToFill() }
            placeholder: { InitialsAvatar(name: profile.displayName, size: size) }
            .frame(width: size, height: size)
            .clipShape(Circle())
    } else {
        InitialsAvatar(name: profile.displayName, size: size)
    }
}
```

Existing request rows keep calling `avatar(request.profile)` and therefore keep the 40-point size.

## Task 3: Compact the add-friend section without changing send logic

**Files:**
- Modify: `Daily Music/Views/Friends/FriendsView.swift`

- [ ] **Step 1: Replace the large QR/code poster with a compact invite row**

Inside `addFriendSection`, replace this first block:

```swift
VStack(spacing: 14) {
    QRCodeView(string: friendLink, size: 170)
    Text(store.myCode)
        .font(.system(.title2, design: .monospaced).weight(.bold))
        .tracking(4)
    ShareLink(item: friendLink) {
        Label("Share invite", systemImage: "square.and.arrow.up")
    }
    .buttonStyle(.bordered)
}
.frame(maxWidth: .infinity)
.padding(.vertical, 8)
```

with:

```swift
HStack(spacing: 12) {
    QRCodeView(string: friendLink, size: 52)
    VStack(alignment: .leading, spacing: 4) {
        Text("Your invite")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        Text(store.myCode)
            .font(.system(.headline, design: .monospaced).weight(.bold))
            .tracking(3)
    }
    Spacer()
    ShareLink(item: friendLink) {
        Label("Share", systemImage: "square.and.arrow.up")
    }
    .buttonStyle(.bordered)
}
.padding(.vertical, 4)
```

This keeps QR support available but makes it visually subordinate to the friends list.

- [ ] **Step 2: Keep manual code-entry behavior unchanged**

Leave this logic intact:

```swift
TextField("Enter a 6-digit code", text: $enteredCode)
    .keyboardType(.numberPad)
    .textContentType(.oneTimeCode)
    .focused($isFriendCodeFocused)
    .onChange(of: enteredCode) { _, newValue in
        let digits = String(newValue.filter { FriendCode.alphabet.contains($0) }.prefix(6))
        if digits != newValue { enteredCode = digits }
    }
Button("Send") {
    Task {
        if await store.send(code: enteredCode) {
            enteredCode = ""
            isFriendCodeFocused = false
        }
        sendError = store.errorMessage
    }
}
.disabled(FriendCode.normalize(enteredCode).count != 6)
```

Only adjust spacing or labels around it if the compiler requires type inference help. Do not move the `store.send(code:)` call or change the success/error behavior.

- [ ] **Step 3: Confirm the add section is secondary**

The section header can stay `Section("Add a friend")`, but the first row must now be the compact `HStack`, not the large centered QR poster.

## Task 4: Verification against existing logic

**Files:**
- Test/build: project and existing tests

- [ ] **Step 1: Run the existing FriendsStore tests**

Run:

```bash
xcodebuild test -project "Daily Music.xcodeproj" -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:"Daily MusicTests/FriendsStoreTests"
```

Expected: `FriendsStoreTests.loadPopulatesAndBadgeCounts` and `FriendsStoreTests.approveMovesRequestToFriends` pass.

If the simulator name is unavailable, list devices:

```bash
xcrun simctl list devices available
```

then retry with an available iPhone simulator.

- [ ] **Step 2: Run a full build**

Run:

```bash
xcodebuild build -project "Daily Music.xcodeproj" -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: build succeeds with no Swift compile errors.

- [ ] **Step 3: Manual simulator check**

Launch the app in a simulator and verify:
- Friends tab opens.
- Confirmed friends appear above requests and add-friend controls.
- Tapping a confirmed friend still pushes `FriendInsightsView`.
- Swipe-to-remove still exposes the existing Remove action.
- Request accept/decline buttons still call the existing response actions.
- The code field still filters to six allowed `FriendCode.alphabet` characters.
- Send remains disabled until `FriendCode.normalize(enteredCode).count == 6`.
- Successful send clears `enteredCode` and dismisses keyboard focus.
- Failed send shows `store.errorMessage`.
- Tapping **Share** or **Share invite** opens the native iOS share sheet directly, with no intermediate Daily Music sheet.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git diff -- "Daily Music/Views/Friends/FriendsView.swift"
```

Expected:
- `showShare` state removed.
- `.sheet(isPresented: $showShare)` removed.
- Direct `ShareLink(item: friendLink)` present in the invite controls.
- `store.send`, `store.respond`, and `store.remove` calls still present and semantically unchanged.
- `friendLink` still uses `dailymusic://friend/\(store.myCode)`.

## Task 5: Commit implementation

**Files:**
- Commit: `Daily Music/Views/Friends/FriendsView.swift`

- [ ] **Step 1: Confirm working tree**

Run:

```bash
git status --short
```

Expected: only `Daily Music/Views/Friends/FriendsView.swift` is modified, unless the previous task also intentionally staged this plan file.

- [ ] **Step 2: Stage implementation**

Run:

```bash
git add "Daily Music/Views/Friends/FriendsView.swift"
```

- [ ] **Step 3: Commit implementation**

Run:

```bash
git commit -m "Refine friends page invite layout"
```

Expected: a commit containing the Friends tab implementation.

## Self-Review

Spec coverage:
- Direct share sheet: Task 1.
- Friends-first hierarchy: Task 2.
- Requests remain visible and unchanged: Task 2 and Task 4.
- Compact add-friend panel: Task 3.
- Empty state with direct share: Task 2.
- Existing data flow preserved: File Structure, Task 3, Task 4.
- Verification expectations: Task 4.

Placeholder scan:
- No placeholder markers or undefined later work.

Type consistency:
- Uses existing `FriendsView`, `FriendsStore`, `FriendCode`, `UserProfile`, `DailyEntry`, `QRCodeView`, `InitialsAvatar`, and `FriendInsightsView` names.
- Adds only one helper signature change: `avatar(_ profile: UserProfile, size: CGFloat = 40)`.
