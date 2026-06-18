# UIKit-Hosted Listening Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the frame-by-frame SwiftUI Today-to-Listening overlay animation with a UIKit-hosted, commit-triggered vertical transition while preserving the pull gestures and arming feedback.

**Architecture:** `TodayView` owns only a Boolean presentation intent. A new `UIViewControllerRepresentable` owns a child `UIHostingController<ListeningView>` and moves that already-laid-out view with `UIViewPropertyAnimator`. A pure state machine defines mount, readiness, duplicate-request, and teardown ordering and is tested independently from UIKit.

**Tech Stack:** Swift 5, SwiftUI, UIKit, Swift Testing, Xcode 26.5 simulator.

## Global Constraints

- Keep pull down from Today and pull up from Listening.
- Keep both arming rings, thresholds, velocity commits, haptics, and VoiceOver actions.
- Do not use continuous full-screen finger tracking, a curtain mask, `.drawingGroup()`, or a Today scroll-position handoff.
- Start playback and decorative animation only after UIKit presentation completes.
- Keep Today mounted and unchanged underneath the opaque Listening screen.
- Keep Vault and Favorites behavior unchanged.
- Use a short opacity transition when Reduce Motion is enabled.
- Preserve the existing unstaged intent that Today shows its complete song section after dismissal.

---

## File Structure

- `Daily Music/Views/Components/ListeningTransition.swift`: gesture math and the transition lifecycle state machine.
- `Daily Music/Views/Components/UIKitListeningTransitionHost.swift`: UIKit containment and animator orchestration.
- `Daily Music/Views/ListeningView.swift`: readiness gating and pull-up commit behavior.
- `Daily Music/Views/TodayView.swift`: presentation intent, host wiring, and cleanup.
- `Daily MusicTests/TodayListeningTests.swift`: lifecycle and gesture-policy coverage.

---

### Task 1: Define The Transition Lifecycle

**Files:**
- Modify: `Daily Music/Views/Components/ListeningTransition.swift`
- Modify: `Daily MusicTests/TodayListeningTests.swift`

**Interfaces:**
- Consumes: existing `TransitionResolver` and `TransitionMath`.
- Produces: `ListeningHostPhase`, `ListeningHostEvent`, `ListeningHostEffect`, and `ListeningHostMachine.handle(_:)`.

- [ ] **Step 1: Write failing lifecycle tests**

Remove `TodayListeningTransitionPolicyTests` and add:

```swift
struct ListeningHostMachineTests {
    @Test func presentationMovesThroughPrepareAnimateAndReady() {
        var machine = ListeningHostMachine()
        #expect(machine.handle(.presentRequested) == .prepareHost)
        #expect(machine.phase == .preparing)
        #expect(machine.isMounted && !machine.isReady)
        #expect(machine.handle(.hostPrepared) == .animateIn)
        #expect(machine.phase == .presenting)
        #expect(machine.handle(.presentationCompleted) == .none)
        #expect(machine.phase == .presented)
        #expect(machine.isReady)
    }

    @Test func duplicatePresentationRequestsAreIgnored() {
        var machine = ListeningHostMachine()
        #expect(machine.handle(.presentRequested) == .prepareHost)
        #expect(machine.handle(.presentRequested) == .none)
    }

    @Test func dismissalKeepsHostMountedUntilCompletion() {
        var machine = ListeningHostMachine(phase: .presented)
        #expect(machine.handle(.dismissRequested) == .animateOut)
        #expect(machine.phase == .dismissing)
        #expect(machine.isMounted && !machine.isReady)
        #expect(machine.handle(.dismissalCompleted) == .detachHost)
        #expect(machine.phase == .idle)
        #expect(!machine.isMounted)
    }

    @Test func duplicateDismissalsDetachOnlyOnce() {
        var machine = ListeningHostMachine(phase: .presented)
        #expect(machine.handle(.dismissRequested) == .animateOut)
        #expect(machine.handle(.dismissRequested) == .none)
        #expect(machine.handle(.dismissalCompleted) == .detachHost)
        #expect(machine.handle(.dismissalCompleted) == .none)
    }

    @Test func cancellationDetachesAnyMountedPhase() {
        for phase in [ListeningHostPhase.preparing, .presenting, .presented, .dismissing] {
            var machine = ListeningHostMachine(phase: phase)
            #expect(machine.handle(.cancelled) == .detachHost)
            #expect(machine.phase == .idle)
        }
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme 'Daily Music' \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -derivedDataPath './build/DerivedData' \
  -only-testing:'Daily MusicTests/ListeningHostMachineTests' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because the host lifecycle types do not exist.

- [ ] **Step 3: Implement the lifecycle machine**

Remove `ImmersiveSection`, `TodayListeningTransitionPhase`, and `TodayListeningTransitionPolicy`, then add:

```swift
enum ListeningHostPhase: Equatable {
    case idle, preparing, presenting, presented, dismissing
}

enum ListeningHostEvent {
    case presentRequested, hostPrepared, presentationCompleted
    case dismissRequested, dismissalCompleted, cancelled
}

enum ListeningHostEffect: Equatable {
    case none, prepareHost, animateIn, animateOut, detachHost
}

struct ListeningHostMachine {
    private(set) var phase: ListeningHostPhase

    init(phase: ListeningHostPhase = .idle) { self.phase = phase }

    var isMounted: Bool { phase != .idle }
    var isReady: Bool { phase == .presented }

    mutating func handle(_ event: ListeningHostEvent) -> ListeningHostEffect {
        switch (phase, event) {
        case (.idle, .presentRequested):
            phase = .preparing
            return .prepareHost
        case (.preparing, .hostPrepared):
            phase = .presenting
            return .animateIn
        case (.presenting, .presentationCompleted):
            phase = .presented
            return .none
        case (.presented, .dismissRequested):
            phase = .dismissing
            return .animateOut
        case (.dismissing, .dismissalCompleted):
            phase = .idle
            return .detachHost
        case (.preparing, .cancelled), (.presenting, .cancelled),
             (.presented, .cancelled), (.dismissing, .cancelled):
            phase = .idle
            return .detachHost
        default:
            return .none
        }
    }
}
```

- [ ] **Step 4: Run lifecycle, resolver, and math tests**

Run the Step 2 command, adding these selectors:

```bash
-only-testing:'Daily MusicTests/TransitionResolverTests' \
-only-testing:'Daily MusicTests/TransitionMathTests'
```

Expected: all focused tests pass.

- [ ] **Step 5: Commit**

```bash
git add 'Daily Music/Views/Components/ListeningTransition.swift' \
  'Daily MusicTests/TodayListeningTests.swift'
git commit -m 'test(listening): define UIKit host lifecycle'
```

---

### Task 2: Add The UIKit Transition Host

**Files:**
- Create: `Daily Music/Views/Components/UIKitListeningTransitionHost.swift`

**Interfaces:**
- Consumes: `ListeningHostMachine`.
- Produces: `UIKitListeningTransitionHost<Content: View>` with `isPresented`, `reduceMotion`, `onDismissed`, and a readiness-aware content builder.

- [ ] **Step 1: Create the representable and container controller**

```swift
import SwiftUI
import UIKit

struct UIKitListeningTransitionHost<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let reduceMotion: Bool
    let onDismissed: () -> Void
    @ViewBuilder let content: (Bool) -> Content

    func makeUIViewController(context: Context) -> ListeningTransitionContainerController<Content> {
        ListeningTransitionContainerController(
            reduceMotion: reduceMotion,
            onDismissed: onDismissed,
            content: content
        )
    }

    func updateUIViewController(
        _ controller: ListeningTransitionContainerController<Content>,
        context: Context
    ) {
        controller.update(
            wantsPresentation: isPresented,
            reduceMotion: reduceMotion,
            onDismissed: onDismissed,
            content: content
        )
    }

    static func dismantleUIViewController(
        _ controller: ListeningTransitionContainerController<Content>,
        coordinator: Void
    ) {
        controller.cancelAndDetach()
    }
}

@MainActor
final class ListeningTransitionContainerController<Content: View>: UIViewController {
    private var machine = ListeningHostMachine()
    private var hostingController: UIHostingController<Content>?
    private var animator: UIViewPropertyAnimator?
    private var wantsPresentation = false
    private var reduceMotion: Bool
    private var onDismissed: () -> Void
    private var content: (Bool) -> Content

    init(
        reduceMotion: Bool,
        onDismissed: @escaping () -> Void,
        content: @escaping (Bool) -> Content
    ) {
        self.reduceMotion = reduceMotion
        self.onDismissed = onDismissed
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        view = PassthroughTransitionContainerView()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reconcilePresentation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hostingController?.view.frame = view.bounds
    }

    func update(
        wantsPresentation: Bool,
        reduceMotion: Bool,
        onDismissed: @escaping () -> Void,
        content: @escaping (Bool) -> Content
    ) {
        self.wantsPresentation = wantsPresentation
        self.reduceMotion = reduceMotion
        self.onDismissed = onDismissed
        self.content = content
        reconcilePresentation()
    }

    func cancelAndDetach() {
        animator?.stopAnimation(true)
        animator = nil
        _ = machine.handle(.cancelled)
        detachHost(notify: false)
    }
}

private final class PassthroughTransitionContainerView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { !$0.isHidden && $0.alpha > 0.01 && $0.frame.contains(point) }
    }
}
```

- [ ] **Step 2: Add lifecycle execution methods**

Add a private controller extension whose methods follow this exact sequence:

```swift
private extension ListeningTransitionContainerController {
    func reconcilePresentation() {
        guard isViewLoaded, view.window != nil else { return }
        if wantsPresentation {
            guard machine.handle(.presentRequested) == .prepareHost else { return }
            prepareHost()
        } else {
            guard machine.handle(.dismissRequested) == .animateOut else { return }
            refreshContent()
            animateOut()
        }
    }

    func prepareHost() {
        let hosting = UIHostingController(rootView: content(false))
        hosting.view.backgroundColor = .black
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: self)
        view.layoutIfNeeded()
        hosting.view.transform = reduceMotion
            ? .identity
            : CGAffineTransform(translationX: 0, y: -max(view.bounds.height, 1))
        hosting.view.alpha = reduceMotion ? 0 : 1
        hostingController = hosting
        guard machine.handle(.hostPrepared) == .animateIn else { return }
        animateIn()
    }

    func animateIn() {
        guard let hostedView = hostingController?.view else { return }
        let animator = makeAnimator {
            hostedView.transform = .identity
            hostedView.alpha = 1
        }
        self.animator = animator
        animator.addCompletion { [weak self] position in
            guard let self, position == .end else { return }
            self.animator = nil
            _ = self.machine.handle(.presentationCompleted)
            self.refreshContent()
            UIAccessibility.post(
                notification: .screenChanged,
                argument: self.hostingController?.view
            )
            self.reconcilePresentation()
        }
        animator.startAnimation()
    }

    func animateOut() {
        guard let hostedView = hostingController?.view else {
            finishDismissal()
            return
        }
        let height = max(view.bounds.height, 1)
        let animator = makeAnimator {
            if self.reduceMotion {
                hostedView.alpha = 0
            } else {
                hostedView.transform = CGAffineTransform(translationX: 0, y: -height)
            }
        }
        self.animator = animator
        animator.addCompletion { [weak self] position in
            guard let self, position == .end else { return }
            self.animator = nil
            self.finishDismissal()
        }
        animator.startAnimation()
    }

    func makeAnimator(animations: @escaping () -> Void) -> UIViewPropertyAnimator {
        reduceMotion
            ? UIViewPropertyAnimator(duration: 0.16, curve: .easeInOut, animations: animations)
            : UIViewPropertyAnimator(duration: 0.48, dampingRatio: 0.88, animations: animations)
    }

    func refreshContent() {
        hostingController?.rootView = content(machine.isReady)
    }

    func finishDismissal() {
        guard machine.handle(.dismissalCompleted) == .detachHost else { return }
        detachHost(notify: true)
    }

    func detachHost(notify: Bool) {
        guard let hosting = hostingController else { return }
        hosting.willMove(toParent: nil)
        hosting.view.removeFromSuperview()
        hosting.removeFromParent()
        hostingController = nil
        if notify {
            onDismissed()
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }
}
```

- [ ] **Step 3: Build and rerun lifecycle tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -scheme 'Daily Music' \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -derivedDataPath './build/DerivedData' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`. Then rerun Task 1 Step 2 and expect all lifecycle tests to pass.

- [ ] **Step 4: Commit**

```bash
git add 'Daily Music/Views/Components/UIKitListeningTransitionHost.swift'
git commit -m 'feat(listening): add UIKit transition host'
```

---

### Task 3: Gate Listening And Use Pull-Up As A Trigger

**Files:**
- Modify: `Daily Music/Views/ListeningView.swift`

**Interfaces:**
- Consumes: `isTransitionReady: Bool` from the host.
- Produces: readiness-gated playback/effects and commit-triggered dismissal.

- [ ] **Step 1: Add readiness with archive-compatible defaults**

Add `var isTransitionReady: Bool = true` before `onAdvance`. Remove `presentation: Binding<Double>?` and `slidePlayerAway(_:)`. Keep the small foreground offset and scale as gesture feedback.

- [ ] **Step 2: Gate work until presentation completes**

Sample and collect listen time only when ready. Replace the playback task with:

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

Guard `startPlaybackIfNeeded()` with `isTransitionReady`. Start breathing, pulse, and hint animations only when readiness becomes true; reset them without animation when readiness becomes false. Pass `isTransitionReady && player.state == .playing` to `EqualizerBars`.

- [ ] **Step 3: Make a committed pull request dismissal**

Guard dismiss gesture changes and completion with `isTransitionReady`. Preserve the current axis rejection, arm math, cancel spring, and haptic. Replace the commit branch with:

```swift
case .commit:
    Haptics.tap()
    onAdvance()
```

- [ ] **Step 4: Build and test**

Run the Task 2 build command and all focused Task 1 tests.

Expected: build succeeds and all focused tests pass.

- [ ] **Step 5: Commit**

```bash
git add 'Daily Music/Views/ListeningView.swift'
git commit -m 'fix(listening): gate work behind UIKit presentation'
```

---

### Task 4: Wire Today To The UIKit Host

**Files:**
- Modify: `Daily Music/Views/TodayView.swift`

**Interfaces:**
- Consumes: `UIKitListeningTransitionHost`, preloaded artwork, and readiness-aware `ListeningView`.
- Produces: centralized Boolean presentation intent and post-dismiss playback cleanup.

- [ ] **Step 1: Remove SwiftUI transition state**

Delete `presentation`, `viewHeight`, and `immersiveScrollPosition`, plus the height geometry reader. Stop passing `immersiveScrollPosition` to `EntryDetailView`. Keep `showingListening` and `enterArm`.

- [ ] **Step 2: Centralize every entrance**

Make the new-drop prompt call `beginListening()`. Replace that method with:

```swift
private func beginListening() {
    guard !showingListening, loadedEntry != nil else { return }
    enterArm = 0
    showingListening = true
}
```

- [ ] **Step 3: Replace `playerLayer` and dismissal**

```swift
@ViewBuilder private var playerLayer: some View {
    if let entry = loadedEntry {
        UIKitListeningTransitionHost(
            isPresented: $showingListening,
            reduceMotion: reduceMotion,
            onDismissed: { Task { await env.musicPlayer.stop() } }
        ) { isReady in
            ListeningView(
                entry: entry,
                initialArtwork: artwork.image,
                showsAdvanceButton: false,
                showsRevealIntro: false,
                isTransitionReady: isReady,
                onAdvance: { finishListening() },
                onReachedListenThreshold: { env.listensStore.markHeard(entry) }
            )
            .environment(env)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .zIndex(1)
    }
}

private func finishListening() {
    guard showingListening else { return }
    showingListening = false
}
```

Remove the old player offset, presentation spring, and teardown method.

- [ ] **Step 4: Build and test**

Run the Task 2 build command and all Task 1 focused tests.

Expected: build succeeds and all focused tests pass.

- [ ] **Step 5: Commit**

```bash
git add 'Daily Music/Views/TodayView.swift'
git commit -m 'fix(today): present listening through UIKit host'
```

---

### Task 5: Verify The Complete Transition

**Files:**
- Verify all files changed in Tasks 1-4.

**Interfaces:**
- Consumes: the completed transition.
- Produces: automated and simulator evidence.

- [ ] **Step 1: Run the complete suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme 'Daily Music' \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -derivedDataPath './build/DerivedData' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` with no failed Swift Testing suites.

- [ ] **Step 2: Exercise simulator behavior**

Verify partial pulls cancel, committed pulls animate without flashes, playback starts only after entrance, horizontal scrubbing does not dismiss, Today remains unchanged after exit, rapid repeated gestures do not duplicate the player, and Reduce Motion cross-fades cleanly.

- [ ] **Step 3: Inspect final state**

```bash
git diff --check
git status --short
git log -6 --oneline --decorate
```

Expected: no whitespace errors and only intentional changes remain.
