# Gesture-tracking Today ↔ Listening transition — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Today ↔ Listening transition track the swipe direction, swipeable across the whole player screen, with no refresh-style stall on open.

**Architecture:** Replace the `.fullScreenCover` modal (which slides up from the bottom, fighting the downward pull-open gesture) with a conditional `ListeningView` sibling inside a `ZStack`, using a `.move(edge: .top)` transition driven by a single `.animation(value:)`. Make the return swipe cover the whole screen via `.contentShape`.

**Tech Stack:** SwiftUI (iOS), Xcode 16 file-system-synchronized app target.

**Note on testing:** This is gesture/animation UI work with no meaningful automated-test seam. Each task's verification is (a) a clean build and (b) the manual simulator checks from the spec. Build command (this machine's `xcode-select` points at CommandLineTools, so `DEVELOPER_DIR` must be overridden):

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
```

**Reference spec:** `docs/superpowers/specs/2026-06-16-listening-transition-design.md`

---

## File Structure

- **Modify** `Daily Music/Views/TodayView.swift` — wrap `NavigationStack` in a `ZStack`, remove the `.fullScreenCover`, present `ListeningView` as an animated conditional sibling.
- **Modify** `Daily Music/Views/ListeningView.swift` — add `.contentShape(Rectangle())` so the whole player catches the return swipe.
- **Read-only** `Daily Music/Views/EntryDetailImmersive.swift` — confirm the overscroll trigger needs no change.

---

### Task 1: Confirm the open trigger needs no change

**Files:**
- Read: `Daily Music/Views/EntryDetailImmersive.swift:41-52`

- [ ] **Step 1: Re-read the overscroll trigger**

Confirm `onScrollGeometryChange` still calls `onRequestListen?()` at `offset < -80` and that `onRequestListen` is the only path that sets `showingListening = true`. The descending player (Task 2) will cover the scroll bounce; the trigger itself stays as-is. No edit in this task — this is a verification gate so the later tasks rest on a confirmed assumption.

Expected: the block matches the spec's "Root cause" description. If it has diverged, stop and reconcile with the spec before continuing.

---

### Task 2: Replace `.fullScreenCover` with an animated top-edge transition

**Files:**
- Modify: `Daily Music/Views/TodayView.swift`

- [ ] **Step 1: Add the reduceMotion environment value**

In `TodayView`, just below `@Environment(AppEnvironment.self) private var env`, add:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

- [ ] **Step 2: Wrap the `NavigationStack` in a `ZStack` and present `ListeningView` as a sibling**

The current `body` is `NavigationStack { … }` with a `.fullScreenCover(isPresented: $showingListening) { … }` modifier (around `TodayView.swift:86-100`). Make two edits:

(a) Wrap the whole `NavigationStack` (with all its existing `.toolbar` / `.sheet` / `.onChange` / `.overlay` / `.animation` / `.task` modifiers intact) in a `ZStack`, and add the player branch after it:

```swift
        ZStack {
            NavigationStack {
                // … everything currently inside body, unchanged …
            }
            // … the .task at the end stays attached to the NavigationStack …

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
                .transition(reduceMotion ? .opacity : .move(edge: .top))
                .zIndex(1)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.86),
                   value: showingListening)
```

(b) Delete the now-redundant `.fullScreenCover(isPresented: $showingListening) { … }` modifier block — its `ListeningView(...)` call moved verbatim into the `ZStack` branch above.

Keep the `.task { … }` that builds the view model attached to the `NavigationStack` (it stays where it is; the `ZStack` just encloses it).

- [ ] **Step 3: Build**

Run the build command from the plan header.
Expected: `BUILD SUCCEEDED`. If `loadedEntry` or `env.musicPlayer`/`env.listensStore` are reported unresolved, confirm the branch is inside `TodayView`'s `body` (same scope as before).

- [ ] **Step 4: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Views/TodayView.swift"
git commit -m "feat(today): top-edge transition for the listening player

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Make the whole ListeningView catch the return swipe

**Files:**
- Modify: `Daily Music/Views/ListeningView.swift:77-80`

- [ ] **Step 1: Add `.contentShape` to the root `ZStack`**

The root `ZStack` in `body` currently chains `.preferredColorScheme(.dark)` then `.simultaneousGesture(swipeUpToReturnGesture)` (around `ListeningView.swift:77-80`). Insert `.contentShape(Rectangle())` immediately before the `.simultaneousGesture` line so the transparent `Spacer` regions become hit-testable:

```swift
        .preferredColorScheme(.dark)
        // Swipe up to send the player back down to Today — the mirror of Today's
        // pull-down-to-listen. Simultaneous so it never blocks the transport/scrub.
        .contentShape(Rectangle())
        .simultaneousGesture(swipeUpToReturnGesture)
```

- [ ] **Step 2: Build**

Run the build command from the plan header.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Views/ListeningView.swift"
git commit -m "fix(listening): make the whole player swipeable to return

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Manual verification on the simulator

**Files:** none (verification only)

- [ ] **Step 1: Launch the app on the simulator**

Build-and-run on `iPhone 17` (via Xcode Run, or `xcodebuild ... build` then boot/install). Navigate to the Today tab with today's song loaded.

- [ ] **Step 2: Walk the spec's verification checklist**

From `docs/superpowers/specs/2026-06-16-listening-transition-design.md` (§ Verification):

1. Pull down on Today → player descends from the **top**, no refresh-style stall.
2. Swipe up **anywhere** on the player (not just over a button) → returns to Today with an upward slide.
3. Play/pause, restart, favorite, and the scrub bar still respond — the swipe doesn't block them.
4. Settings → Accessibility → Reduce Motion ON → both directions **cross-fade** instead of sliding.
5. Let a 30s clip finish → auto-advance back to Today animates the same way.

- [ ] **Step 3: Record the outcome**

If all five pass, the feature is done — proceed to finishing-a-development-branch. If any fails, capture which step and the observed behavior, then return to systematic-debugging before further edits.

---

## Self-Review

- **Spec coverage:**
  - Symptom 1 (refresh stall / no open animation) → Task 2 (top-edge transition covers the bounce). ✓
  - Symptom 2 (only the button is swipeable) → Task 3 (`.contentShape`). ✓
  - Symptom 3 (no return animation) → Task 2 (the `.animation(value:)` drives the `.move(edge: .top)` removal). ✓
  - reduceMotion fallback → Task 2 Step 1–2 (`.opacity` / `nil`). ✓
  - "No change to EntryDetailImmersive" → Task 1 confirms. ✓
- **Placeholder scan:** none.
- **Type consistency:** `showingListening`, `loadedEntry`, `env.musicPlayer`, `env.listensStore`, `swipeUpToReturnGesture` all match existing identifiers in the two files.
