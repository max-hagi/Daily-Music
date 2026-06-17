# Interactive Today ↔ Listening Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the clunky threshold-fire cross-fade between Today and the immersive Listening player with a continuous, finger-tracked transition, and flip the dismiss gesture to swipe-down (platform convention) while keeping the pull-down-to-listen ceremony.

**Architecture:** A pure helper file (`ListeningTransition.swift`) holds the commit/cancel decision and the gesture→progress math, unit-tested in isolation. The mounted player is driven by a single `presentation: Double` (0 = absent, 1 = fully shown); `TodayView` owns it, springs it 0→1 on commit, and binds it into `ListeningView` whose new swipe-down drag tracks it 1→0. Enter shows live feedback on Today's content via a separate `pullProgress` (the player can't be mounted early — mounting auto-starts audio). The heavy blurred bloom is opacity-only, never repositioned, preserving the prior perf fix.

**Tech Stack:** SwiftUI (iOS 18 APIs: `onScrollGeometryChange`, `DragGesture.Value.velocity`, `withAnimation(_:completion:)`), Swift Testing (`import Testing`, `@Test`, `#expect`).

**Spec:** [docs/superpowers/specs/2026-06-17-interactive-listening-transition-design.md](../specs/2026-06-17-interactive-listening-transition-design.md)

**Build/test commands** (xcode-select points at CommandLineTools, so `DEVELOPER_DIR` is required):

```bash
# Build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build

# Run only the transition unit tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/TransitionResolverTests" \
  -only-testing:"Daily MusicTests/TransitionMathTests"
```

**Key facts that constrain this plan:**
- The app target is a file-system-synchronized group → new files under `Daily Music/` auto-compile. The **test target is NOT** synced → new tests must go into the already-registered `Daily MusicTests/TodayListeningTests.swift` to avoid editing `project.pbxproj`.
- `ListeningView` has three call sites: `TodayView.swift:134` (interactive), `VaultView.swift:400` and `FavoritesView.swift:341` (both `.fullScreenCover` with a trailing `onAdvance` closure). The new `presentation` parameter MUST be optional with a `nil` default and inserted **before** `onAdvance` so trailing-closure binding is preserved.
- `clamped(to:)` in `EntryDetailImmersive.swift:365` is `private`, so the new file uses its own inline clamp.

---

### Task 1: Write failing tests for the pure transition helpers

**Files:**
- Test: `Daily MusicTests/TodayListeningTests.swift` (append two new test structs)

- [ ] **Step 1: Append the test structs**

Add to the end of `Daily MusicTests/TodayListeningTests.swift`:

```swift
struct TransitionResolverTests {
    @Test func commitsAtOrAboveFractionWhenSlow() {
        #expect(TransitionResolver.resolve(committedFraction: 0.4, velocity: 0) == .commit)
        #expect(TransitionResolver.resolve(committedFraction: 0.9, velocity: 0) == .commit)
    }

    @Test func cancelsBelowFractionWhenSlow() {
        #expect(TransitionResolver.resolve(committedFraction: 0.2, velocity: 0) == .cancel)
        #expect(TransitionResolver.resolve(committedFraction: 0.0, velocity: 0) == .cancel)
    }

    @Test func fastForwardFlickCommitsBelowFraction() {
        #expect(TransitionResolver.resolve(committedFraction: 0.1, velocity: 1200) == .commit)
    }

    @Test func fastReverseFlickCancelsAboveFraction() {
        #expect(TransitionResolver.resolve(committedFraction: 0.8, velocity: -1200) == .cancel)
    }
}

struct TransitionMathTests {
    @Test func pullClampsAtZero() {
        #expect(TransitionMath.progress(forPull: -50) == 0)
        #expect(TransitionMath.progress(forPull: 0) == 0)
    }

    @Test func pullReachesOneAtSpan() {
        #expect(TransitionMath.progress(forPull: TransitionMath.pullSpan) == 1)
        #expect(TransitionMath.progress(forPull: 999) == 1)
    }

    @Test func pullIsLinearMidway() {
        #expect(TransitionMath.progress(forPull: TransitionMath.pullSpan / 2) == 0.5)
    }

    @Test func dismissReturnsZeroForNonPositiveHeight() {
        #expect(TransitionMath.dismissFraction(forDrag: 100, height: 0) == 0)
        #expect(TransitionMath.dismissFraction(forDrag: 100, height: -10) == 0)
    }

    @Test func dismissClampsAndScalesWithHeight() {
        let h: CGFloat = 800
        let span = Double(h) * TransitionMath.dismissHeightFraction   // 280
        #expect(TransitionMath.dismissFraction(forDrag: span, height: h) == 1)
        #expect(TransitionMath.dismissFraction(forDrag: span / 2, height: h) == 0.5)
        #expect(TransitionMath.dismissFraction(forDrag: -10, height: h) == 0)
        #expect(TransitionMath.dismissFraction(forDrag: span * 2, height: h) == 1)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail (do not compile)**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/TransitionResolverTests" \
  -only-testing:"Daily MusicTests/TransitionMathTests"
```
Expected: BUILD/TEST FAILURE — "cannot find 'TransitionResolver' in scope" / "cannot find 'TransitionMath' in scope".

- [ ] **Step 3: Commit the failing tests**

```bash
git add "Daily MusicTests/TodayListeningTests.swift"
git commit -m "test(listening): failing tests for transition resolver + math"
```

---

### Task 2: Implement the pure transition helpers

**Files:**
- Create: `Daily Music/Views/Components/ListeningTransition.swift`

- [ ] **Step 1: Create the helper file**

Create `Daily Music/Views/Components/ListeningTransition.swift`:

```swift
//
//  ListeningTransition.swift
//  Daily Music
//
//  Pure, view-free math for the Today ↔ Listening interactive transition.
//  Kept separate so the easy-to-get-wrong commit/cancel decision and the
//  gesture→progress mappings are unit-tested without spinning up a SwiftUI view.
//

import CoreGraphics

enum TransitionOutcome: Equatable {
    case commit   // finish the gesture's intent
    case cancel   // snap back to where the gesture started
}

enum TransitionResolver {
    /// Fraction of the gesture's intent that must be reached to commit on release alone.
    static let commitFraction = 0.4
    /// Velocity (points/sec, toward the intent) that commits even below `commitFraction`;
    /// the same magnitude in reverse cancels even above it.
    static let commitVelocity = 800.0

    /// Decide whether a released gesture should complete or snap back.
    /// - Parameters:
    ///   - committedFraction: 0 = at the gesture's start, 1 = intent fully achieved.
    ///   - velocity: points/sec; positive = moving toward the intent.
    static func resolve(committedFraction: Double, velocity: Double) -> TransitionOutcome {
        if velocity >= commitVelocity { return .commit }
        if velocity <= -commitVelocity { return .cancel }
        return committedFraction >= commitFraction ? .commit : .cancel
    }
}

enum TransitionMath {
    /// Over-pull distance (points) that maps to a full enter (progress 1).
    static let pullSpan: Double = 160
    /// Dismiss-drag span as a fraction of the screen height (so it feels the same on any device).
    static let dismissHeightFraction: Double = 0.35

    /// Journal over-pull (points, positive = pulled down past the top) → 0...1.
    static func progress(forPull pull: Double) -> Double {
        clamp(pull / pullSpan)
    }

    /// Downward dismiss-drag (points, positive = down) → 0...1, scaled to screen height.
    static func dismissFraction(forDrag drag: Double, height: CGFloat) -> Double {
        guard height > 0 else { return 0 }
        let span = Double(height) * dismissHeightFraction
        return clamp(drag / span)
    }

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
}
```

- [ ] **Step 2: Run the tests to verify they pass**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/TransitionResolverTests" \
  -only-testing:"Daily MusicTests/TransitionMathTests"
```
Expected: TEST SUCCEEDED (all 9 tests pass).

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Components/ListeningTransition.swift"
git commit -m "feat(listening): pure transition resolver + progress math"
```

---

### Task 3: Make ListeningView presentation-driven with a swipe-down dismiss

**Files:**
- Modify: `Daily Music/Views/ListeningView.swift`

This task is view wiring (verified by build, not unit tests). Apply all edits, then build.

- [ ] **Step 1: Add the `presentation` binding parameter (before `onAdvance`)**

In `Daily Music/Views/ListeningView.swift`, the property block currently reads:

```swift
    var showsRevealIntro: Bool = false
    /// Fired when the bottom button is tapped (and, on Today, when the clip ends).
    /// Last so trailing-closure call sites bind to it.
    var onAdvance: () -> Void
```

Change it to:

```swift
    var showsRevealIntro: Bool = false
    /// Today drives the interactive enter/exit transition through this 0…1 value
    /// (0 = absent, 1 = fully presented). Vault/Favorites present in a fullScreenCover
    /// and pass nil — the drag then animates an internal value and dismisses on commit.
    var presentation: Binding<Double>? = nil
    /// Fired when the bottom button is tapped (and, on Today, when the clip ends).
    /// Last so trailing-closure call sites bind to it.
    var onAdvance: () -> Void
```

- [ ] **Step 2: Add the effective-presentation plumbing and view-height state**

In the `@State` block (near `swipeHintBob`), add:

```swift
    /// Drives the gentle up-and-down nudge on the "swipe down" return hint.
    @State private var swipeHintBob = false
    /// Used when no external `presentation` binding is supplied (Vault/Favorites).
    @State private var localPresentation: Double = 1
    /// Captured container height so the dismiss drag scales to the screen.
    @State private var viewHeight: CGFloat = 1
```

(The first line replaces the existing `swipeHintBob` declaration — keep just one.)

Then add these computed/helper members next to the other private helpers (e.g. just below `private var displayProgress: Double { ... }`):

```swift
    /// Single source of truth for how presented the player is, whether driven
    /// externally (Today) or internally (Vault/Favorites).
    private var presentationValue: Double { presentation?.wrappedValue ?? localPresentation }

    private func setPresentation(_ value: Double) {
        if let presentation {
            presentation.wrappedValue = value
        } else {
            localPresentation = value
        }
    }

    private func settlePresentation(to target: Double) {
        if reduceMotion {
            setPresentation(target)
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                setPresentation(target)
            }
        }
    }

    /// Foreground travel for the dismiss slide. Bloom never moves.
    private static let dismissTravel: CGFloat = 120
```

- [ ] **Step 3: Apply the foreground transform and swap the gesture in `body`**

The current `body` opening is:

```swift
    var body: some View {
        ZStack {
            bloom

            if phase == .intro {
                introStage
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.04)))
            } else {
                playerStage
                    .transition(reduceMotion ? .opacity : .opacity)
            }
        }
        .preferredColorScheme(.dark)
        // Swipe up to send the player back down to Today — the mirror of Today's
        // pull-down-to-listen. Simultaneous so it never blocks the transport/scrub.
        .contentShape(Rectangle())
        .simultaneousGesture(swipeUpToReturnGesture)
```

Replace it with (note: the foreground is wrapped in a `Group` so the scale/offset hit it but **not** `bloom`):

```swift
    var body: some View {
        ZStack {
            bloom

            Group {
                if phase == .intro {
                    introStage
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.04)))
                } else {
                    playerStage
                        .transition(reduceMotion ? .opacity : .opacity)
                }
            }
            .scaleEffect(reduceMotion ? 1 : 0.96 + 0.04 * presentationValue)
            .offset(y: reduceMotion ? 0 : (1 - presentationValue) * Self.dismissTravel)
        }
        .preferredColorScheme(.dark)
        // Swipe DOWN to send the player back to Today (the universal full-screen-player
        // dismiss). Interactive: the foreground tracks the finger while the bloom only
        // fades. Simultaneous so it never blocks the transport/scrub.
        .contentShape(Rectangle())
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, newValue in viewHeight = newValue }
            }
        }
        .simultaneousGesture(dismissGesture)
```

- [ ] **Step 4: Replace `swipeUpToReturnGesture` with the interactive `dismissGesture`**

The current gesture (around `ListeningView.swift:487`) is:

```swift
    /// An upward swipe dismisses the player back to Today (the inverse of the
    /// pull-down that opened it). Vertical-only so a horizontal scrub can't trip it.
    private var swipeUpToReturnGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard value.translation.height < -80, abs(value.translation.width) < 60 else { return }
                Haptics.tap()   // confirm the swipe, then the screen cross-dissolves back
                onAdvance()
            }
    }
```

Replace it entirely with:

```swift
    /// A downward swipe dismisses the player back to Today — the universal
    /// full-screen-player gesture. The foreground tracks the finger via
    /// `presentation`; release commits or snaps back by distance + velocity.
    /// Vertical-down only so a horizontal scrub can't trip it.
    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard isDownwardDrag(value) else { return }
                let fraction = TransitionMath.dismissFraction(
                    forDrag: Double(value.translation.height), height: viewHeight)
                setPresentation(1 - fraction)
            }
            .onEnded { value in
                guard isDownwardDrag(value) else {
                    settlePresentation(to: 1)   // horizontal/upward: snap closed
                    return
                }
                let fraction = TransitionMath.dismissFraction(
                    forDrag: Double(value.translation.height), height: viewHeight)
                let outcome = TransitionResolver.resolve(
                    committedFraction: fraction, velocity: Double(value.velocity.height))
                switch outcome {
                case .commit:
                    Haptics.tap()
                    if reduceMotion {
                        onAdvance()
                    } else {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            setPresentation(0)
                        } completion: {
                            onAdvance()
                        }
                    }
                case .cancel:
                    settlePresentation(to: 1)
                }
            }
    }

    /// True for a clearly-downward drag (so horizontal scrubs and upward flicks pass through).
    private func isDownwardDrag(_ value: DragGesture.Value) -> Bool {
        value.translation.height > 0 && abs(value.translation.width) < abs(value.translation.height)
    }
```

- [ ] **Step 5: Update the hint to point down ("swipe down to close")**

The current hint (around `ListeningView.swift:206`) is:

```swift
    /// Mirrors Today's "pull down to listen" cue: a small upward chevron telling
    /// the listener the screen swipes up to leave. A slow bob draws the eye; the
    /// gesture itself lives on the root ZStack. Decorative — hidden from VoiceOver
    /// (the labeled advance button is the accessible exit).
    private var swipeUpHint: some View {
        VStack(spacing: 1) {
            Image(systemName: "chevron.up")
                .font(.system(size: 13, weight: .bold))
            Text("Swipe up to close")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.55))
        .offset(y: swipeHintBob ? -4 : 0)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
            value: swipeHintBob
        )
        .accessibilityHidden(true)
        .onAppear { swipeHintBob = true }
    }
```

Replace it with (keep the same member name `swipeUpHint` so `playerStage` still references it):

```swift
    /// The dismiss cue: a small downward chevron telling the listener the screen
    /// swipes down to leave (matching every full-screen media player). A slow bob
    /// draws the eye. Decorative — hidden from VoiceOver (the labeled advance
    /// button is the accessible exit).
    private var swipeUpHint: some View {
        VStack(spacing: 1) {
            Text("Swipe down to close")
                .font(.caption2.weight(.semibold))
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(.white.opacity(0.55))
        .offset(y: swipeHintBob ? 4 : 0)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
            value: swipeHintBob
        )
        .accessibilityHidden(true)
        .onAppear { swipeHintBob = true }
    }
```

- [ ] **Step 6: Build to verify ListeningView compiles**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
```
Expected: BUILD SUCCEEDED. (Vault/Favorites still compile: they don't pass `presentation`, so it defaults to nil and uses `localPresentation`.)

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Views/ListeningView.swift"
git commit -m "feat(listening): presentation-driven swipe-down dismiss"
```

---

### Task 4: Add live enter feedback in EntryDetailView / EntryDetailImmersive

**Files:**
- Modify: `Daily Music/Views/EntryDetailView.swift` (add prop)
- Modify: `Daily Music/Views/EntryDetailImmersive.swift` (scroll handler)

- [ ] **Step 1: Add the `onListenPullProgress` prop to EntryDetailView**

In `Daily Music/Views/EntryDetailView.swift`, after the `onRequestListen` property (`:31`):

```swift
    /// Today supplies this so the song zone can recede live as the user over-pulls
    /// toward the listen ceremony. nil elsewhere (0 = at rest, 1 = at the commit pull).
    var onListenPullProgress: ((Double) -> Void)? = nil
```

- [ ] **Step 2: Drive `pullProgress` from the existing scroll handler**

In `Daily Music/Views/EntryDetailImmersive.swift`, the over-pull handler (`:41-52`) currently is:

```swift
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top   // negative when pulled past the top
            } action: { _, offset in
                guard onRequestListen != nil else { return }
                if offset < -80, !pullTriggered {
                    pullTriggered = true
                    Haptics.tap()
                    onRequestListen?()
                } else if offset >= -8 {
                    pullTriggered = false   // re-arm once released back near the top
                }
            }
```

Replace it with:

```swift
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top   // negative when pulled past the top
            } action: { _, offset in
                guard onRequestListen != nil else { return }
                let pull = Double(max(0, -offset))   // points pulled past the top
                if !pullTriggered {
                    let progress = TransitionMath.progress(forPull: pull)
                    onListenPullProgress?(progress)   // live recede feedback on Today
                    if progress >= TransitionResolver.commitFraction {
                        pullTriggered = true
                        Haptics.tap()
                        onListenPullProgress?(1)      // finish the recede under the rising player
                        onRequestListen?()
                    }
                } else if offset >= -8 {
                    pullTriggered = false             // re-arm once released near the top
                    onListenPullProgress?(0)
                }
            }
```

- [ ] **Step 3: Build to verify both files compile**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
```
Expected: BUILD SUCCEEDED. (`onListenPullProgress` is wired but not yet supplied by any caller — that's fine; it is optional.)

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/EntryDetailView.swift" "Daily Music/Views/EntryDetailImmersive.swift"
git commit -m "feat(today): report live over-pull progress for listen ceremony"
```

---

### Task 5: Wire the interactive transition into TodayView

**Files:**
- Modify: `Daily Music/Views/TodayView.swift`

- [ ] **Step 1: Add the transition state**

In `Daily Music/Views/TodayView.swift`, the `@State` block currently includes:

```swift
    @State private var showingListening = false  // drives the immersive listen cover
```

Add directly beneath it:

```swift
    @State private var presentation: Double = 0  // 0 = player absent, 1 = fully presented
    @State private var pullProgress: Double = 0  // enter-only recede feedback on Today
```

- [ ] **Step 2: Apply the recede to the Today content and report pull progress**

The `EntryDetailView` branch (`:34-43`) currently is:

```swift
                        case .loaded(let entry):
                            EntryDetailView(
                                entry: entry,
                                dateLabel: todayString,
                                showsNavigationTitle: false,
                                albumArtHorizontalPadding: 28,
                                usesImmersiveBackdrop: true,
                                onRequestListen: { showingListening = true }
                            )
                            .simultaneousGesture(returnSwipeGesture)
```

Replace it with:

```swift
                        case .loaded(let entry):
                            EntryDetailView(
                                entry: entry,
                                dateLabel: todayString,
                                showsNavigationTitle: false,
                                albumArtHorizontalPadding: 28,
                                usesImmersiveBackdrop: true,
                                onRequestListen: { beginListening() },
                                onListenPullProgress: { pullProgress = $0 }
                            )
                            .scaleEffect(reduceMotion ? 1 : 1 - 0.04 * pullProgress)
                            .opacity(1 - 0.25 * pullProgress)
                            .simultaneousGesture(returnSwipeGesture)
```

- [ ] **Step 3: Drive the player container from `presentation` and pass the binding**

The player container (`:132-150`) currently is:

```swift
            ZStack {
                if showingListening, let entry = loadedEntry {
                    ListeningView(
                        entry: entry,
                        showsRevealIntro: false,
                        onAdvance: {
                            showingListening = false
                            // Reading mode is silent: moving to the story (or the clip
                            // finishing) hands the room back — no audio left running.
                            Task { await env.musicPlayer.stop() }
                        },
                        onReachedListenThreshold: { env.listensStore.markHeard(entry) }
                    )
                    .transition(.opacity)
                }
            }
            .zIndex(1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25),
                       value: showingListening)
```

Replace it with:

```swift
            ZStack {
                if showingListening, let entry = loadedEntry {
                    ListeningView(
                        entry: entry,
                        showsRevealIntro: false,
                        presentation: $presentation,
                        onAdvance: { finishListening() },
                        onReachedListenThreshold: { env.listensStore.markHeard(entry) }
                    )
                }
            }
            // Opacity carries the cross-dissolve (cheap, no bloom repositioning);
            // ListeningView adds the foreground scale/slide from the same value.
            .opacity(presentation)
            .zIndex(1)
```

- [ ] **Step 4: Add the begin/finish helpers**

Add these methods to `TodayView` (e.g. just above `returnSwipeGesture` at `:178`):

```swift
    /// Commit the listen ceremony: mount the player and spring it up.
    private func beginListening() {
        showingListening = true
        if reduceMotion {
            presentation = 1
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                presentation = 1
            }
        }
    }

    /// Tear down after the player has animated away (or immediately under Reduce Motion).
    private func finishListening() {
        showingListening = false
        presentation = 0
        pullProgress = 0
        // Reading mode is silent: handing the room back leaves no audio running.
        Task { await env.musicPlayer.stop() }
    }
```

- [ ] **Step 5: Build to verify TodayView compiles and wires together**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Run the full test suite to confirm nothing regressed**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: TEST SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Views/TodayView.swift"
git commit -m "feat(today): interactive finger-tracked Today↔Listening transition"
```

---

### Task 6: Device verification, docs, and memory

**Files:**
- Modify: `docs/ARCHITECTURE.md` (if it documents the Today/Listening transition)

- [ ] **Step 1: Verify the feel on the simulator/device**

Launch the app (run skill or Xcode). Confirm:
- Pull down on Today's song zone → Today recedes live as you pull; at ~64pt it commits with a haptic and the player springs up (no flat fade).
- In the player, **swipe down** → the foreground tracks your finger downward and fades while the bloom stays put; releasing past ~⅓ screen OR a fast flick dismisses; a small/slow drag snaps back.
- The horizontal progress scrubber still works (a sideways drag does not dismiss).
- Vault and Favorites still open the player in a full-screen cover and now dismiss on swipe-down too; the "Done" button still works.
- Enable Settings → Accessibility → Reduce Motion: transitions are opacity-only, no slide/scale, and still commit/dismiss correctly.

- [ ] **Step 2: Update ARCHITECTURE.md if it references the transition**

Run:
```bash
grep -n "cross-dissolve\|Listening\|showingListening\|transition" docs/ARCHITECTURE.md
```
If a passage describes the old threshold cross-fade / swipe-up dismiss, update it to: "Today↔Listening is an interactive, finger-tracked transition driven by a single `presentation` value (`TransitionResolver`/`TransitionMath` in `ListeningTransition.swift`); enter = pull-down ceremony with live recede + commit spring, exit = swipe-down to dismiss; the bloom is opacity-only to stay within the frame budget." If there is no such passage, skip.

- [ ] **Step 3: Commit any doc change**

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs(architecture): interactive Today↔Listening transition"
```

- [ ] **Step 4: Update the project memory**

Update `/Users/maximesavehilaghi/.claude/projects/-Users-maximesavehilaghi-Developer-Daily-Music/memory/listening-transition.md` to note the 2026-06-17 follow-up: the transition is now interactive/finger-tracked, dismiss flipped to swipe-down, pure helpers live in `ListeningTransition.swift` with tests in `TodayListeningTests.swift`. Keep the existing perf rationale (bloom opacity-only). Refresh the one-line pointer in `MEMORY.md` if needed.

---

## Self-Review

**Spec coverage:**
- Two state values (`presentation`, `pullProgress`) → Task 5 Step 1. ✓
- `presentation` drives bloom opacity (container `.opacity`) + foreground scale/offset (ListeningView `Group`) → Task 3 Step 3, Task 5 Step 3. ✓
- `pullProgress` drives Today recede → Task 5 Step 2. ✓
- Enter pull mapping + 0.4 commit latch → Task 4 Step 2. ✓
- Exit swipe-down interactive drag + resolve(commit/cancel) + spring-then-onAdvance → Task 3 Step 4. ✓
- Hint copy/chevron/bob flipped → Task 3 Step 5. ✓
- Pure helpers + tests → Tasks 1–2. ✓
- Reduce Motion opacity-only path → Task 3 Steps 2–4, Task 5 Steps 2 & 4. ✓
- Scrub vs dismiss disambiguation → `isDownwardDrag` (Task 3 Step 4). ✓
- Vault/Favorites unaffected (optional binding, internal `localPresentation`) → Task 3 Steps 1–2. ✓

**Placeholder scan:** No TBDs; every code step shows complete code; commands have expected output. ✓

**Type/name consistency:** `presentation: Binding<Double>?`, `presentationValue`, `setPresentation`, `settlePresentation`, `dismissGesture`, `isDownwardDrag`, `onListenPullProgress`, `beginListening`, `finishListening`, `TransitionResolver.resolve(committedFraction:velocity:)`, `TransitionResolver.commitFraction`, `TransitionMath.progress(forPull:)`, `TransitionMath.dismissFraction(forDrag:height:)`, `TransitionMath.pullSpan`, `TransitionMath.dismissHeightFraction` — used identically across plan and tests. ✓
