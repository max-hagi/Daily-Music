# Onboarding Music Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the onboarding taste seed into a swipeable card stack with auto-playing, looping previews, ending in a direct handoff into today's first listening ceremony.

**Architecture:** A pure `TasteSeedDeck` state machine (new model) drives a dumb `TasteSeedCardStack` view; `TasteSeedView` keeps owning phases and persistence. Auto-play rides the existing `MusicPlayer` (`toggle` from `.finished` already restarts a clip — that *is* the loop). The finale sets a `launchIntoCeremony` flag on `AppEnvironment` that `TodayView` consumes to skip its 0.6s settle delay.

**Tech Stack:** SwiftUI (iOS 17+, `@Observable`), Swift Testing (`import Testing`, `@Test`, `#expect`).

**Spec:** `docs/superpowers/specs/2026-06-10-onboarding-music-overhaul-design.md`

## Build & test commands

`xcode-select` points at CommandLineTools on this machine — every `xcodebuild` call needs `DEVELOPER_DIR`:

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"

# Full test suite
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20

# One suite (substitute the struct name)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/TasteSeedTests" 2>&1 | tail -20
```

**Critical project quirk:** the app target (`Daily Music/`) is a file-system-synchronized group — new `.swift` files compile automatically. The test target (`Daily MusicTests/`) is NOT — a new test file requires editing `project.pbxproj` via Xcode. **This plan therefore adds tests only to existing test files** (`TasteSeedTests.swift`, `PlaybackTests.swift`). Do not create new test files.

---

### Task 1: Fix the stale StarterPack count test

StarterPack grew from 10 to 13 songs (commits 92803c0, 3b81442) but `starterPackHasTenUniqueSongs` still expects 10. Fix it so the suite is green before we build on it.

**Files:**
- Modify: `Daily MusicTests/TasteSeedTests.swift:9-12`

- [ ] **Step 1: Update the test to assert uniqueness without a brittle hardcoded count**

Replace:

```swift
    @Test func starterPackHasTenUniqueSongs() {
        #expect(StarterPack.songs.count == 10)
        #expect(Set(StarterPack.songs.map(\.id)).count == 10)
    }
```

with:

```swift
    @Test func starterPackSongsAreUniqueAndPlentiful() {
        // Enough songs to clear the taste-mirror unlock threshold (10), all unique.
        #expect(StarterPack.songs.count >= 10)
        #expect(Set(StarterPack.songs.map(\.id)).count == StarterPack.songs.count)
        #expect(Set(StarterPack.songs.map(\.appleMusicID)).count == StarterPack.songs.count)
    }
```

- [ ] **Step 2: Run the suite, verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/TasteSeedTests" 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Daily MusicTests/TasteSeedTests.swift"
git commit -m "test: unbrittle StarterPack count test (pack grew to 13 songs)"
```

---

### Task 2: TasteSeedDeck model (TDD)

A pure value type owning "which card is front, what's been judged" — extracted from `TasteSeedView`'s ad-hoc `index`/`picks` state so the stack flow is unit-testable.

**Files:**
- Create: `Daily Music/Models/TasteSeedDeck.swift`
- Test: `Daily MusicTests/TasteSeedTests.swift` (append inside the existing `TasteSeedTests` struct)

- [ ] **Step 1: Write the failing tests**

Append inside `struct TasteSeedTests` (the `entry(mood:genre:year:)` helper already exists in this file):

```swift
    // MARK: TasteSeedDeck

    private func tinyDeck() -> TasteSeedDeck {
        TasteSeedDeck(songs: [
            entry(mood: "Euphoric", genre: "Pop", year: 2020),
            entry(mood: "Melancholy", genre: "Alternative", year: 2015),
            entry(mood: "Defiant", genre: "Rock", year: 1991),
            entry(mood: "Dreamy", genre: "Alternative", year: 2018),
        ])
    }

    @Test func deckStartsAtFirstSong() {
        let deck = tinyDeck()
        #expect(deck.current?.id == deck.songs[0].id)
        #expect(deck.positionText == "1 of 4")
        #expect(!deck.isComplete)
        #expect(deck.picks.isEmpty)
    }

    @Test func judgingAdvancesAndRecordsThePick() {
        var deck = tinyDeck()
        deck.judge(1)
        #expect(deck.current?.id == deck.songs[1].id)
        #expect(deck.positionText == "2 of 4")
        #expect(deck.picks.count == 1)
        #expect(deck.picks[0].value == 1)
        #expect(deck.picks[0].entry.id == deck.songs[0].id)
    }

    @Test func judgingTheLastSongCompletesTheDeck() {
        var deck = tinyDeck()
        deck.judge(1); deck.judge(-1); deck.judge(1); deck.judge(-1)
        #expect(deck.isComplete)
        #expect(deck.current == nil)
        #expect(deck.picks.count == 4)
        #expect(deck.picks.map(\.value) == [1, -1, 1, -1])
    }

    @Test func judgingPastTheEndIsANoOp() {
        var deck = tinyDeck()
        for _ in 0..<6 { deck.judge(1) }   // 2 extra judgments
        #expect(deck.picks.count == 4)
        #expect(deck.isComplete)
    }

    @Test func upcomingShowsFrontPlusPeekingCards() {
        var deck = tinyDeck()
        #expect(deck.upcoming.map(\.id) == Array(deck.songs.prefix(3)).map(\.id))
        deck.judge(1); deck.judge(1)
        #expect(deck.upcoming.map(\.id) == [deck.songs[2].id, deck.songs[3].id])  // only 2 left
        deck.judge(1); deck.judge(1)
        #expect(deck.upcoming.isEmpty)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/TasteSeedTests" 2>&1 | tail -20`
Expected: BUILD FAILED — `cannot find 'TasteSeedDeck' in scope`

- [ ] **Step 3: Implement the model**

Create `Daily Music/Models/TasteSeedDeck.swift` (app target auto-compiles new files):

```swift
//
//  TasteSeedDeck.swift
//  Daily Music
//
//  Pure state machine for the onboarding card stack: which StarterPack song is
//  front, which are peeking behind it, and what's been judged so far. The view
//  (TasteSeedCardStack/TasteSeedView) renders this; persistence (SeedRatings)
//  and phase changes stay in TasteSeedView.
//

import Foundation

struct TasteSeedDeck {
    let songs: [DailyEntry]
    private(set) var index = 0
    private(set) var picks: [RatedSong] = []

    init(songs: [DailyEntry]) {
        self.songs = songs
    }

    /// The front card (nil once every song is judged).
    var current: DailyEntry? {
        index < songs.count ? songs[index] : nil
    }

    /// Front card plus up to two peeking behind it, front first.
    var upcoming: [DailyEntry] {
        guard index < songs.count else { return [] }
        return Array(songs[index..<min(index + 3, songs.count)])
    }

    var isComplete: Bool { index >= songs.count }

    var positionText: String {
        "\(min(index + 1, songs.count)) of \(songs.count)"
    }

    /// Record a judgment (+1 like / -1 dislike) for the front card and advance.
    mutating func judge(_ value: Int) {
        guard let song = current else { return }
        picks.append(RatedSong(entry: song, value: value))
        index += 1
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: same command as Step 2.
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/TasteSeedDeck.swift" "Daily MusicTests/TasteSeedTests.swift"
git commit -m "feat(onboarding): TasteSeedDeck — pure card-stack state machine"
```

---

### Task 3: Pin the loop foundation in MusicPlayer (TDD on existing behavior)

The preview loop is just "when the player reports `.finished` during rating, call `toggle(current)` again" — `toggle` from `.finished` runs `startFresh`. Pin that with a test so a future `MusicPlayer` refactor can't silently break the loop.

**Files:**
- Test: `Daily MusicTests/PlaybackTests.swift` (append inside the existing `PlaybackTests` struct, which already defines `FakeEngine` and `sampleEntry()`)

- [ ] **Step 1: Write the test**

Append inside `struct PlaybackTests`:

```swift
    // The taste-seed loop depends on this: replaying a finished clip via toggle()
    // must start it fresh (not resume), so onboarding can loop previews.
    @Test func toggleAfterFinishedReplaysFromStart() async {
        let engine = FakeEngine()
        let player = MusicPlayer(engine: engine)
        let entry = sampleEntry()
        await player.toggle(entry)            // play #1
        engine.onProgress?(30, 30)
        engine.onFinish?()                    // clip ends
        #expect(player.state == .finished)
        await player.toggle(entry)            // the loop's replay call
        #expect(engine.playCalls == 2)        // fresh play, not resume
        #expect(engine.resumeCalls == 0)
        #expect(player.state == .playing)
        #expect(player.nowPlayingEntryID == entry.id)
    }
```

- [ ] **Step 2: Run the suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/PlaybackTests" 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **` (this pins existing behavior; if it fails, STOP — the loop design assumption is wrong, re-read `MusicPlayer.toggle`'s `.finished` branch before proceeding)

- [ ] **Step 3: Commit**

```bash
git add "Daily MusicTests/PlaybackTests.swift"
git commit -m "test(playback): pin toggle-after-finished replay (taste-seed loop foundation)"
```

---

### Task 4: Ceremony delay rule (TDD)

`TodayView` sleeps 0.6s before raising the ceremony. The finale needs that to be 0 when arriving from onboarding. Make the delay a pure, tested rule on `ListeningCeremony`.

**Files:**
- Modify: `Daily Music/Models/ListeningCeremony.swift`
- Test: `Daily MusicTests/PlaybackTests.swift` (the existing ceremony tests live here)

- [ ] **Step 1: Write the failing test**

Append inside `struct PlaybackTests`:

```swift
    @Test func ceremonyDelayIsZeroWhenLaunchingFromOnboarding() {
        #expect(ListeningCeremony.autoOpenDelay(launchingFromOnboarding: true) == .zero)
        #expect(ListeningCeremony.autoOpenDelay(launchingFromOnboarding: false) == .seconds(0.6))
    }
```

- [ ] **Step 2: Run, verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/PlaybackTests" 2>&1 | tail -20`
Expected: BUILD FAILED — `type 'ListeningCeremony' has no member 'autoOpenDelay'`

- [ ] **Step 3: Implement**

In `Daily Music/Models/ListeningCeremony.swift`, add inside `enum ListeningCeremony`:

```swift
    /// How long Today settles on screen before the ceremony rises. Day one —
    /// arriving straight from the onboarding reveal — skips the beat so the
    /// arc (rate songs → archetype → first song) is unbroken.
    static func autoOpenDelay(launchingFromOnboarding: Bool) -> Duration {
        launchingFromOnboarding ? .zero : .seconds(0.6)
    }
```

- [ ] **Step 4: Run, verify it passes**

Run: same command as Step 2.
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/ListeningCeremony.swift" "Daily MusicTests/PlaybackTests.swift"
git commit -m "feat(today): ListeningCeremony.autoOpenDelay — zero beat when arriving from onboarding"
```

---

### Task 5: TasteSeedCardStack view

The dumb deck renderer: front card draggable with judgment badges, next cards peeking behind. No unit tests (pure SwiftUI gesture/animation) — verified by hand in Task 8.

**Files:**
- Create: `Daily Music/Views/Onboarding/TasteSeedCardStack.swift`

- [ ] **Step 1: Create the view**

```swift
//
//  TasteSeedCardStack.swift
//  Daily Music
//
//  The onboarding swipe deck. Renders TasteSeedDeck.upcoming (front first):
//  the front card follows the drag with rotation and an INTO IT / NAH badge,
//  flying off past the threshold; the next cards peek behind. Dumb on purpose —
//  judgment recording, persistence, and audio live in TasteSeedView.
//

import SwiftUI

struct TasteSeedCardStack: View {
    let cards: [DailyEntry]            // deck.upcoming — front card first, max 3
    var onTapFront: () -> Void         // tap art → pause/resume preview
    var onJudge: (Int) -> Void         // +1 / -1 for the front card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGSize = .zero
    @State private var flying = false  // front card is mid-fling; ignore input

    private let commitDistance: CGFloat = 110

    var body: some View {
        ZStack {
            // Reversed so the front card (index 0) draws on top.
            ForEach(Array(cards.enumerated().reversed()), id: \.element.id) { depth, song in
                card(song, depth: depth)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: cards.first?.id)
    }

    @ViewBuilder
    private func card(_ song: DailyEntry, depth: Int) -> some View {
        let isFront = depth == 0
        VStack(spacing: 10) {
            AlbumArtView(url: song.albumArtURL, cornerRadius: 24)
                .frame(maxWidth: 300)
                .overlay(alignment: .topLeading) { if isFront { badge } }
            VStack(spacing: 2) {
                Text(song.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                Text(song.artist)
                    .font(.headline)
                    .foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .opacity(isFront ? 1 : 0)   // only the front card shows its meta
        }
        .scaleEffect(isFront ? 1 : 1 - 0.06 * CGFloat(depth))
        .offset(y: isFront ? 0 : CGFloat(depth) * 14)
        .rotationEffect(.degrees(isFront ? Double(drag.width / 18) : (depth == 1 ? -2.5 : 2.5)))
        .offset(isFront ? drag : .zero)
        .shadow(color: .black.opacity(isFront ? 0.25 : 0.1), radius: 14, y: 8)
        .zIndex(isFront ? 1 : 0)
        .onTapGesture { if isFront { onTapFront() } }
        .gesture(isFront ? dragGesture : nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isFront ? "\(song.title) by \(song.artist), now previewing" : "")
        .accessibilityHidden(!isFront)
        .accessibilityAction(named: "Like") { onJudge(1) }
        .accessibilityAction(named: "Dislike") { onJudge(-1) }
        .accessibilityAction(named: "Pause or play preview") { onTapFront() }
    }

    // The INTO IT / NAH stamp that fades in as the drag approaches the threshold.
    @ViewBuilder private var badge: some View {
        let strength = min(1, abs(drag.width) / commitDistance)
        if drag.width != 0 {
            Text(drag.width > 0 ? "INTO IT" : "NAH")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(drag.width > 0 ? .green : .secondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(drag.width > 0 ? Color.green : Color.secondary, lineWidth: 3))
                .rotationEffect(.degrees(drag.width > 0 ? -12 : 12))
                .padding(14)
                .opacity(Double(strength))
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !flying else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !flying else { return }
                if abs(value.translation.width) >= commitDistance {
                    judge(value.translation.width > 0 ? 1 : -1)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        drag = .zero
                    }
                }
            }
    }

    private func judge(_ value: Int) {
        if reduceMotion {
            // No fling — TasteSeedView's card-change crossfade handles the transition.
            drag = .zero
            onJudge(value)
            return
        }
        flying = true
        withAnimation(.easeOut(duration: 0.25)) {
            drag = CGSize(width: value > 0 ? 640 : -640, height: drag.height * 1.5)
        } completion: {
            onJudge(value)
            drag = .zero
            flying = false
        }
    }
}
```

- [ ] **Step 2: Build (no tests for a pure view; just prove it compiles)**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Onboarding/TasteSeedCardStack.swift"
git commit -m "feat(onboarding): TasteSeedCardStack — swipeable deck with judgment badges"
```

---

### Task 6: Rewire TasteSeedView — deck, stack, auto-play, loop

Replace the `index`/`picks` state with `TasteSeedDeck`, the static card with the stack, and tap-to-play with auto-play + loop. Keep compact fallback thumbs for accessibility.

**Files:**
- Modify: `Daily Music/Views/Onboarding/TasteSeedView.swift`

- [ ] **Step 1: Replace state and rating view**

Replace these properties (currently `@State private var index = 0` and `@State private var picks: [RatedSong] = []` plus the `current` computed var):

```swift
    @State private var deck = TasteSeedDeck(songs: StarterPack.songs)
```

(Delete `private let songs = StarterPack.songs`, `@State private var index`, `@State private var picks`, and `private var current`.)

Update the `index`-keyed animation modifier on the body's ZStack from `value: index` to `value: deck.index`.

Replace the whole `ratingView` and `judgmentButton` with:

```swift
    // MARK: rating — the swipe deck
    private var ratingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer(minLength: Theme.Spacing.xl)
            Text(deck.positionText)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            TasteSeedCardStack(
                cards: deck.upcoming,
                onTapFront: { if let song = deck.current { togglePreview(song) } },
                onJudge: judge
            )

            Text(player.state == .paused ? "Tap the art to resume" : "Previewing — tap the art to pause")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            // Compact fallbacks: swiping is the primary gesture, but the thumbs
            // stay for one-handed reach, VoiceOver, and Reduce Motion users.
            HStack(spacing: Theme.Spacing.xl) {
                judgmentButton(value: -1, symbol: "hand.thumbsdown.fill", tint: .secondary)
                judgmentButton(value: 1, symbol: "hand.thumbsup.fill", tint: Theme.Brand.gradient[0])
            }
            .padding(.bottom, 32)
        }
    }

    private func judgmentButton(value: Int, symbol: String, tint: Color) -> some View {
        Button { judge(value) } label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(tint, in: Circle())
                .shadow(color: tint.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value > 0 ? "Like" : "Dislike")
    }
```

- [ ] **Step 2: Auto-play + loop + judge**

Replace the existing `judge(_:)` with:

```swift
    private func judge(_ value: Int) {
        Haptics.tap()
        deck.judge(value)
        if let next = deck.current {
            Task { await player.toggle(next) }   // different entry → starts fresh
        } else {
            read = StartingRead.from(picks: deck.picks)
            SeedRatings.save(deck.picks)   // seed the real taste mirror
            Task { await player.stop() }
            phase = .reveal
        }
    }
```

Update the `reveal` computed property's first line to use the deck:

```swift
        let profile = TasteMirror.build(from: deck.picks).archetype ?? .theShapeshifter
```

In the body, after the existing `.animation(...)` modifiers, add the auto-play kickoff and the loop:

```swift
        .onChange(of: phase) { _, newPhase in
            // Begin tapped → rating starts → first preview auto-plays. The Begin
            // tap is the consenting user gesture for audio.
            guard newPhase == .rating, let song = deck.current else { return }
            Task { await player.toggle(song) }
        }
        .onChange(of: player.state) { _, newState in
            // Loop: a finished preview restarts until the user swipes.
            guard phase == .rating, newState == .finished,
                  let song = deck.current, player.nowPlayingEntryID == song.id else { return }
            Task { await player.toggle(song) }   // toggle from .finished replays fresh
        }
```

Note the `index`-keyed animation: change `value: index` to `value: deck.index` (done in Step 1) — double-check it compiles.

- [ ] **Step 3: Copy changes (intro + reveal)**

In `intro`, replace the explainer `Text`:

```swift
            Text("Songs will play out loud — headphones on 🎧. Swipe right if you're into it, left if not. This seeds your taste profile; it grows from your daily songs after.")
```

In `reveal`, replace the button label `Text("Continue")` with:

```swift
                Text("Hear today's song").frame(maxWidth: .infinity)
```

Also update the file's header comment (lines 5–9) to describe the new flow: auto-playing swipe deck → reveal → straight into today's ceremony.

- [ ] **Step 4: Build**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run the full TasteSeed + Playback suites (regression check)**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests/TasteSeedTests" -only-testing:"Daily MusicTests/PlaybackTests" 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Views/Onboarding/TasteSeedView.swift"
git commit -m "feat(onboarding): taste seed rides the swipe deck — auto-playing, looping previews"
```

---

### Task 7: Finale wiring — straight into the ceremony

`launchIntoCeremony` flag on `AppEnvironment`; set on taste-seed completion; consumed by `TodayView` to open the ceremony with zero delay.

**Files:**
- Modify: `Daily Music/App/AppEnvironment.swift` (add one stored property)
- Modify: `Daily Music/Views/Onboarding/OnboardingView.swift:64-77` (the taste-seed fullScreenCover)
- Modify: `Daily Music/Views/TodayView.swift:113-125` (the auto-open onChange)

- [ ] **Step 1: Add the flag to AppEnvironment**

In `AppEnvironment`, after the `let catchUpLog: CatchUpLog` property:

```swift
    /// Day-one handoff: set when the taste-seed reveal completes so TodayView
    /// raises the first ceremony immediately (no settle beat). One-shot —
    /// TodayView clears it after consuming.
    var launchIntoCeremony = false
```

(It's `@Observable`; a stored `var` with a default needs no `init` change.)

- [ ] **Step 2: Set it when the taste seed completes**

In `OnboardingView`'s `.fullScreenCover(isPresented: $showingTasteSeed)`, the `onComplete` closure — add one line before `advance()`:

```swift
            TasteSeedView(displayName: displayName) { read in
                startingMood = read.mood ?? ""
                startingGenre = read.genre ?? ""
                startingDecade = read.decade ?? ""
                tasteSeedDone = true
                showingTasteSeed = false
                env.launchIntoCeremony = true   // reveal's button promised today's song
                advance()
            } onSkip: {
```

(The `onSkip` closure stays unchanged — skipping the seed gets the normal delayed ceremony.)

- [ ] **Step 3: Consume it in TodayView**

Replace the body of `.onChange(of: loadedEntry?.id)` (currently the `0.6`-second sleep block):

```swift
            .onChange(of: loadedEntry?.id) { _, _ in
                guard let entry = loadedEntry else { return }
                let heard = heardEntryID.isEmpty ? nil : heardEntryID
                guard ListeningCeremony.shouldAutoOpen(todayEntryID: entry.id, heardEntryID: heard) else { return }
                // Normally Today settles for a beat before the ceremony rises; on
                // day one (straight from the onboarding reveal) the beat is zero
                // so the arc — rate songs → archetype → first song — is unbroken.
                let fromOnboarding = env.launchIntoCeremony
                env.launchIntoCeremony = false
                listeningIsCeremony = true
                Task {
                    try? await Task.sleep(for: ListeningCeremony.autoOpenDelay(launchingFromOnboarding: fromOnboarding))
                    guard loadedEntry?.id == entry.id else { return }
                    showingListening = true
                }
            }
```

- [ ] **Step 4: Build and run the full test suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/App/AppEnvironment.swift" "Daily Music/Views/Onboarding/OnboardingView.swift" "Daily Music/Views/TodayView.swift"
git commit -m "feat(onboarding): reveal hands off straight into today's first ceremony"
```

---

### Task 8: Manual verification + docs

**Files:**
- Modify: `docs/ARCHITECTURE.md` (taste-seed + ceremony sections)

- [ ] **Step 1: Manual simulator pass**

Launch in the simulator (mock services/PreviewMusicEngine make onboarding fully explorable). Reset onboarding state first if needed (delete the app from the simulator). Verify:

1. Intro warns audio will play; **Begin** starts the first preview automatically.
2. Cards swipe: badge fades in, past-threshold fling advances + next preview starts; under-threshold springs back.
3. Letting the (6s mock) preview end loops it.
4. Tap art pauses/resumes; thumbs buttons still judge.
5. Skip stops audio.
6. Reveal button reads "Hear today's song"; tapping it lands in the ceremony with no perceptible tab-bar dwell.
7. Settings → toggle Reduce Motion in simulator (Accessibility) → judging crossfades instead of flinging.
8. Kill + relaunch after onboarding: ceremony uses the normal delayed rise (flag was cleared).

- [ ] **Step 2: Update ARCHITECTURE.md**

Per the standing project rule, update `docs/ARCHITECTURE.md`: the onboarding section (TasteSeedView → TasteSeedDeck + TasteSeedCardStack, auto-play/loop via MusicPlayer) and the Today section (`launchIntoCeremony` one-shot flag, `ListeningCeremony.autoOpenDelay`).

- [ ] **Step 3: Final commit**

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs: architecture map for onboarding swipe deck + ceremony handoff"
```

---

## Self-review notes

- **Spec coverage:** card stack (Tasks 2, 5, 6), auto-play + loop (Tasks 3, 6), finale (Tasks 4, 7), accessibility fallbacks (Tasks 5, 6), testing strategy (Tasks 1–4, 8). Future work intentionally untouched.
- **No new test files** — all tests land in existing `TasteSeedTests.swift` / `PlaybackTests.swift` (test target isn't file-system-synced; new files would need pbxproj surgery).
- **Type consistency:** `TasteSeedDeck.judge(_:)` / `upcoming` / `positionText` / `isComplete` are used identically in Tasks 2, 5, 6; `ListeningCeremony.autoOpenDelay(launchingFromOnboarding:)` matches Tasks 4 and 7.
