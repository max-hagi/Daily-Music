# Listening Transition Fluidity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Today-to-Listening entry consistent and flash-free, then make Listening-to-Today dismissal follow the user's finger with locked-axis gesture handling and velocity-aware settling.

**Architecture:** `TodayView` owns a tested `TodayListeningPhase` and the shared `presentation` value. `ListeningView` reports direct drag progress through the existing presentation binding and uses callbacks to tell Today when an interactive dismissal starts or cancels. Pure lifecycle, axis, progress, and velocity helpers live in `ListeningTransition.swift` and are covered before SwiftUI wiring changes.

**Tech Stack:** Swift 5, SwiftUI, Swift Testing, Xcode 26.5 simulator.

## Global Constraints

- Keep the custom pull-down entrance and swipe-up exit.
- Do not use `fullScreenCover`, the rejected curtain mask, or `.drawingGroup()`.
- Preserve the arming ring, Reduce Motion behavior, artwork caches, playback controls, and listen threshold.
- Keep Vault and Favorites behavior unchanged unless a default parameter is required for compatibility.
- Run tests on iPhone 17 simulator `0FE45C94-06D9-4521-904B-F5C95960DEE6`.

---

### Task 1: Add Testable Transition Lifecycle and Gesture Math

**Files:**
- Modify: `Daily Music/Views/Components/ListeningTransition.swift`
- Modify: `Daily MusicTests/TodayListeningTests.swift`

**Interfaces:**
- Produces: `TodayListeningPhase`, including `isMounted`, `isReady`, `canBegin`, and `backingSection`.
- Produces: `TransitionGestureAxis` and `TransitionGestureResolver.axis(horizontal:vertical:)`.
- Produces: `TransitionMath.presentation(forDrag:height:)` and `TransitionMath.initialVelocity(yVelocity:height:from:to:)`.
- Consumes: existing `ImmersiveSection`, `TransitionOutcome`, and `TransitionResolver`.

- [ ] **Step 1: Replace the old backing-section policy tests with failing lifecycle tests**

Add these cases to `TodayListeningTests.swift`:

```swift
struct TodayListeningPhaseTests {
    @Test func enteringMountsPlayerWithoutMovingBackingViewOrStartingPlayback() {
        #expect(TodayListeningPhase.entering.isMounted)
        #expect(TodayListeningPhase.entering.isReady == false)
        #expect(TodayListeningPhase.entering.backingSection == nil)
    }

    @Test func presentedPlayerIsReadyAndHidesJournalHandoff() {
        #expect(TodayListeningPhase.presented.isMounted)
        #expect(TodayListeningPhase.presented.isReady)
        #expect(TodayListeningPhase.presented.backingSection == .journal)
    }

    @Test func dismissingKeepsPlayerMountedAndReadyOverJournal() {
        #expect(TodayListeningPhase.dismissing.isMounted)
        #expect(TodayListeningPhase.dismissing.isReady)
        #expect(TodayListeningPhase.dismissing.backingSection == .journal)
    }

    @Test func idleUnmountsPlayer() {
        #expect(TodayListeningPhase.idle.isMounted == false)
        #expect(TodayListeningPhase.idle.isReady == false)
        #expect(TodayListeningPhase.idle.backingSection == nil)
    }

    @Test func backingViewChangesOnlyAfterEntranceCompletes() {
        let phases: [TodayListeningPhase] = [.idle, .entering, .presented]
        #expect(phases.map(\.backingSection) == [nil, nil, .journal])
    }

    @Test func onlyIdlePhaseCanBeginAnotherEntrance() {
        #expect(TodayListeningPhase.idle.canBegin)
        #expect(TodayListeningPhase.entering.canBegin == false)
        #expect(TodayListeningPhase.presented.canBegin == false)
        #expect(TodayListeningPhase.dismissing.canBegin == false)
    }
}
```

- [ ] **Step 2: Add failing axis, presentation, and velocity tests**

```swift
struct TransitionGestureTests {
    @Test func upwardDominantMovementLocksVerticalDismissal() {
        #expect(TransitionGestureResolver.axis(horizontal: 8, vertical: -20) == .verticalUp)
    }

    @Test func horizontalMovementLocksOutDismissal() {
        #expect(TransitionGestureResolver.axis(horizontal: 20, vertical: -8) == .horizontal)
    }

    @Test func downwardMovementIsIgnored() {
        #expect(TransitionGestureResolver.axis(horizontal: 2, vertical: 20) == .ignored)
    }

    @Test func upwardDragMapsDirectlyToPresentation() {
        #expect(TransitionMath.presentation(forDrag: 0, height: 800) == 1)
        #expect(TransitionMath.presentation(forDrag: 200, height: 800) == 0.75)
        #expect(TransitionMath.presentation(forDrag: 900, height: 800) == 0)
    }

    @Test func presentationMappingHandlesInvalidHeightAndOvershoot() {
        #expect(TransitionMath.presentation(forDrag: 200, height: 0) == 1)
        #expect(TransitionMath.presentation(forDrag: -40, height: 800) == 1)
        #expect(TransitionMath.presentation(forDrag: 1_600, height: 800) == 0)
    }

    @Test func releaseVelocityIsNormalizedToRemainingPresentationDistance() {
        let velocity = TransitionMath.initialVelocity(
            yVelocity: -800,
            height: 800,
            from: 0.75,
            to: 0
        )
        #expect(velocity > 0)
        #expect(velocity.isFinite)
    }
}
```

- [ ] **Step 3: Run the focused tests and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme 'Daily Music' \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -derivedDataPath './build/DerivedData' \
  -only-testing:'Daily MusicTests/TodayListeningPhaseTests' \
  -only-testing:'Daily MusicTests/TransitionGestureTests'
```

Expected: compilation fails because the new lifecycle and gesture APIs do not exist.

- [ ] **Step 4: Implement the minimal lifecycle and gesture helpers**

In `ListeningTransition.swift`, replace `TodayListeningTransitionPhase` and `TodayListeningTransitionPolicy` with:

```swift
enum TodayListeningPhase: Equatable {
    case idle
    case entering
    case presented
    case dismissing

    var isMounted: Bool { self != .idle }
    var isReady: Bool { self == .presented || self == .dismissing }
    var canBegin: Bool { self == .idle }

    var backingSection: ImmersiveSection? {
        isReady ? .journal : nil
    }
}

enum TransitionGestureAxis: Equatable {
    case verticalUp
    case horizontal
    case ignored
}

enum TransitionGestureResolver {
    static func axis(horizontal: Double, vertical: Double) -> TransitionGestureAxis {
        if vertical < 0, abs(vertical) > abs(horizontal) { return .verticalUp }
        if abs(horizontal) >= abs(vertical) { return .horizontal }
        return .ignored
    }
}
```

Extend `TransitionMath` with:

```swift
static func presentation(forDrag drag: Double, height: CGFloat) -> Double {
    guard height > 0 else { return 1 }
    return clamp(1 - drag / Double(height))
}

static func initialVelocity(
    yVelocity: Double,
    height: CGFloat,
    from: Double,
    to: Double
) -> Double {
    guard height > 0 else { return 0 }
    let distance = to - from
    guard abs(distance) > 0.0001 else { return 0 }
    let presentationVelocity = yVelocity / Double(height)
    return min(max(presentationVelocity / distance, -10), 10)
}
```

- [ ] **Step 5: Run the focused tests and verify GREEN**

Run the command from Step 3.

Expected: all `TodayListeningPhaseTests` and `TransitionGestureTests` pass.

- [ ] **Step 6: Commit Task 1**

```bash
git add 'Daily Music/Views/Components/ListeningTransition.swift' \
  'Daily MusicTests/TodayListeningTests.swift'
git commit -m 'test(listening): define fluid transition lifecycle'
```

---

### Task 2: Centralize Today Entrance and Dismissal Sequencing

**Files:**
- Modify: `Daily Music/Views/TodayView.swift`

**Interfaces:**
- Consumes: `TodayListeningPhase.isMounted`, `.isReady`, and `.backingSection` from Task 1.
- Produces for `ListeningView`: `isTransitionReady`, `onDismissalStarted`, and `onDismissalCancelled` arguments.

- [ ] **Step 1: Replace Today's loose mount Boolean with the tested lifecycle phase**

In `TodayView.swift`:

```swift
@State private var listeningPhase: TodayListeningPhase = .idle
```

Remove `showingListening`. Change the enter-ring condition to `!listeningPhase.isMounted`, and change the player-layer condition to `listeningPhase.isMounted`.

- [ ] **Step 2: Route every entrance through one function**

Change the new-drop prompt's `onListen` to:

```swift
onListen: {
    showingNewDropPrompt = false
    beginListening()
}
```

Implement entrance sequencing as:

```swift
private func beginListening() {
    guard listeningPhase.canBegin, loadedEntry != nil else { return }
    presentation = 0
    listeningPhase = .entering

    if reduceMotion {
        presentation = 1
        completeListeningEntrance()
        return
    }

    Task { @MainActor in
        await Task.yield()
        guard listeningPhase == .entering else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            presentation = 1
        } completion: {
            completeListeningEntrance()
        }
    }
}

private func completeListeningEntrance() {
    guard listeningPhase == .entering else { return }
    listeningPhase = .presented
    immersiveScrollPosition = listeningPhase.backingSection
    enterArm = 0
}
```

- [ ] **Step 3: Add one dismissal guard shared by swipe, accessibility, and clip finish**

Pass these callbacks to `ListeningView`:

```swift
isTransitionReady: listeningPhase.isReady,
onDismissalStarted: {
    guard listeningPhase == .presented else { return }
    listeningPhase = .dismissing
    immersiveScrollPosition = listeningPhase.backingSection
},
onDismissalCancelled: {
    guard listeningPhase == .dismissing else { return }
    listeningPhase = .presented
}
```

Update `finishListening()` so `.presented` starts one noninteractive dismissal, `.dismissing` only tears down after `presentation == 0`, and `.idle`/`.entering` ignore duplicate requests. Update teardown to set `.idle`.

- [ ] **Step 4: Build and run lifecycle tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme 'Daily Music' \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -derivedDataPath './build/DerivedData' \
  -only-testing:'Daily MusicTests/TodayListeningPhaseTests'
```

Expected: build succeeds and all lifecycle tests pass.

- [ ] **Step 5: Commit Task 2**

```bash
git add 'Daily Music/Views/TodayView.swift'
git commit -m 'fix(today): sequence listening presentation cleanly'
```

---

### Task 3: Track the Whole Player and Gate Playback Until Ready

**Files:**
- Modify: `Daily Music/Views/ListeningView.swift`
- Modify: `Daily Music/Views/TodayView.swift`
- Test: `Daily MusicTests/TodayListeningTests.swift`

**Interfaces:**
- Consumes: `TransitionGestureAxis`, `TransitionGestureResolver`, and new `TransitionMath` helpers.
- Adds to `ListeningView`: `isTransitionReady: Bool = true`, `onDismissalStarted: (() -> Void)? = nil`, and `onDismissalCancelled: (() -> Void)? = nil`.

- [ ] **Step 1: Add readiness and axis state to `ListeningView`**

Add parameters and state:

```swift
var isTransitionReady: Bool = true
var onDismissalStarted: (() -> Void)? = nil
var onDismissalCancelled: (() -> Void)? = nil

@State private var dismissAxis: TransitionGestureAxis?
```

For Today, pass the values from Task 2. Existing Vault/Favorites call sites use the defaults.

- [ ] **Step 2: Replace the foreground rubber-band with direct presentation updates**

Remove the Today foreground offset/scale. Preserve the lightweight foreground treatment only when `presentation == nil` so archive covers retain their current feedback.

In `dismissGesture.onChanged`:

```swift
if dismissAxis == nil {
    dismissAxis = TransitionGestureResolver.axis(
        horizontal: Double(value.translation.width),
        vertical: Double(value.translation.height)
    )
    if dismissAxis == .verticalUp { onDismissalStarted?() }
}
guard dismissAxis == .verticalUp else { return }

let up = max(0, -Double(value.translation.height))
dismissArm = TransitionMath.armProgress(forDrag: up, height: viewHeight)
presentation?.wrappedValue = TransitionMath.presentation(forDrag: up, height: viewHeight)
```

- [ ] **Step 3: Settle with release velocity and reset the axis**

Replace `slidePlayerAway` with one helper that animates to `0` or `1`:

```swift
private func settlePresentation(
    to target: Double,
    yVelocity: Double,
    completion: @escaping () -> Void
) {
    guard let presentation else { completion(); return }
    let initialVelocity = TransitionMath.initialVelocity(
        yVelocity: yVelocity,
        height: viewHeight,
        from: presentation.wrappedValue,
        to: target
    )
    withAnimation(.interpolatingSpring(
        mass: 1,
        stiffness: 190,
        damping: 24,
        initialVelocity: initialVelocity
    )) {
        presentation.wrappedValue = target
    } completion: {
        completion()
    }
}
```

Commit calls `settlePresentation(to: 0, ...)` then `onAdvance()`. Cancel calls `settlePresentation(to: 1, ...)`, resets `dismissArm` and `dismissAxis`, then calls `onDismissalCancelled`. Reduce Motion sets the target immediately and runs the same completion path.

- [ ] **Step 4: Gate playback and repeating animations on readiness**

Change the playback task to use readiness as its identity:

```swift
.task(id: isTransitionReady) {
    guard isTransitionReady else { return }
    if phase == .player {
        await startPlaybackIfNeeded()
    } else {
        try? await Task.sleep(for: .seconds(1.6))
        guard !Task.isCancelled else { return }
        reveal()
    }
}
```

Create `startDecorativeAnimationsIfReady()` with guards for `isTransitionReady` and `reduceMotion`. Call it from `.onAppear` and `.onChange(of: isTransitionReady)`. Start `animate`, `introPulse`, and `swipeHintBob` there, and remove the unconditional hint `.onAppear` mutation.

In the listen-tracker loop, only sample when `isTransitionReady` so entrance time never counts as playback.

- [ ] **Step 5: Run focused transition tests**

Run the Task 1 focused command.

Expected: lifecycle, gesture, resolver, and math suites pass.

- [ ] **Step 6: Run the full suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme 'Daily Music' \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -derivedDataPath './build/DerivedData'
```

Expected: 312 or more tests pass with zero failures.

- [ ] **Step 7: Commit Task 3**

```bash
git add 'Daily Music/Views/ListeningView.swift' \
  'Daily Music/Views/TodayView.swift' \
  'Daily MusicTests/TodayListeningTests.swift'
git commit -m 'fix(listening): track interactive dismissal directly'
```

---

### Task 4: Simulator Interaction and Final Verification

**Files:**
- Modify only if verification exposes a transition-specific defect.

**Interfaces:**
- Consumes the completed transition lifecycle and gesture behavior from Tasks 1-3.

- [ ] **Step 1: Verify the new-drop prompt path**

Use the mock environment in the iPhone 17 simulator. Trigger the new-drop prompt and tap Listen.

Expected: the player visibly enters, Today does not remain on screen with hidden audio, and playback starts only after the player covers Today.

- [ ] **Step 2: Verify pull-to-listen entrance timing**

From the song zone, pull down until armed and release.

Expected: the visible Today content does not jump before the player covers it; once dismissed, the journal is already in place.

- [ ] **Step 3: Verify direct dismissal and cancellation**

Slowly swipe up, pause mid-drag, reverse slightly, then release both below and above the threshold.

Expected: the whole player stays attached to the finger, cancellation returns to rest without a jump, and commit continues with the release velocity.

- [ ] **Step 4: Verify scrubber isolation and race handling**

Scrub horizontally, finish a preview while beginning a dismiss drag, and repeat with Reduce Motion enabled.

Expected: horizontal scrubbing never shifts the player, only one dismissal runs, and Reduce Motion shows no intermediate frame.

- [ ] **Step 5: Run final automated verification**

Run the full-suite command from Task 3, Step 8, then:

```bash
git diff --check
git status --short --branch
```

Expected: all tests pass, `git diff --check` is silent, and only intentional source/test changes are present before the final commit.
