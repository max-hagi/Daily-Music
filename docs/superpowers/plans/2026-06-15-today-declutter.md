# Today Declutter + Earned Listening — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Today tab calm and legible at a glance, and make collecting a record (grading it **mint**) something you earn by genuinely listening.

**Architecture:** Today-scoped behavior change + a SwiftUI view declutter. Collection now fires from a Today-only listen-threshold callback on the shared `ListeningView` (Vault's open-marks-heard semantics untouched). The auto-opening listening ceremony is replaced by a deep-linked daily reminder + an in-app blind pop-up. The immersive song zone is rebuilt as "Direction A": quiet utilities flanking the title, a medium 👍/👎 rating, one evolving primary button (Listen → Open in), the journal peek alone at the bottom, plus a pull-down-to-listen gesture and the streak moved into the greeting.

**Tech Stack:** SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`), iOS 18+, `@Observable` stores, UserNotifications.

**Spec:** `docs/superpowers/specs/2026-06-15-today-declutter-design.md`

### Build & test commands

`xcode-select` points at CommandLineTools, so override `DEVELOPER_DIR`:

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug test        # use `build` for view-only tasks
```

### ⚠️ One-time test-target registration

The **app target** auto-compiles new files (filesystem-synchronized group). The **test target** does NOT. The new test file `Daily MusicTests/TodayListeningTests.swift` (created in Task 1) must be added to the `Daily MusicTests` target once via Xcode (select the file → File inspector → check **Daily MusicTests** under Target Membership), or the `test` command won't see it. Do this the first time `test` is run in Phase 1.

---

## Phase 1 — Earned listening (Today-scoped)

### Task 1: `ListenTracker` pure accumulator + threshold

**Files:**
- Create: `Daily Music/Models/ListenTracker.swift`
- Test: `Daily MusicTests/TodayListeningTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Daily MusicTests/TodayListeningTests.swift`:

```swift
import Foundation
import Testing
@testable import Daily_Music

struct ListenTrackerTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    @Test func accumulatesOnlyWhilePlaying() {
        var tracker = ListenTracker()
        tracker.sample(isPlaying: true, now: at(0))
        tracker.sample(isPlaying: true, now: at(10))   // +10 playing
        tracker.sample(isPlaying: false, now: at(20))  // paused gap, no credit
        tracker.sample(isPlaying: true, now: at(30))   // restart clock
        tracker.sample(isPlaying: true, now: at(35))   // +5 playing
        #expect(tracker.accumulated == 15)
    }

    @Test func reachesThresholdAtTwentyFiveSeconds() {
        var tracker = ListenTracker()
        tracker.sample(isPlaying: true, now: at(0))
        tracker.sample(isPlaying: true, now: at(24))
        #expect(tracker.hasReachedThreshold(finished: false) == false)
        tracker.sample(isPlaying: true, now: at(25))
        #expect(tracker.hasReachedThreshold(finished: false) == true)
    }

    @Test func finishingShortClipCollectsImmediately() {
        var tracker = ListenTracker()
        tracker.sample(isPlaying: true, now: at(0))
        tracker.sample(isPlaying: true, now: at(8))    // only 8s, under threshold
        #expect(tracker.hasReachedThreshold(finished: true) == true)
    }

    @Test func scrubbingWithoutPlayingNeverCredits() {
        var tracker = ListenTracker()
        // state never .playing (scrubbing/paused): no wall-clock credit accrues
        tracker.sample(isPlaying: false, now: at(0))
        tracker.sample(isPlaying: false, now: at(60))
        #expect(tracker.accumulated == 0)
        #expect(tracker.hasReachedThreshold(finished: false) == false)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the `test` command above (register the file in Xcode first — see callout).
Expected: FAIL — "cannot find 'ListenTracker' in scope".

- [ ] **Step 3: Write the minimal implementation**

Create `Daily Music/Models/ListenTracker.swift`:

```swift
//
//  ListenTracker.swift
//  Daily Music
//
//  Pure rule for "has the listener actually heard this?". Accumulates wall-clock
//  time only while audio is PLAYING (so scrubbing/pausing can't fake a listen),
//  and treats reaching the clip's natural end as an immediate pass (covers
//  previews shorter than the threshold). Drives Today's "collect as mint" moment.
//

import Foundation

struct ListenTracker {
    /// Seconds of genuine playback required to collect a record. Tunable.
    static let collectThreshold: TimeInterval = 25

    private(set) var accumulated: TimeInterval = 0
    private var lastTick: Date?

    /// Feed the current playback state on a steady cadence. Credit only accrues
    /// across consecutive playing samples; any non-playing sample resets the clock.
    mutating func sample(isPlaying: Bool, now: Date = Date()) {
        guard isPlaying else { lastTick = nil; return }
        if let last = lastTick { accumulated += now.timeIntervalSince(last) }
        lastTick = now
    }

    func hasReachedThreshold(finished: Bool) -> Bool {
        finished || accumulated >= Self.collectThreshold
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the `test` command. Expected: PASS (4 tests in `ListenTrackerTests`).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/ListenTracker.swift" "Daily MusicTests/TodayListeningTests.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "feat(today): add ListenTracker for earned-listening threshold"
```

---

### Task 2: Collect-on-threshold in `ListeningView` (Today only)

**Files:**
- Modify: `Daily Music/Views/ListeningView.swift`
- Modify: `Daily Music/Views/TodayView.swift:101-111` (the `fullScreenCover` `ListeningView` closure)

- [ ] **Step 1: Add the opt-in callback + tracker to `ListeningView`**

In `ListeningView.swift`, add a stored property next to the other `var` inputs (after `onAdvance` is fine, but place before `@Environment`):

```swift
    /// Today-only: fired ONCE when the listener crosses the collect threshold
    /// (≥25s of playback, or the clip finishing). Vault/Favorites pass nil — their
    /// collection semantics (open = caught up) are unchanged.
    var onReachedListenThreshold: (() -> Void)? = nil
```

Add state near the other `@State`s:

```swift
    @State private var tracker = ListenTracker()
    @State private var didReachThreshold = false
    @State private var showingCollected = false
```

- [ ] **Step 2: Drive the tracker while the player is open**

Add this `.task` modifier to the `body`'s root `ZStack` (alongside the existing `.task` blocks):

```swift
        .task(id: entry.id) {
            guard onReachedListenThreshold != nil else { return }
            while !Task.isCancelled {
                tracker.sample(isPlaying: player.state == .playing)
                if !didReachThreshold,
                   tracker.hasReachedThreshold(finished: player.state == .finished) {
                    didReachThreshold = true
                    Haptics.success()
                    onReachedListenThreshold?()
                    if !reduceMotion {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showingCollected = true }
                    } else {
                        showingCollected = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
```

- [ ] **Step 3: Add a subtle in-player "Collected" confirmation**

Inside `controlDeck`'s `VStack`, directly above `EqualizerBars(...)`, add:

```swift
                if showingCollected {
                    Label("Collected — mint", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.white.opacity(0.18), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Collected as a mint record")
                }
```

- [ ] **Step 4: Wire Today's callback; stop collecting on advance**

In `TodayView.swift`, change the `fullScreenCover(isPresented: $showingListening)` body so the trailing closure no longer collects, and the threshold callback does:

```swift
            .fullScreenCover(isPresented: $showingListening) {
                if let entry = loadedEntry {
                    ListeningView(
                        entry: entry,
                        showsRevealIntro: false,
                        onReachedListenThreshold: { env.listensStore.markHeard(entry) }
                    ) {
                        showingListening = false
                        Task { await env.musicPlayer.stop() }
                    }
                }
            }
```

(Removes the `env.listensStore.markHeard(entry)` call from the advance closure; leaving early no longer collects. `showsRevealIntro` is now always false — see Task 5 for full ceremony removal.)

- [ ] **Step 5: Build**

Run the `build` command. Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Manual verification (simulator)**

- Open today's drop → let it play ~25s → success haptic + "Collected — mint" appears; dismiss → Today shows mint state.
- Open today's drop → immediately tap "Read today's story" before 25s → NOT collected (cover stays pending).
- Let a short preview finish before 25s → collects on finish.

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Views/ListeningView.swift" "Daily Music/Views/TodayView.swift"
git commit -m "feat(today): collect as mint only after genuine listening"
```

---

## Phase 2 — Greeting uses the onboarding first name

### Task 3: `PersonName.firstName` + use in Today greeting

**Files:**
- Create: `Daily Music/Models/PersonName.swift`
- Test: `Daily MusicTests/TodayListeningTests.swift` (append a struct)
- Modify: `Daily Music/Views/TodayView.swift:161-168` (`listenerName`)

- [ ] **Step 1: Write the failing tests**

Append to `Daily MusicTests/TodayListeningTests.swift`:

```swift
struct PersonNameTests {
    @Test func takesFirstWordOfAFullName() {
        #expect(PersonName.firstName(from: "Max Smith") == "Max")
    }

    @Test func stripsEmailDomainThenFirstWord() {
        #expect(PersonName.firstName(from: "max@example.com") == "max")
    }

    @Test func emptyOrWhitespaceYieldsNil() {
        #expect(PersonName.firstName(from: "") == nil)
        #expect(PersonName.firstName(from: "   ") == nil)
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(PersonName.firstName(from: "  Max  Smith ") == "Max")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the `test` command. Expected: FAIL — "cannot find 'PersonName' in scope".

- [ ] **Step 3: Write the implementation**

Create `Daily Music/Models/PersonName.swift`:

```swift
//
//  PersonName.swift
//  Daily Music
//
//  Shared rule for the friendly first-name greeting, so Today and onboarding
//  ("You're all set, Max") agree. Strips any email @domain, then takes the
//  first whitespace-separated word.
//

import Foundation

enum PersonName {
    /// The first name to greet with, or nil when there's nothing usable.
    static func firstName(from raw: String) -> String? {
        let beforeAt = raw.split(separator: "@").first.map(String.init) ?? raw
        let firstWord = beforeAt
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstWord, !firstWord.isEmpty else { return nil }
        return firstWord
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the `test` command. Expected: PASS (`PersonNameTests`, 4 tests).

- [ ] **Step 5: Use it in `TodayView.listenerName`**

Replace the body of `listenerName` in `TodayView.swift`:

```swift
    private var listenerName: String {
        guard let displayName = env.session.session?.displayName,
              let first = PersonName.firstName(from: displayName) else {
            return "there"
        }
        return first
    }
```

- [ ] **Step 6: Build**

Run the `build` command. Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Models/PersonName.swift" "Daily MusicTests/TodayListeningTests.swift" "Daily Music/Views/TodayView.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "feat(today): greet with the onboarding first name"
```

---

## Phase 3 — New-drop announcement (replaces auto-ceremony)

### Task 4: `NewDropPromptRule` pure gating

**Files:**
- Create: `Daily Music/Models/NewDropPromptRule.swift`
- Test: `Daily MusicTests/TodayListeningTests.swift` (append a struct)

- [ ] **Step 1: Write the failing tests**

Append to `Daily MusicTests/TodayListeningTests.swift`:

```swift
struct NewDropPromptRuleTests {
    @Test func showsWhenUncollectedAndNotDismissed() {
        #expect(NewDropPromptRule.shouldShow(isCollected: false, dismissedThisSession: false) == true)
    }

    @Test func hiddenOnceCollected() {
        #expect(NewDropPromptRule.shouldShow(isCollected: true, dismissedThisSession: false) == false)
    }

    @Test func hiddenAfterDismissThisSession() {
        #expect(NewDropPromptRule.shouldShow(isCollected: false, dismissedThisSession: true) == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the `test` command. Expected: FAIL — "cannot find 'NewDropPromptRule' in scope".

- [ ] **Step 3: Write the implementation**

Create `Daily Music/Models/NewDropPromptRule.swift`:

```swift
//
//  NewDropPromptRule.swift
//  Daily Music
//
//  Pure rule for the in-app "your song of the day is ready" pop-up. It appears
//  when today's drop is still uncollected and the user hasn't dismissed it this
//  session. Once collected (or dismissed), the song zone's own affordances take
//  over and we don't nag again.
//

import Foundation

enum NewDropPromptRule {
    static func shouldShow(isCollected: Bool, dismissedThisSession: Bool) -> Bool {
        !isCollected && !dismissedThisSession
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the `test` command. Expected: PASS (`NewDropPromptRuleTests`, 3 tests).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/NewDropPromptRule.swift" "Daily MusicTests/TodayListeningTests.swift"
git commit -m "feat(today): add new-drop prompt gating rule"
```

---

### Task 5: `NewDropPrompt` view + present over Today; remove auto-open

**Files:**
- Create: `Daily Music/Views/Today/NewDropPrompt.swift`
- Modify: `Daily Music/Views/TodayView.swift` (present pop-up; remove `onChange` auto-open + `launchIntoCeremony`/ceremony state)
- Modify: `Daily Music/Models/ListeningCeremony.swift` (retire `shouldAutoOpen`/`autoOpenDelay`)

- [ ] **Step 1: Create the blind pop-up view**

Create `Daily Music/Views/Today/NewDropPrompt.swift`:

```swift
//
//  NewDropPrompt.swift
//  Daily Music
//
//  The in-app "your song of the day is ready" card that replaces the auto-opening
//  ceremony. Blind by design — the song stays hidden so tapping Listen is still a
//  reveal. Listen opens the player; Maybe later drops to the (uncollected) song zone.
//

import SwiftUI

struct NewDropPrompt: View {
    let dateText: String
    let onListen: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle().fill(.white.opacity(0.12))
                        .frame(width: 76, height: 76)
                        .scaleEffect(pulse && !reduceMotion ? 1.12 : 0.96)
                    Image(systemName: "music.note")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 6) {
                    Text(dateText.uppercased())
                        .font(.caption.weight(.heavy)).tracking(2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Your song of the day is ready")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text("Hear it first — listen all the way to collect it.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                Button(action: onListen) {
                    Label("Listen", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(tint: Theme.Brand.gradient[0]))

                Button("Maybe later", action: onDismiss)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 2)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
```

- [ ] **Step 2: Present it from `TodayView`, remove the auto-open**

In `TodayView.swift`:

Add state (near the other `@State`s):

```swift
    @State private var showingNewDropPrompt = false
    @State private var dismissedDropPromptThisSession = false
```

Replace the entire `.onChange(of: loadedEntry?.id) { ... }` block (the auto-open ceremony) with logic that shows the prompt instead:

```swift
            .onChange(of: loadedEntry?.id) { _, _ in evaluateNewDropPrompt() }
            .onChange(of: env.listensStore.heardAt) { _, _ in evaluateNewDropPrompt() }
            .overlay {
                if showingNewDropPrompt, let entry = loadedEntry {
                    NewDropPrompt(
                        dateText: todayString,
                        onListen: {
                            showingNewDropPrompt = false
                            listeningIsCeremony = false
                            showingListening = true
                        },
                        onDismiss: {
                            showingNewDropPrompt = false
                            dismissedDropPromptThisSession = true
                        }
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showingNewDropPrompt)
```

Add the helper method (inside `TodayView`):

```swift
    private func evaluateNewDropPrompt() {
        guard let entry = loadedEntry else { return }
        let isCollected = env.listensStore.isHeard(entry)
        showingNewDropPrompt = NewDropPromptRule.shouldShow(
            isCollected: isCollected,
            dismissedThisSession: dismissedDropPromptThisSession
        )
    }
```

Also call `evaluateNewDropPrompt()` once after `await model?.load()` in the `.task`. Delete the now-unused `listeningIsCeremony` ceremony intro path if it is no longer read elsewhere, and remove the `env.launchIntoCeremony` usage from the deleted block. Keep `showsRevealIntro: false` at the `ListeningView` call site (already set in Task 2).

- [ ] **Step 3: Retire the ceremony helpers**

In `ListeningCeremony.swift`, remove `shouldAutoOpen` and `autoOpenDelay` (no remaining callers). If `env.launchIntoCeremony` is now unused app-wide, remove that property from `AppEnvironment`; if removing it is noisy, leave it set-but-unread and note it. Grep to confirm no other references:

```bash
grep -rn "shouldAutoOpen\|autoOpenDelay\|launchIntoCeremony\|listeningIsCeremony" "Daily Music"
```

Resolve every hit.

- [ ] **Step 4: Build**

Run the `build` command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Manual verification**

- Fresh launch with an uncollected drop → pop-up appears over Today (song hidden). Listen → player. Maybe later → dismisses to the (pending) song zone, doesn't reappear this session.
- After collecting → no pop-up; relaunch with a collected drop → no pop-up.

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Views/Today/NewDropPrompt.swift" "Daily Music/Views/TodayView.swift" "Daily Music/Models/ListeningCeremony.swift" "Daily Music/App/AppEnvironment.swift"
git commit -m "feat(today): replace auto-ceremony with blind new-drop prompt"
```

---

### Task 6: Daily reminder deep-links to Today

**Files:**
- Modify: `Daily Music/Services/NotificationService.swift:90-100` (daily reminder content)

- [ ] **Step 1: Add the deep-link payload**

In `scheduleDailyReminder`, after `content.sound = .default` (inside the `for offset` loop), add:

```swift
            // Tapping the reminder opens Today; the in-app new-drop prompt handles
            // the rest (RootView.onOpenURL → pendingTodayRoute → MainTabView).
            content.userInfo = ["url": "dailymusic://today"]
```

- [ ] **Step 2: Build**

Run the `build` command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual verification**

- With notifications authorized and a reminder scheduled, trigger/await the reminder, tap it → app opens on the Today tab. (The `dailymusic://today` route already exists in `RootView`.)

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Services/NotificationService.swift"
git commit -m "feat(today): daily reminder deep-links to Today"
```

---

## Phase 4 — Decluttered song zone (Direction A)

> These are SwiftUI composition changes; verify by build + on-device look. Keep each task's diff self-contained and commit between them.

### Task 7: Title row with flanking utilities + medium rating; drop inline reactions

**Files:**
- Modify: `Daily Music/Views/EntryDetailImmersive.swift` (`songZone`, `ratingExperience`; remove `inlineReactionsBar`)
- Modify: `Daily Music/Views/EntryActionCluster.swift` (`entryIdentityWithInlineControls` already flanks title — add the react button; size the rating)

- [ ] **Step 1: Add react to the title-flanking controls**

In `EntryActionCluster.swift`, `entryIdentityWithInlineControls(dateLabel:)`, replace the trailing controls column so the right side carries react **and** info (left stays heart):

```swift
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    VStack(spacing: Theme.Spacing.sm) {
                        compactHeartButton
                    }
                    .frame(width: 82, alignment: .leading)

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        reactionButton(controlSize: 40, symbolSize: 16)
                        compactInfoButton
                    }
                    .frame(width: 96, alignment: .trailing)
                }
```

- [ ] **Step 2: Make the immersive rating medium-sized**

In `EntryDetailImmersive.swift`, change `primaryRatingControl` usage by giving `ratingExperience` a medium control. Replace `ratingExperience`:

```swift
    private var ratingExperience: some View {
        RatingBar(
            entry: entry,
            accent: palette.accent,
            controlSize: 48,
            symbolSize: 22,
            spacing: 14,
            isReadOnly: !allowsRating
        )
        .frame(maxWidth: 420)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, 2)
    }
```

(Medium — clearly the main action, not the old 84pt hero. Sizing will be fine-tuned during testing.)

- [ ] **Step 3: Remove the standalone reactions bar from the song zone**

In `EntryDetailImmersive.swift` `songZone`, delete the `inlineReactionsBar` line from the stack, and delete the now-unused `inlineReactionsBar` computed property. The resulting `songZone` order is: greeting → art → `entryIdentityWithInlineControls` → `ratingExperience` → (Task 8 button) → Spacer → journal dock.

- [ ] **Step 4: Build**

Run the `build` command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Manual verification**

- Song zone shows: title with ♡ (left) and ☺ ⓘ (right); medium 👍/👎 below; no separate reactions pill. React button still opens the reactions popover.

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Views/EntryDetailImmersive.swift" "Daily Music/Views/EntryActionCluster.swift"
git commit -m "refactor(today): quiet utilities by the title, medium rating, drop reactions pill"
```

---

### Task 8: Evolving primary button; OpenInSection cleanup

**Files:**
- Modify: `Daily Music/Views/OpenInSection.swift` (remove visible ⋯; long-press alternates; expose a reusable "open in default" action + button)
- Modify: `Daily Music/Views/EntryDetailImmersive.swift` (replace `openInSectionWithRatingNudge` with the evolving button)

- [ ] **Step 1: Rework `OpenInSection` — drop the ⋯, add long-press alternates**

Replace the `body` of `OpenInSection` so the primary button opens the default service, a **long-press** context menu offers the others, and the save button stays:

```swift
    var body: some View {
        HStack(spacing: 10) {
            Button {
                if let url = preferred.url(for: entry) { openURL(url) }
            } label: {
                ZStack {
                    Text("Open in \(preferred.displayName)").lineLimit(1)
                    HStack {
                        ServiceLogo(service: preferred)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.forward")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.md)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: accent))
            .contextMenu { alternateServiceButtons }   // long-press → other services

            if rowState.showsSaveButton {
                Button(action: saveAction) {
                    Image(systemName: rowState.saveIconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(rowState.isSaved ? .green : accent)
                        .frame(width: 48, height: 48)
                        .symbolEffect(.bounce, value: rowState.isSaved)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .disabled(rowState.isSaveDisabled)
                .accessibilityLabel(rowState.isSaved ? "Added to your Daily Music playlist" : "Save to your Daily Music playlist")
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder private var alternateServiceButtons: some View {
        ForEach(StreamingService.allCases.filter { $0 != preferred }) { service in
            Button {
                if let url = service.url(for: entry) { openURL(url) }
            } label: {
                Label("Open in \(service.displayName)", systemImage: "arrow.up.forward.app")
            }
        }
    }
```

- [ ] **Step 2: Add the evolving primary button to the immersive layout**

In `EntryDetailImmersive.swift`, replace `openInSectionWithRatingNudge` with a state-aware control. When today's drop is **uncollected**, show "Listen to collect" (opens the player via the same path as the headphones/pull-down); when **collected**, show the existing `OpenInSection`. The rating nudge stays above it:

```swift
    private var openInSectionWithRatingNudge: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if shouldShowRatingNudge {
                ratingNudge.padding(.horizontal)
            }

            if isCollected {
                OpenInSection(
                    entry: entry,
                    accent: palette.accent,
                    rowState: openInRowState,
                    saveAction: saveToLibrary
                )
                .alert("Couldn't save this song", isPresented: $saveFailed) {
                    Button("OK", role: .cancel) {}
                } message: { Text(saveErrorMessage) }
            } else {
                Button { onRequestListen?() } label: {
                    Label("Listen to collect", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(tint: palette.accent))
                .padding(.horizontal)
            }
        }
        .padding(.top, Theme.Spacing.lg)
        .animation(ratingNudgeAnimation, value: shouldShowRatingNudge)
    }

    private var isCollected: Bool {
        env.listensStore.isHeard(entry)
    }
```

Add the listen hook to `EntryDetailView` (so Today can present the player). In `EntryDetailView.swift`, add a stored input:

```swift
    /// Today supplies this so the "Listen to collect" button + pull-down can open
    /// the player. nil elsewhere (Vault/Favorites have their own listen entry points).
    var onRequestListen: (() -> Void)? = nil
```

In `TodayView.swift`, pass it to the `EntryDetailView(...)` in the `.loaded` case:

```swift
                            onRequestListen: { showingListening = true }
```

(Insert as an argument; keep the existing ones.)

- [ ] **Step 3: Build**

Run the `build` command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual verification**

- Uncollected: bottom button reads "Listen to collect" and opens the player. After collecting: button becomes "Open in {default}". Long-press it → other services. ⋯ is gone.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/OpenInSection.swift" "Daily Music/Views/EntryDetailImmersive.swift" "Daily Music/Views/EntryDetailView.swift" "Daily Music/Views/TodayView.swift"
git commit -m "feat(today): evolving Listen→Open-in button; long-press for other services"
```

---

### Task 9: Sleeve treatment on Today's cover

**Files:**
- Modify: `Daily Music/Views/EntryDetailImmersive.swift` (`songZone` cover)

- [ ] **Step 1: Render the cover via `SleeveView` on Today**

In `EntryDetailImmersive.swift` `songZone`, replace the `AlbumArtView(...)` cover line with a sleeve-rendered cover that reflects collection state. Use the entry's `ListenStatus`:

```swift
            SleeveView(
                entry: entry,
                status: env.listensStore.status(for: entry),
                size: coverSleeveSize
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, albumArtHorizontalPadding)
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7),
                       value: env.listensStore.status(for: entry).indicatorColor)
```

Add a helper for the hero sleeve size near the other computed props in this file:

```swift
    private var coverSleeveSize: CGFloat { 300 }
```

(SleeveView already previews at 132pt; 300pt is the hero size. Tune during testing.)

- [ ] **Step 2: Build**

Run the `build` command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual verification**

- Uncollected today's drop → pending sleeve (accent border + peeking disc). After the collect moment → mint sleeve (gloss). Visual matches the Vault's language.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/EntryDetailImmersive.swift"
git commit -m "feat(today): show pending→mint sleeve state on the cover"
```

---

### Task 10: Streak chip into the greeting; trim the toolbar

**Files:**
- Modify: `Daily Music/Views/EntryDetailView.swift` (accept an optional greeting accessory)
- Modify: `Daily Music/Views/EntryDetailImmersive.swift` (render the accessory in the greeting row)
- Modify: `Daily Music/Views/TodayView.swift` (build the streak chip; remove the streak + headphones toolbar items)

- [ ] **Step 1: Add a greeting-accessory slot to `EntryDetailView`**

In `EntryDetailView.swift`, add:

```swift
    /// Optional trailing chip shown in the immersive greeting row (Today's streak).
    /// Type-erased so callers pass any small view; nil on Vault/Favorites.
    var greetingAccessory: AnyView? = nil
```

- [ ] **Step 2: Render it in the greeting row**

In `EntryDetailImmersive.swift` `songZone`, replace the `if let preArtworkMessage { ... }` block with a row that pairs the greeting and the accessory:

```swift
            if preArtworkMessage != nil || greetingAccessory != nil {
                HStack(spacing: Theme.Spacing.sm) {
                    if let preArtworkMessage {
                        Text(preArtworkMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let greetingAccessory {
                        greetingAccessory
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
            } else {
                Color.clear.frame(height: 16).padding(.top, Theme.Spacing.sm)
            }
```

- [ ] **Step 3: Pass the streak chip from Today; remove toolbar items**

In `TodayView.swift`:

In the `.loaded` `EntryDetailView(...)`, add the accessory when a streak exists:

```swift
                            greetingAccessory: model.streak.flatMap { streak in
                                streak.current > 0 ? AnyView(TodayToolbarStreakBadge(streak: streak)) : nil
                            },
```

Delete the streak `ToolbarItem` (the `if let streak = model?.streak ...` one) and the headphones `ToolbarItem` from the `.toolbar`. Keep the gear (leading) and the `TodayToolbarLiveBadge` (trailing). `TodayToolbarStreakBadge` is reused as-is (its tap popover, flare, and milestone haptic all still work in the content position).

- [ ] **Step 4: Build**

Run the `build` command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Manual verification**

- Streak now sits as a chip in the greeting row (tap → popover with goal-gradient + best run; flare still plays once/day). Toolbar shows only gear + "N listening". No headphones button.

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Views/EntryDetailView.swift" "Daily Music/Views/EntryDetailImmersive.swift" "Daily Music/Views/TodayView.swift"
git commit -m "feat(today): move streak into the greeting; trim the toolbar"
```

---

### Task 11: Pull-down to listen / replay

**Files:**
- Modify: `Daily Music/Views/EntryDetailImmersive.swift` (top cue + pull gesture)
- Modify: `Daily Music/Views/TodayView.swift` (already provides `onRequestListen` from Task 8)

- [ ] **Step 1: Add the pull cue at the top of the song zone**

In `EntryDetailImmersive.swift` `songZone`, insert above the greeting row a small cue (only meaningful on Today, i.e. when `onRequestListen != nil`):

```swift
            if onRequestListen != nil {
                Label(isCollected ? "pull down to replay" : "pull down to listen",
                      systemImage: "chevron.down")
                    .labelStyle(.titleAndIcon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .opacity(0.65)
                    .padding(.top, 4)
            }
```

- [ ] **Step 2: Trigger listen on overscroll-pull**

On the immersive `ScrollView` (in `immersiveLayout`), add a pull detector using scroll geometry. Add this `.onScrollGeometryChange` alongside the existing one:

```swift
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top   // negative when pulled past top
            } action: { _, offset in
                guard onRequestListen != nil else { return }
                if offset < -80, !pullTriggered {
                    pullTriggered = true
                    Haptics.tap()
                    onRequestListen?()
                } else if offset >= -8 {
                    pullTriggered = false   // re-arm once released back to top
                }
            }
```

Add the guard state to `EntryDetailView.swift` (shared state lives there):

```swift
    @State var pullTriggered = false
```

- [ ] **Step 3: Build**

Run the `build` command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual verification**

- At the top of the song zone, a "⌄ pull down to listen/replay" cue is visible. Pulling down past ~80pt opens the player (haptic). It re-arms after releasing. Normal upward scroll still snaps to the journal — no conflict.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/EntryDetailImmersive.swift" "Daily Music/Views/EntryDetailView.swift"
git commit -m "feat(today): pull-down to listen/replay with a cue"
```

---

## Final verification

- [ ] Run the full test suite: `test` command → all green (`ListenTrackerTests`, `PersonNameTests`, `NewDropPromptRuleTests` + existing).
- [ ] Full manual pass on device/simulator: new-drop prompt → listen ≥25s → collect moment → mint sleeve → "Open in" button; Maybe later → pending zone; pull-down replay; streak chip popover; long-press alternate services; greeting shows onboarding first name.
- [ ] `grep -rn "shouldAutoOpen\|autoOpenDelay\|inlineReactionsBar" "Daily Music"` returns nothing.

## Notes for the executor

- Work on a feature branch (the tree currently has unrelated Vault changes; commit only the files listed per task).
- `RatingBar` already supports `controlSize`/`symbolSize`/`spacing` (see its use in `EntryActionCluster.primaryRatingControl`).
- `Haptics.success()` / `.tap()` and `PrimaryActionButtonStyle` / `Theme.*` already exist and are used throughout.
- Sizing numbers (rating 48pt, sleeve 300pt, pull threshold 80pt, collect threshold 25s) are deliberately tunable; expect to adjust them when testing.
```
