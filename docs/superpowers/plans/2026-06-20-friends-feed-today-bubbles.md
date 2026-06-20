# Friends Feed + Today Social Bubbles — Implementation Plan (Phase 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Friends tab as an art-directed activity feed and add floating friend-reaction bubbles to the Today hero — both powered entirely by the already-live `friend_ratings` data, with zero backend changes.

**Architecture:** A new pure engine (`FriendActivityFeed`) turns per-friend rating maps + entry history into feed items, today-reactions, and taste-match percents. A `@MainActor @Observable` `FriendsActivityStore` on `AppEnvironment` fetches the raw data and exposes the derived outputs. The Friends tab and Today both read this one store. Friends' badges/streaks are explicitly Phase 2 and out of scope here.

**Tech Stack:** Swift 6 / SwiftUI, `@Observable` stores, Swift Testing (`import Testing`, `@Test`, `#expect`), Supabase RPC services behind protocols (mocked in tests).

**Spec:** `docs/superpowers/specs/2026-06-20-friends-feed-today-bubbles-design.md`

---

## Build & Test Commands

Build (simulator):
```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
```

Test:
```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

> **CRITICAL — test-file registration:** The **app target** (`Daily Music/`) uses an Xcode-16 file-system-synchronized group, so new files under `Daily Music/` compile automatically. The **test target** (`Daily MusicTests/`) does NOT — every **new test file** must be added to the target via Xcode (updates `project.pbxproj`) before `xcodebuild test` will see it. Each task that creates a new test file calls this out.

---

## File Structure

**Create:**
- `Daily Music/Models/FriendActivity.swift` — pure types (`Verdict`, `FriendReaction`, `FriendActivityItem`) + the `FriendActivityFeed` engine (recent-drop items, today-reactions, match percents).
- `Daily Music/Models/FriendReactionBubbleLogic.swift` — pure `BubbleLayout.split` (cap + overflow) and `FriendBubbleReveal.shouldShow` predicate.
- `Daily Music/ViewModels/FriendsActivityStore.swift` — `@MainActor @Observable` store assembling the engine outputs from the live services.
- `Daily Music/Views/Components/FriendReactionBubbles.swift` — the Today floating-bubbles overlay view.
- `Daily Music/Views/Friends/FriendActivityRow.swift` — one feed row.
- `Daily MusicTests/FriendActivityFeedTests.swift` — engine + bubble-logic tests.
- `Daily MusicTests/FriendsActivityStoreTests.swift` — store assembly test.

**Modify:**
- `Daily Music/App/AppEnvironment.swift` — add `friendsActivityStore` property + init wiring.
- `Daily Music/Views/EntryDetailImmersive.swift:155-167` — overlay bubbles on the Today sleeve.
- `Daily Music/Views/TodayView.swift` — load the activity store on appear.
- `Daily Music/Views/Friends/FriendsView.swift` — restyle into the feed (wash background, invite card, activity feed, match bars), preserving requests/nudge/swipe-to-remove.

**Scope note:** The Phase-1 feed contains **loved/passed on recent drops only**. Taste-match info is surfaced on the friends-list rows (a % bar), so a separate "taste-match" feed item is intentionally omitted (YAGNI). Friends' badges/streaks are Phase 2.

---

## Task 1: Pure activity-feed engine

**Files:**
- Create: `Daily Music/Models/FriendActivity.swift`
- Test: `Daily MusicTests/FriendActivityFeedTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Daily MusicTests/FriendActivityFeedTests.swift`:

```swift
import Testing
import Foundation
@testable import Daily_Music

struct FriendActivityFeedTests {
    // Two friends, three entries (e0 newest … e2 oldest).
    private func fixture() -> (friends: [Friend], history: [DailyEntry], byFriend: [UUID: [UUID: Int]]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func entry(_ i: Int) -> DailyEntry {
            DailyEntry(
                id: MockEntryService.mockEntryID(i),
                date: cal.date(byAdding: .day, value: -i, to: today)!,
                title: "Song \(i)", artist: "Artist \(i)",
                albumArtURL: nil, journalMarkdown: "", appleMusicID: "", spotifyURI: ""
                // genre…language default to nil
            )
        }
        let alex = Friend(friendshipID: UUID(), profile: UserProfile(id: UUID(), displayName: "Alex", avatarURL: nil))
        let sam  = Friend(friendshipID: UUID(), profile: UserProfile(id: UUID(), displayName: "Sam", avatarURL: nil))
        let history = [entry(0), entry(1), entry(2)]
        let byFriend: [UUID: [UUID: Int]] = [
            alex.profile.id: [MockEntryService.mockEntryID(0): 1,  MockEntryService.mockEntryID(2): -1],
            sam.profile.id:  [MockEntryService.mockEntryID(0): -1]
        ]
        return ([alex, sam], history, byFriend)
    }

    @Test func recentDropItemsBuildsLovedAndPassed() {
        let f = fixture()
        let items = FriendActivityFeed.recentDropItems(
            friends: f.friends, ratingsByFriend: f.byFriend, history: f.history, window: 5)
        // Alex: loved e0, passed e2. Sam: passed e0. → 3 items, newest entry first.
        #expect(items.count == 3)
        #expect(items.first?.entry.id == MockEntryService.mockEntryID(0))
        #expect(items.allSatisfy { $0.entry.date >= items.last!.entry.date })
        let alexLoved = items.first { $0.friend.displayName == "Alex" && $0.entry.id == MockEntryService.mockEntryID(0) }
        #expect(alexLoved?.verdict == .loved)
    }

    @Test func windowLimitsHowFarBack() {
        let f = fixture()
        let items = FriendActivityFeed.recentDropItems(
            friends: f.friends, ratingsByFriend: f.byFriend, history: f.history, window: 1)
        // Only e0 is in-window → Alex loved + Sam passed = 2 items.
        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.entry.id == MockEntryService.mockEntryID(0) })
    }

    @Test func todayReactionsFilterToTheGivenEntry() {
        let f = fixture()
        let reactions = FriendActivityFeed.todayReactions(
            friends: f.friends, ratingsByFriend: f.byFriend, todayEntryID: MockEntryService.mockEntryID(0))
        #expect(reactions.count == 2)
        #expect(reactions.first { $0.friend.displayName == "Alex" }?.verdict == .loved)
        #expect(reactions.first { $0.friend.displayName == "Sam" }?.verdict == .passed)
    }

    @Test func todayReactionsEmptyWhenNoTodayEntry() {
        let f = fixture()
        #expect(FriendActivityFeed.todayReactions(
            friends: f.friends, ratingsByFriend: f.byFriend, todayEntryID: nil).isEmpty)
    }

    @Test func matchPercentsOmitFriendsBelowThreshold() {
        let f = fixture()
        // mine agrees with Alex on e0 (both like) but only 2 co-rated < minShared(3) → nil/omitted.
        let mine: [UUID: Int] = [MockEntryService.mockEntryID(0): 1, MockEntryService.mockEntryID(2): 1]
        let pcts = FriendActivityFeed.matchPercents(
            friends: f.friends, ratingsByFriend: f.byFriend, mine: mine, history: f.history)
        // Alex co-rated 2 (e0,e2) < 3 → omitted; Sam co-rated 1 → omitted.
        #expect(pcts.isEmpty)
    }
}
```

- [ ] **Step 2: Register the new test file in Xcode**

Open the project in Xcode and add `Daily MusicTests/FriendActivityFeedTests.swift` to the `Daily MusicTests` target (it won't compile via CLI until `project.pbxproj` references it).

- [ ] **Step 3: Run tests to verify they fail**

Run the test command above.
Expected: FAIL — `cannot find 'FriendActivityFeed' in scope` (and the new types).

- [ ] **Step 4: Write the engine**

Create `Daily Music/Models/FriendActivity.swift`:

```swift
//
//  FriendActivity.swift
//  Daily Music
//
//  Pure engine + value types for the Friends activity feed and the Today
//  reaction bubbles. Turns per-friend rating maps (from friend_ratings) into
//  loved/passed items, today's reactions, and taste-match percents. No I/O —
//  the FriendsActivityStore feeds it live data; tests feed it fixtures.
//

import Foundation

/// A friend's verdict on a song, derived from their +1 / -1 rating.
enum Verdict: Equatable {
    case loved   // rating > 0
    case passed  // rating < 0

    /// Build from a raw rating value; nil for 0 / missing.
    init?(rating: Int) {
        if rating > 0 { self = .loved }
        else if rating < 0 { self = .passed }
        else { return nil }
    }

    var emoji: String { self == .loved ? "❤️" : "👎" }

    /// Verb used in feed copy: "loved today's drop" / "passed on today's drop".
    var feedVerb: String { self == .loved ? "loved" : "passed on" }
}

/// A friend's reaction to a single song — used by the Today bubbles.
struct FriendReaction: Identifiable, Equatable {
    let friend: UserProfile
    let verdict: Verdict
    var id: UUID { friend.id }
}

/// One row in the activity feed: a friend loved/passed a specific drop.
struct FriendActivityItem: Identifiable, Equatable {
    let id: String
    let friend: UserProfile
    let verdict: Verdict
    let entry: DailyEntry
}

/// Pure builders. All inputs are plain values so every output is unit-testable.
enum FriendActivityFeed {

    /// Loved/passed items across the most recent `window` drops, newest entry
    /// first. Friends with no (or a 0) rating on an entry contribute nothing.
    static func recentDropItems(
        friends: [Friend],
        ratingsByFriend: [UUID: [UUID: Int]],
        history: [DailyEntry],
        window: Int
    ) -> [FriendActivityItem] {
        let recent = Array(history.prefix(max(0, window)))
        var items: [FriendActivityItem] = []
        for entry in recent {
            for friend in friends {
                guard let raw = ratingsByFriend[friend.profile.id]?[entry.id],
                      let verdict = Verdict(rating: raw) else { continue }
                items.append(FriendActivityItem(
                    id: "\(friend.profile.id.uuidString)-\(entry.id.uuidString)",
                    friend: friend.profile,
                    verdict: verdict,
                    entry: entry))
            }
        }
        return items.sorted { $0.entry.date > $1.entry.date }
    }

    /// Friends' verdicts on a single entry (today's drop). Empty when the id is nil.
    static func todayReactions(
        friends: [Friend],
        ratingsByFriend: [UUID: [UUID: Int]],
        todayEntryID: UUID?
    ) -> [FriendReaction] {
        guard let todayEntryID else { return [] }
        return friends.compactMap { friend in
            guard let raw = ratingsByFriend[friend.profile.id]?[todayEntryID],
                  let verdict = Verdict(rating: raw) else { return nil }
            return FriendReaction(friend: friend.profile, verdict: verdict)
        }
    }

    /// Taste-match percent per friend, reusing TasteComparison. Friends below the
    /// minimum shared-ratings threshold are omitted (no meaningful %).
    static func matchPercents(
        friends: [Friend],
        ratingsByFriend: [UUID: [UUID: Int]],
        mine: [UUID: Int],
        history: [DailyEntry]
    ) -> [UUID: Int] {
        var out: [UUID: Int] = [:]
        for friend in friends {
            let theirs = ratingsByFriend[friend.profile.id] ?? [:]
            if let pct = TasteComparison.build(mine: mine, theirs: theirs, history: history).matchPercent {
                out[friend.profile.id] = pct
            }
        }
        return out
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run the test command.
Expected: PASS — all 5 `FriendActivityFeedTests`.

- [ ] **Step 6: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Models/FriendActivity.swift" "Daily MusicTests/FriendActivityFeedTests.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "feat: pure FriendActivityFeed engine for friends feed + Today bubbles"
```

---

## Task 2: Bubble cap + reveal logic

**Files:**
- Create: `Daily Music/Models/FriendReactionBubbleLogic.swift`
- Test: append to `Daily MusicTests/FriendActivityFeedTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `Daily MusicTests/FriendActivityFeedTests.swift`:

```swift
struct FriendReactionBubbleLogicTests {
    private func reaction(_ name: String, _ v: Verdict) -> FriendReaction {
        FriendReaction(friend: UserProfile(id: UUID(), displayName: name, avatarURL: nil), verdict: v)
    }

    @Test func splitShowsAllWhenUnderCap() {
        let r = [reaction("A", .loved), reaction("B", .passed)]
        let s = BubbleLayout.split(r, maxVisible: 4)
        #expect(s.shown.count == 2)
        #expect(s.overflow == 0)
    }

    @Test func splitCapsAndCountsOverflow() {
        let r = (0..<7).map { reaction("F\($0)", .loved) }
        let s = BubbleLayout.split(r, maxVisible: 4)
        #expect(s.shown.count == 4)
        #expect(s.overflow == 3)
    }

    @Test func revealRequiresTodayListenedAndReactions() {
        #expect(FriendBubbleReveal.shouldShow(isToday: true,  hasListenedOrRated: true,  hasReactions: true))
        #expect(!FriendBubbleReveal.shouldShow(isToday: false, hasListenedOrRated: true,  hasReactions: true))
        #expect(!FriendBubbleReveal.shouldShow(isToday: true,  hasListenedOrRated: false, hasReactions: true))
        #expect(!FriendBubbleReveal.shouldShow(isToday: true,  hasListenedOrRated: true,  hasReactions: false))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the test command.
Expected: FAIL — `cannot find 'BubbleLayout'` / `'FriendBubbleReveal'` in scope.

- [ ] **Step 3: Write the logic**

Create `Daily Music/Models/FriendReactionBubbleLogic.swift`:

```swift
//
//  FriendReactionBubbleLogic.swift
//  Daily Music
//
//  Pure helpers for the Today reaction bubbles: how many to show vs collapse,
//  and whether the bubbles may appear at all. Kept separate from the view so the
//  rules are unit-tested without rendering.
//

import Foundation

enum BubbleLayout {
    /// Cap the visible bubbles; the rest fold into an overflow count.
    static func split(_ reactions: [FriendReaction], maxVisible: Int)
        -> (shown: [FriendReaction], overflow: Int) {
        guard reactions.count > maxVisible else { return (reactions, 0) }
        return (Array(reactions.prefix(maxVisible)), reactions.count - maxVisible)
    }
}

enum FriendBubbleReveal {
    /// Bubbles show only on Today, only after the user engaged (listened or
    /// rated), and only when at least one friend has reacted — so they land as a
    /// payoff and never bias the user's own rating.
    static func shouldShow(isToday: Bool, hasListenedOrRated: Bool, hasReactions: Bool) -> Bool {
        isToday && hasListenedOrRated && hasReactions
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the test command.
Expected: PASS — all 3 `FriendReactionBubbleLogicTests`.

- [ ] **Step 5: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Models/FriendReactionBubbleLogic.swift" "Daily MusicTests/FriendActivityFeedTests.swift"
git commit -m "feat: bubble cap + reveal-gating logic for Today reaction bubbles"
```

---

## Task 3: FriendsActivityStore + AppEnvironment wiring

**Files:**
- Create: `Daily Music/ViewModels/FriendsActivityStore.swift`
- Modify: `Daily Music/App/AppEnvironment.swift:46-48` (add property) and `:125-135` (init)
- Test: `Daily MusicTests/FriendsActivityStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Daily MusicTests/FriendsActivityStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct FriendsActivityStoreTests {
    @Test func loadAssemblesReactionsItemsAndMatch() async throws {
        // Use one shared MockFriendService so the store sees the same Alex id
        // (and seeded ratings) the test inspects.
        let friendSvc = MockFriendService()
        let alex = try await friendSvc.friends()[0].profile

        let store = FriendsActivityStore(
            friends: friendSvc,
            entries: MockEntryService(),
            ratings: MockRatingService())

        await store.load()

        // MockEntryService entry 0 is today; MockFriendService seeds Alex's
        // rating on entry 0 as +1 → a "loved" reaction on today's drop.
        #expect(store.todayReactions.contains { $0.friend.id == alex.id && $0.verdict == .loved })
        // Recent window covers today + prior drops Alex has rated → non-empty feed.
        #expect(!store.items.isEmpty)
        // Alex and the seeded "me" share well over minShared ratings → a % exists.
        #expect(store.matchByFriend[alex.id] != nil)
    }

    @Test func loadIsResilientToEmptyFriends() async {
        // A friend service with no friends/ratings yields empty, not a crash.
        let store = FriendsActivityStore(
            friends: EmptyFriendService(),
            entries: MockEntryService(),
            ratings: MockRatingService())
        await store.load()
        #expect(store.items.isEmpty)
        #expect(store.todayReactions.isEmpty)
        #expect(store.matchByFriend.isEmpty)
    }
}

/// A FriendService with no social graph, for the empty-state path.
private actor EmptyFriendService: FriendService {
    func myCode() async throws -> String { "ABCDEF" }
    func friends() async throws -> [Friend] { [] }
    func incomingRequests() async throws -> [FriendRequest] { [] }
    func sendRequest(code: String) async throws {}
    func respond(requestID: UUID, accept: Bool) async throws {}
    func remove(friendshipID: UUID) async throws {}
    func friendRatings(friendID: UUID) async throws -> [UUID: Int] { [:] }
}
```

- [ ] **Step 2: Register the new test file in Xcode**

Add `Daily MusicTests/FriendsActivityStoreTests.swift` to the `Daily MusicTests` target in Xcode.

- [ ] **Step 3: Run test to verify it fails**

Run the test command.
Expected: FAIL — `cannot find 'FriendsActivityStore' in scope`.

- [ ] **Step 4: Write the store**

Create `Daily Music/ViewModels/FriendsActivityStore.swift`:

```swift
//
//  FriendsActivityStore.swift
//  Daily Music
//
//  Assembles the Friends activity feed and the Today reaction bubbles from live
//  data: each friend's ratings (friend_ratings RPC), the published entry
//  history, and the user's own ratings. Pure assembly lives in
//  FriendActivityFeed; this store just fetches and caches the derived outputs so
//  the Friends tab and Today both read one consistent source. Best-effort: any
//  failed fetch degrades to empty rather than erroring.
//

import Foundation

@MainActor
@Observable
final class FriendsActivityStore {
    /// Loved/passed on recent drops, newest first — drives the activity feed.
    private(set) var items: [FriendActivityItem] = []
    /// Friends' verdicts on today's drop — drives the Today bubbles.
    private(set) var todayReactions: [FriendReaction] = []
    /// Taste-match percent per friend id — drives the friends-list bars.
    private(set) var matchByFriend: [UUID: Int] = [:]

    /// How many recent drops the feed looks back over.
    private let window = 5

    private let friends: FriendService
    private let entries: EntryService
    private let ratings: RatingService

    init(friends: FriendService, entries: EntryService, ratings: RatingService) {
        self.friends = friends
        self.entries = entries
        self.ratings = ratings
    }

    func load() async {
        let roster = (try? await friends.friends()) ?? []
        let history = (try? await entries.publishedHistory()) ?? []
        let mine = (try? await ratings.myRatings()) ?? [:]

        var byFriend: [UUID: [UUID: Int]] = [:]
        for friend in roster {
            byFriend[friend.profile.id] = (try? await friends.friendRatings(friendID: friend.profile.id)) ?? [:]
        }

        let todayEntryID = history.first { Calendar.current.isDateInToday($0.date) }?.id

        items = FriendActivityFeed.recentDropItems(
            friends: roster, ratingsByFriend: byFriend, history: history, window: window)
        todayReactions = FriendActivityFeed.todayReactions(
            friends: roster, ratingsByFriend: byFriend, todayEntryID: todayEntryID)
        matchByFriend = FriendActivityFeed.matchPercents(
            friends: roster, ratingsByFriend: byFriend, mine: mine, history: history)
    }
}
```

- [ ] **Step 5: Wire it onto AppEnvironment**

In `Daily Music/App/AppEnvironment.swift`, add the stored property after `friendsStore` (around line 46):

```swift
    let friendsStore: FriendsStore
    let friendsActivityStore: FriendsActivityStore
```

And in `init(...)`, immediately after `self.friendsStore = FriendsStore(service: friends)` (around line 125):

```swift
        self.friendsStore = FriendsStore(service: friends)
        self.friendsActivityStore = FriendsActivityStore(
            friends: friends, entries: entries, ratings: ratings)
```

(No factory-method changes needed — both `mock()` and `live()` already pass `friends`, `entries`, `ratings` into `init`.)

- [ ] **Step 6: Run test to verify it passes**

Run the test command.
Expected: PASS — both `FriendsActivityStoreTests`.

- [ ] **Step 7: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/ViewModels/FriendsActivityStore.swift" "Daily Music/App/AppEnvironment.swift" "Daily MusicTests/FriendsActivityStoreTests.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "feat: FriendsActivityStore on AppEnvironment, assembling feed + bubbles + match"
```

---

## Task 4: FriendReactionBubbles view (Today)

**Files:**
- Create: `Daily Music/Views/Components/FriendReactionBubbles.swift`

View assembly — verified by build (logic is already unit-tested in Task 2).

- [ ] **Step 1: Write the view**

Create `Daily Music/Views/Components/FriendReactionBubbles.swift`:

```swift
//
//  FriendReactionBubbles.swift
//  Daily Music
//
//  Floating friend-reaction bubbles pinned around the Today sleeve. Each bubble
//  is a friend avatar + their verdict emoji (❤️ loved / 👎 passed). Caps at a few
//  visible bubbles with a "+N" overflow so it never clutters the hero. Intended
//  to be placed in an overlay sized to the cover; see EntryDetailImmersive.
//

import SwiftUI

struct FriendReactionBubbles: View {
    let reactions: [FriendReaction]
    var maxVisible = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    // Anchor each bubble to a corner of the cover, nudged slightly outward.
    private let anchors: [(Alignment, CGSize)] = [
        (.topTrailing,   CGSize(width: 14,  height: -12)),
        (.bottomLeading, CGSize(width: -16, height: 14)),
        (.bottomTrailing,CGSize(width: 12,  height: 18)),
        (.topLeading,    CGSize(width: -12, height: -10))
    ]

    var body: some View {
        let split = BubbleLayout.split(reactions, maxVisible: maxVisible)
        ZStack {
            ForEach(Array(split.shown.enumerated()), id: \.element.id) { index, reaction in
                let anchor = anchors[index % anchors.count]
                bubble(reaction)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: anchor.0)
                    .offset(anchor.1)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        reduceMotion ? nil
                        : .spring(response: 0.45, dampingFraction: 0.6)
                            .delay(0.06 * Double(index)),
                        value: appeared)
            }

            if split.overflow > 0 {
                overflowBubble(split.overflow)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: 26)
                    .opacity(appeared ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut.delay(0.28), value: appeared)
            }
        }
        .allowsHitTesting(false)
        .onAppear { appeared = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(split))
    }

    private func bubble(_ reaction: FriendReaction) -> some View {
        HStack(spacing: 5) {
            InitialsAvatar(name: reaction.friend.displayName, size: 26)
            Text(reaction.verdict.emoji).font(.system(size: 13))
        }
        .padding(3)
        .padding(.trailing, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    private func overflowBubble(_ count: Int) -> some View {
        Text("+\(count)")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    private func accessibilitySummary(_ split: (shown: [FriendReaction], overflow: Int)) -> String {
        let parts = split.shown.map { "\($0.friend.displayName ?? "A friend") \($0.verdict.feedVerb) this" }
        let extra = split.overflow > 0 ? " and \(split.overflow) more" : ""
        return parts.joined(separator: ", ") + extra
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command.
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Views/Components/FriendReactionBubbles.swift"
git commit -m "feat: FriendReactionBubbles floating overlay for Today"
```

---

## Task 5: Integrate bubbles into Today

**Files:**
- Modify: `Daily Music/Views/EntryDetailImmersive.swift:158-167` (overlay the sleeve)
- Modify: `Daily Music/Views/TodayView.swift` (load the store on appear)

View integration — verified by build + manual run.

- [ ] **Step 1: Overlay the bubbles on the Today sleeve**

In `Daily Music/Views/EntryDetailImmersive.swift`, the `songZone` renders the Today cover as `SleeveView` (the `if onRequestListen != nil` branch). Replace that `SleeveView(...)` block:

```swift
                SleeveView(
                    entry: entry,
                    status: env.listensStore.status(for: entry),
                    size: coverSleeveSize
                )
                .frame(maxWidth: .infinity)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7),
                    value: env.listensStore.status(for: entry).indicatorColor
                )
```

with the same thing wrapped in an overlay:

```swift
                SleeveView(
                    entry: entry,
                    status: env.listensStore.status(for: entry),
                    size: coverSleeveSize
                )
                .frame(maxWidth: .infinity)
                .overlay(alignment: .center) {
                    if FriendBubbleReveal.shouldShow(
                        isToday: onRequestListen != nil,
                        hasListenedOrRated: env.listensStore.isHeard(entry),
                        hasReactions: !env.friendsActivityStore.todayReactions.isEmpty
                    ) {
                        FriendReactionBubbles(reactions: env.friendsActivityStore.todayReactions)
                            .frame(width: coverSleeveSize, height: coverSleeveSize)
                            .transition(.opacity)
                    }
                }
                .animation(
                    reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7),
                    value: env.listensStore.status(for: entry).indicatorColor
                )
```

(The `isToday: onRequestListen != nil` check guarantees Vault/Favorites — which never pass `onRequestListen` — never show bubbles.)

- [ ] **Step 2: Load the activity store from Today**

In `Daily Music/Views/TodayView.swift`, find the main `.task` that builds and loads the model (around line 130, `if model == nil { … }; await model?.load()`). Add a load of the activity store at the end of that same `.task` closure, after `evaluateNewDropPrompt()`:

```swift
                await model?.load()
                evaluateNewDropPrompt()
                await env.friendsActivityStore.load()
```

- [ ] **Step 3: Build to verify it compiles**

Run the build command.
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual check (mock environment)**

Run the app in the simulator (mock environment seeds Alex's ratings). On Today:
- Before listening: **no** bubbles on the cover.
- After pulling down to listen past the threshold (or once today's song is collected): an ❤️ bubble for Alex animates in around the cover.

- [ ] **Step 5: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Views/EntryDetailImmersive.swift" "Daily Music/Views/TodayView.swift"
git commit -m "feat: reveal friend reaction bubbles on Today after listen/rate"
```

---

## Task 6: FriendActivityRow view

**Files:**
- Create: `Daily Music/Views/Friends/FriendActivityRow.swift`

View assembly — verified by build.

- [ ] **Step 1: Write the row**

Create `Daily Music/Views/Friends/FriendActivityRow.swift`:

```swift
//
//  FriendActivityRow.swift
//  Daily Music
//
//  One row in the Friends activity feed: "{name} loved/passed on {song}" with
//  the cover and a verdict bubble, in the same visual language as the Today
//  bubbles so the two surfaces feel like one feature.
//

import SwiftUI

struct FriendActivityRow: View {
    let item: FriendActivityItem
    var onOpenEntry: (DailyEntry) -> Void = { _ in }

    var body: some View {
        Button { onOpenEntry(item.entry) } label: {
            HStack(spacing: Theme.Spacing.sm) {
                InitialsAvatar(name: item.friend.displayName, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(item.entry.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Theme.Spacing.sm)

                Text(item.verdict.emoji).font(.body)
                AlbumArtView(url: item.entry.albumArtURL, cornerRadius: Theme.Radius.chip)
                    .frame(width: 40, height: 40)
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                    .stroke(Theme.Surface.cardStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.friend.displayName ?? "A friend") \(item.verdict.feedVerb) \(item.entry.title)")
    }

    private var headline: String {
        let name = item.friend.displayName ?? "A friend"
        return "\(name) \(item.verdict.feedVerb) this"
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command.
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Views/Friends/FriendActivityRow.swift"
git commit -m "feat: FriendActivityRow for the Friends activity feed"
```

---

## Task 7: Friends tab redesign

**Files:**
- Modify: `Daily Music/Views/Friends/FriendsView.swift` (full restyle)

Redesign the tab into the feed: a gradient wash behind a plain List with clear
rows (preserves `swipeActions` + keyboard handling), a styled invite card, the
activity feed, and taste-match bars on friend rows. Verified by build + manual.

- [ ] **Step 1: Rewrite FriendsView**

Replace the entire contents of `Daily Music/Views/Friends/FriendsView.swift`:

```swift
//  FriendsView.swift — the Friends tab: an art-directed activity feed.
//  A gradient wash sits behind a plain List with clear rows, so the screen
//  matches the rest of the app while keeping swipe-to-remove + keyboard handling.
//  Zones: invite card → activity feed (friends loved/passed recent drops) →
//  requests → friends (with taste-match bars). Friends' badges/streaks are Phase 2.
import SwiftUI

struct FriendsView: View {
    @Environment(AppEnvironment.self) private var env
    var onOpenEntry: (DailyEntry) -> Void = { _ in }

    @State private var enteredCode = ""
    @State private var sendError: String?
    @FocusState private var isFriendCodeFocused: Bool

    private var store: FriendsStore { env.friendsStore }
    private var activity: FriendsActivityStore { env.friendsActivityStore }

    private var friendLink: String { "dailymusic://friend/\(store.myCode)" }

    var body: some View {
        NavigationStack {
            List {
                inviteSection
                if !activity.items.isEmpty { activitySection }
                if !store.requests.isEmpty { requestsSection }
                friendsSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(wash)
            .navigationTitle("Friends")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isFriendCodeFocused = false }
                }
            }
            .task {
                await store.load()
                await activity.load()
                if let pending = UserDefaults.standard.string(forKey: "pendingFriendCode") {
                    enteredCode = FriendCode.normalize(pending)
                    UserDefaults.standard.removeObject(forKey: "pendingFriendCode")
                }
            }
            .refreshable {
                await store.load()
                await activity.load()
            }
        }
    }

    // Clear-background row helper so every section reads as floating cards on the wash.
    private func clearRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    // MARK: invite

    private var inviteSection: some View {
        Section {
            clearRow {
                VStack(spacing: Theme.Spacing.md) {
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
                                .font(.subheadline.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack {
                        TextField("Enter a 6-character code", text: $enteredCode)
                            .keyboardType(.asciiCapable)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isFriendCodeFocused)
                            .onChange(of: enteredCode) { _, newValue in
                                let cleaned = String(FriendCode.normalize(newValue).prefix(6))
                                if cleaned != newValue { enteredCode = cleaned }
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
                    }
                    if let sendError {
                        Text(sendError).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(Theme.Surface.cardStroke, lineWidth: 1)
                }
            }
        }
    }

    // MARK: activity feed

    private var activitySection: some View {
        Section {
            ForEach(activity.items) { item in
                clearRow {
                    FriendActivityRow(item: item, onOpenEntry: onOpenEntry)
                }
            }
        } header: {
            sectionHeader("Activity")
        }
    }

    // MARK: requests

    private var requestsSection: some View {
        Section {
            ForEach(store.requests) { request in
                clearRow {
                    HStack(spacing: 12) {
                        avatar(request.profile)
                        Text(request.profile.displayName ?? "New friend").font(.headline)
                        Spacer()
                        Button { Task { await store.respond(request, accept: true) } } label: {
                            Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                        }.buttonStyle(.plain)
                        Button { Task { await store.respond(request, accept: false) } } label: {
                            Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                        }.buttonStyle(.plain)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
                }
            }
        } header: {
            sectionHeader("Requests")
        }
    }

    // MARK: friends

    private var friendsSection: some View {
        Section {
            if store.friends.isEmpty {
                clearRow {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No friends yet").font(.headline)
                        Text("Share your invite to start comparing taste mirrors.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ShareLink(item: friendLink) {
                            Label("Share invite", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
            } else {
                ForEach(store.friends) { friend in
                    clearRow {
                        HStack(spacing: 12) {
                            NavigationLink {
                                FriendInsightsView(friend: friend, onOpenEntry: onOpenEntry)
                            } label: {
                                friendRowLabel(friend)
                            }
                            nudgeButton(friend)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) { Task { await store.remove(friend) } }
                    }
                }
            }
        } header: {
            sectionHeader("Your friends")
        }
    }

    private func friendRowLabel(_ friend: Friend) -> some View {
        HStack(spacing: 12) {
            avatar(friend.profile, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.profile.displayName ?? "Friend").font(.headline)
                if let pct = activity.matchByFriend[friend.profile.id] {
                    matchBar(pct)
                } else {
                    Text("Open their taste mirror")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func matchBar(_ pct: Int) -> some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Surface.subtleTrack)
                    Capsule()
                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(pct) / 100)
                }
            }
            .frame(height: 7)
            Text("\(pct)%")
                .font(.caption.weight(.bold)).monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("\(pct) percent taste match")
    }

    private func nudgeButton(_ friend: Friend) -> some View {
        let nudgeStore = env.friendNudgeStore
        return Button {
            Task { await nudgeStore.send(to: friend) }
        } label: {
            Label(nudgeStore.buttonTitle(for: friend), systemImage: nudgeStore.iconName(for: friend))
                .font(.caption.weight(.semibold))
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(nudgeStore.isDisabled(for: friend))
        .accessibilityLabel("Nudge \(friend.profile.displayName ?? "friend")")
        .accessibilityHint("Send a push notification encouraging them to check Daily Music")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.heavy))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }

    private var wash: some View {
        LinearGradient(
            colors: [
                Theme.Brand.gradient[0].opacity(0.30),
                Color(.systemBackground).opacity(0.95),
                Theme.Brand.gradient[1].opacity(0.16)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

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
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command.
Expected: BUILD SUCCEEDED.

> If the `nudgeButton` change to `.labelStyle(.iconOnly)` loses needed context, the original `nudgeStore.message(for:)` line can be re-added below the button; it was dropped here to keep the row compact. Confirm during manual check.

- [ ] **Step 3: Manual check (mock environment)**

Run the app and open Friends:
- Wash background (not grey grouped-list), invite card up top.
- An **Activity** section listing Alex's loved/passed on recent drops, with covers.
- **Your friends** rows show a **taste-match % bar** for Alex.
- Swipe a friend row left → **Remove** still works. Nudge button still works.

- [ ] **Step 4: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add "Daily Music/Views/Friends/FriendsView.swift"
git commit -m "feat: redesign Friends tab as an art-directed activity feed"
```

---

## Task 8: Full verification + architecture doc

**Files:**
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Run the whole test suite**

Run the test command.
Expected: PASS — including the new `FriendActivityFeedTests`, `FriendReactionBubbleLogicTests`, `FriendsActivityStoreTests`, and the existing `FriendsStoreTests`.

- [ ] **Step 2: Update the architecture map**

In `docs/ARCHITECTURE.md`, add `FriendsActivityStore` to the stores/state section and note the Friends-feed + Today-bubbles flow (both read `FriendsActivityStore`, powered by `friend_ratings`; friends' badges/streaks are deferred to Phase 2). Match the file's existing format.

- [ ] **Step 3: Commit**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
git add docs/ARCHITECTURE.md
git commit -m "docs: map FriendsActivityStore + friends feed / Today bubbles"
```

---

## Self-Review Notes

- **Spec coverage:** Friends redesign → Task 7. Activity feed (ratings-powered) → Tasks 1, 3, 6, 7. Today floating bubbles (Option B, reveal-after-engage, cap+overflow, loved/passed) → Tasks 1, 2, 4, 5. No-backend constraint → all data via existing `friend_ratings`/`publishedHistory`/`myRatings`. Phase-2 items (friends' badges/streaks, emoji bubbles) intentionally excluded.
- **Deviation from spec:** the optional "taste-match highlight" feed item is dropped; match % is shown on friend rows instead (Task 7). Documented in the File Structure scope note.
- **Type consistency:** `Verdict`, `FriendReaction`, `FriendActivityItem`, `FriendActivityFeed.{recentDropItems,todayReactions,matchPercents}`, `BubbleLayout.split`, `FriendBubbleReveal.shouldShow`, and `FriendsActivityStore.{items,todayReactions,matchByFriend,load()}` are defined in Tasks 1–3 and used unchanged in Tasks 4–7.
- **Test registration:** new test files (`FriendActivityFeedTests.swift`, `FriendsActivityStoreTests.swift`) require manual Xcode target registration — flagged in Tasks 1 and 3.
```
