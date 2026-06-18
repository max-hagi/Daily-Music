# Listening Fluidity and Today Scrollbar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Today and Listening follow the user's gesture in both directions and hide only Today's immersive scroll indicator.

**Architecture:** Today owns one normalized `presentation` value and a small lifecycle phase. EntryDetail reports the raw downward pull, Listening reports the raw upward pull, and Today settles the same opaque Listening layer to an endpoint. The existing UIKit host remains compiled but Today no longer uses its independent animator.

**Tech Stack:** Swift 6, SwiftUI, UIKit, Swift Testing, Xcode 26/iOS 26 simulator

## Global Constraints

- Preserve the parent-owned Today artwork backdrop and current arming-ring styling.
- Preserve gesture thresholds, velocity commits, haptics, playback gating, and collection behavior.
- Keep Listening opaque throughout normal motion; never cross-fade Today through it.
- Keep Vault and Favorites behavior unchanged.
- Hide the indicator only for Today's immersive entry and preserve scrolling.
- Reduce Motion uses a short fade instead of vertical travel.
- Preserve unrelated working-tree changes and do not stage implementation files that contain them.

---

## File Structure

- `Daily Music/Views/Components/ListeningTransition.swift`: pure lifecycle, gesture-axis, geometry, and velocity math.
- `Daily Music/Views/EntryDetailView.swift`: Today pull callbacks and scroll-indicator configuration.
- `Daily Music/Views/EntryDetailImmersive.swift`: continuous pull reporting and indicator rendering.
- `Daily Music/Views/TodayView.swift`: sole owner of mount state, presentation, settling, and teardown.
- `Daily Music/Views/ListeningView.swift`: upward-dismiss tracking through an optional presentation binding.
- `Daily MusicTests/TodayListeningTests.swift`: transition and policy regression coverage.
- `Daily Music/Views/Components/UIKitListeningTransitionHost.swift`: retained for source compatibility but unused by Today.

---

### Task 1: Define The Shared Transition Contract

**Files:**
- Modify: `Daily MusicTests/TodayListeningTests.swift`
- Modify: `Daily Music/Views/Components/ListeningTransition.swift`

**Interfaces:**
- Produces: `TodayListeningPhase`, `TransitionGestureAxis`, `TransitionGestureResolver.axis(horizontal:vertical:)`, `TransitionMath.presentation(forPull:height:)`, `TransitionMath.presentation(forDismissDrag:height:)`, and `TransitionMath.initialVelocity(yVelocity:height:from:to:)`.
- Consumes: existing `ImmersiveSection`, `TransitionOutcome`, `TransitionResolver`, and arming-progress helpers.

- [ ] **Step 1: Write failing lifecycle and geometry tests**

Replace the obsolete Today-return assertions with:

```swift
struct TodayListeningPhaseTests {
    @Test func pullMountsWithoutStartingPlayback() {
        #expect(TodayListeningPhase.pulling.isMounted)
        #expect(TodayListeningPhase.pulling.isReady == false)
        #expect(TodayListeningPhase.pulling.backingSection == nil)
    }

    @Test func presentedAndDismissingStayReadyOverTheSong() {
        #expect(TodayListeningPhase.presented.isReady)
        #expect(TodayListeningPhase.dismissing.isReady)
        #expect(TodayListeningPhase.presented.backingSection == .song)
        #expect(TodayListeningPhase.dismissing.backingSection == .song)
    }

    @Test func onlyIdleCanStartANewEntrance() {
        #expect(TodayListeningPhase.idle.canBegin)
        for phase in [TodayListeningPhase.pulling, .entering, .presented, .dismissing] {
            #expect(phase.canBegin == false)
        }
    }
}

struct TransitionGestureTests {
    @Test func axisLocksToAnUpwardDominantDismissal() {
        #expect(TransitionGestureResolver.axis(horizontal: 8, vertical: -20) == .verticalUp)
        #expect(TransitionGestureResolver.axis(horizontal: 20, vertical: -8) == .horizontal)
        #expect(TransitionGestureResolver.axis(horizontal: 2, vertical: 20) == .ignored)
    }

    @Test func pullsAndDismissalsMapOneToOneWithScreenTravel() {
        #expect(TransitionMath.presentation(forPull: 0, height: 800) == 0)
        #expect(TransitionMath.presentation(forPull: 200, height: 800) == 0.25)
        #expect(TransitionMath.presentation(forPull: 900, height: 800) == 1)
        #expect(TransitionMath.presentation(forDismissDrag: 0, height: 800) == 1)
        #expect(TransitionMath.presentation(forDismissDrag: 200, height: 800) == 0.75)
        #expect(TransitionMath.presentation(forDismissDrag: 900, height: 800) == 0)
    }

    @Test func invalidHeightAndOvershootAreSafe() {
        #expect(TransitionMath.presentation(forPull: 200, height: 0) == 0)
        #expect(TransitionMath.presentation(forPull: -40, height: 800) == 0)
        #expect(TransitionMath.presentation(forDismissDrag: 200, height: 0) == 1)
        #expect(TransitionMath.presentation(forDismissDrag: -40, height: 800) == 1)
    }

    @Test func releaseVelocityIsFiniteAndPointsTowardTheTarget() {
        let entrance = TransitionMath.initialVelocity(
            yVelocity: 800, height: 800, from: 0.25, to: 1
        )
        let dismissal = TransitionMath.initialVelocity(
            yVelocity: -800, height: 800, from: 0.75, to: 0
        )
        #expect(entrance > 0 && entrance.isFinite)
        #expect(dismissal > 0 && dismissal.isFinite)
    }
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -derivedDataPath './build/DerivedData' \
  -only-testing:'Daily MusicTests/TodayListeningPhaseTests' \
  -only-testing:'Daily MusicTests/TransitionGestureTests' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because the new APIs do not exist.

- [ ] **Step 3: Implement the pure contract**

```swift
enum TodayListeningPhase: Equatable {
    case idle, pulling, entering, presented, dismissing

    var isMounted: Bool { self != .idle }
    var isReady: Bool { self == .presented || self == .dismissing }
    var canBegin: Bool { self == .idle }
    var backingSection: ImmersiveSection? { isReady ? .song : nil }
}

enum TransitionGestureAxis: Equatable {
    case verticalUp, horizontal, ignored
}

enum TransitionGestureResolver {
    static func axis(horizontal: Double, vertical: Double) -> TransitionGestureAxis {
        if vertical < 0, abs(vertical) > abs(horizontal) { return .verticalUp }
        if abs(horizontal) >= abs(vertical) { return .horizontal }
        return .ignored
    }
}
```

Add to `TransitionMath`:

```swift
static func presentation(forPull pull: Double, height: CGFloat) -> Double {
    guard height > 0 else { return 0 }
    return clamp(pull / Double(height))
}

static func presentation(forDismissDrag drag: Double, height: CGFloat) -> Double {
    guard height > 0 else { return 1 }
    return clamp(1 - drag / Double(height))
}

static func initialVelocity(
    yVelocity: Double, height: CGFloat, from: Double, to: Double
) -> Double {
    guard height > 0 else { return 0 }
    let distance = to - from
    guard abs(distance) > 0.0001 else { return 0 }
    return min(max((yVelocity / Double(height)) / distance, -10), 10)
}
```

- [ ] **Step 4: Run Step 2 again and verify GREEN**

Expected: both selected suites pass.

- [ ] **Step 5: Check whitespace without staging pre-existing work**

```bash
git diff --check -- 'Daily Music/Views/Components/ListeningTransition.swift' \
  'Daily MusicTests/TodayListeningTests.swift'
```

---

### Task 2: Report Today's Pull And Hide Only Its Indicator

**Files:**
- Modify: `Daily Music/Views/EntryDetailView.swift`
- Modify: `Daily Music/Views/EntryDetailImmersive.swift`
- Modify: `Daily MusicTests/TodayListeningTests.swift`

**Interfaces:**
- Produces: `onListenPullChanged`, `onListenPullEnded`, `hidesImmersiveScrollIndicator`, and `ImmersiveScrollIndicatorPolicy`.
- Consumes: transition arming and resolver helpers from Task 1.

- [ ] **Step 1: Write the failing indicator policy test**

```swift
struct ImmersiveScrollIndicatorPolicyTests {
    @Test func onlyExplicitTodayConfigurationHidesTheIndicator() {
        #expect(ImmersiveScrollIndicatorPolicy.style(hidesIndicator: true) == .hidden)
        #expect(ImmersiveScrollIndicatorPolicy.style(hidesIndicator: false) == .automatic)
    }
}
```

Run the Task 1 test command with `-only-testing:'Daily MusicTests/ImmersiveScrollIndicatorPolicyTests'` only. Expected: compilation fails because the policy is missing.

- [ ] **Step 2: Add the callback and indicator API**

In `EntryDetailView`:

```swift
var onListenPullChanged: ((_ drag: Double, _ armProgress: Double) -> Void)? = nil
var onListenPullEnded: ((_ outcome: TransitionOutcome, _ yVelocity: Double) -> Void)? = nil
var hidesImmersiveScrollIndicator = false
```

Add the policy beside the backdrop policy:

```swift
enum ImmersiveScrollIndicatorStyle: Equatable { case automatic, hidden }

enum ImmersiveScrollIndicatorPolicy {
    static func style(hidesIndicator: Bool) -> ImmersiveScrollIndicatorStyle {
        hidesIndicator ? .hidden : .automatic
    }
}
```

- [ ] **Step 3: Forward raw pull updates and outcomes**

In `listenPullGesture`, calculate `drag`, `arm`, and `velocity` once. During change call both `onListenArm?(arm)` and `onListenPullChanged?(drag, arm)`. On end resolve the outcome, reset `listenArm`, keep the commit haptic, and call:

```swift
onListenPullEnded?(outcome, velocity)
```

For an invalid/cancelled end after tracking began, call:

```swift
onListenArm?(0)
onListenPullEnded?(.cancel, 0)
```

- [ ] **Step 4: Apply the indicator policy to the immersive ScrollView**

```swift
.scrollIndicators(
    ImmersiveScrollIndicatorPolicy.style(hidesIndicator: hidesImmersiveScrollIndicator) == .hidden
        ? .hidden
        : .automatic
)
```

- [ ] **Step 5: Run the indicator, resolver, and math tests**

Expected: all selected suites pass; standard immersive details retain automatic indicators.

---

### Task 3: Make Today The Sole Presentation Owner

**Files:**
- Modify: `Daily Music/Views/TodayView.swift`

**Interfaces:**
- Consumes: `TodayListeningPhase`, EntryDetail pull callbacks, and transition math.
- Produces for Listening: `presentation: Binding<Double>`, `onDismissalStarted`, and `onDismissalCancelled`.

- [ ] **Step 1: Replace split host/return state**

Remove `showingListening` and `todayReturn`. Use:

```swift
@State private var listeningPhase: TodayListeningPhase = .idle
@State private var presentation: Double = 0
@State private var enterArm: Double = 0
@State private var viewHeight: CGFloat = 1
@State private var immersiveScrollPosition: ImmersiveSection?
```

- [ ] **Step 2: Wire EntryDetail**

```swift
onRequestListen: { beginListening() },
onListenArm: { enterArm = $0 },
onListenPullChanged: { drag, arm in updateListeningPull(drag: drag, arm: arm) },
onListenPullEnded: { outcome, velocity in
    finishListeningPull(outcome: outcome, velocity: velocity)
},
hidesImmersiveScrollIndicator: true,
immersiveScrollPosition: $immersiveScrollPosition
```

- [ ] **Step 3: Replace the UIKit host with one SwiftUI player layer**

```swift
private var playerOffsetY: CGFloat {
    -(1 - CGFloat(presentation)) * viewHeight
}

@ViewBuilder private var playerLayer: some View {
    if listeningPhase.isMounted, let entry = loadedEntry {
        ListeningView(
            entry: entry,
            initialArtwork: artwork.image,
            showsAdvanceButton: false,
            showsRevealIntro: false,
            isTransitionReady: listeningPhase.isReady,
            presentation: $presentation,
            onDismissalStarted: beginListeningDismissal,
            onDismissalCancelled: cancelListeningDismissal,
            onAdvance: { finishListening() },
            onReachedListenThreshold: { env.listensStore.markHeard(entry) }
        )
        .environment(env)
        .offset(y: reduceMotion ? 0 : playerOffsetY)
        .opacity(reduceMotion ? presentation : 1)
        .zIndex(1)
        .ignoresSafeArea()
    }
}
```

- [ ] **Step 4: Track entrance and settle from the live position**

```swift
private func updateListeningPull(drag: Double, arm: Double) {
    guard listeningPhase == .idle || listeningPhase == .pulling else { return }
    if listeningPhase == .idle { listeningPhase = .pulling }
    enterArm = arm
    presentation = TransitionMath.presentation(forPull: drag, height: viewHeight)
}

private func finishListeningPull(outcome: TransitionOutcome, velocity: Double) {
    guard listeningPhase == .pulling else { return }
    enterArm = 0
    switch outcome {
    case .commit:
        listeningPhase = .entering
        settlePresentation(to: 1, yVelocity: velocity) { completeListeningEntrance() }
    case .cancel:
        settlePresentation(to: 0, yVelocity: velocity) {
            listeningPhase = .idle
            presentation = 0
        }
    }
}
```

`settlePresentation` uses `.easeInOut(duration: 0.16)` under Reduce Motion and `.interpolatingSpring(mass: 1, stiffness: 190, damping: 24, initialVelocity:)` otherwise. Initial velocity comes from `TransitionMath.initialVelocity` using the current value.

- [ ] **Step 5: Route direct entrance and teardown through the same value**

Direct buttons set `.entering`, mount at `0`, yield one main-actor turn, then settle to `1`. Dismissal sets `.dismissing`; if Listening already settled to `0`, tear down immediately, otherwise settle to `0`. Cancellation returns `.dismissing` to `.presented`. Teardown sets `.idle`, resets presentation, and stops playback once.

After entrance completes:

```swift
listeningPhase = .presented
immersiveScrollPosition = .song
enterArm = 0
```

- [ ] **Step 6: Build and verify `BUILD SUCCEEDED`**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project "Daily Music.xcodeproj" -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -derivedDataPath './build/DerivedData' CODE_SIGNING_ALLOWED=NO
```

---

### Task 4: Track Listening Dismissal Directly

**Files:**
- Modify: `Daily Music/Views/ListeningView.swift`

**Interfaces:**
- Consumes: optional `presentation: Binding<Double>?`, transition axis, and transition math.
- Produces: lifecycle callbacks to Today while leaving nil-binding archive contexts unchanged.

- [ ] **Step 1: Add Today-only inputs and axis state**

```swift
var presentation: Binding<Double>? = nil
var onDismissalStarted: (() -> Void)? = nil
var onDismissalCancelled: (() -> Void)? = nil
@State private var dismissAxis: TransitionGestureAxis?
```

- [ ] **Step 2: Add endpoint settling**

Implement `settlePresentation(to:yVelocity:completion:)`. For a Today binding, animate its current value with the same 0.16-second fade/spring policy as Today. For nil bindings, retain the existing foreground reset and direct archive dismissal.

- [ ] **Step 3: Lock the axis and update presentation**

On first movement:

```swift
dismissAxis = TransitionGestureResolver.axis(
    horizontal: Double(value.translation.width),
    vertical: Double(value.translation.height)
)
if dismissAxis == .verticalUp { onDismissalStarted?() }
```

For `.verticalUp` only:

```swift
let up = max(0, -Double(value.translation.height))
let arm = TransitionMath.armProgress(forDrag: up, height: viewHeight)
if arm >= 1 && dismissArm < 1 { Haptics.tap() }
dismissArm = arm
presentation?.wrappedValue = TransitionMath.presentation(
    forDismissDrag: up,
    height: viewHeight
)
```

- [ ] **Step 4: Settle commit and cancellation**

Clear `dismissAxis` on end. Commit settles to `0` before `onAdvance`; cancel settles to `1` before `onDismissalCancelled`. Preserve the existing nil-binding Vault/Favorites behavior.

```swift
case .commit:
    Haptics.tap()
    settlePresentation(to: 0, yVelocity: Double(value.velocity.height)) { onAdvance() }
case .cancel:
    settlePresentation(to: 1, yVelocity: Double(value.velocity.height)) {
        onDismissalCancelled?()
    }
```

- [ ] **Step 5: Run focused tests and the complete test target**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -derivedDataPath './build/DerivedData' CODE_SIGNING_ALLOWED=NO
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 6: Inspect the final working tree**

```bash
git diff --check
git status --short
```

Expected: no whitespace errors. Leave implementation unstaged because touched files contain pre-existing user work.

- [ ] **Step 7: Manual simulator checks**

Verify slow pulls and cancellations, fast commits, both directions, hidden Today indicator with working journal snap, Reduce Motion fade, rotation, one-time playback cleanup, and unchanged Vault/Favorites behavior.
