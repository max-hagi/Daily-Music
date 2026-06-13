# Listen-Tracking Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist every listen with a timestamp server-side so the collection's `heardSameDay` vs `caughtUp` distinction (and the hero count) is derivable, replacing the overwritten `heardEntryID` AppStorage and the local-only `CatchUpLog`.

**Architecture:** A pure `ListenStatus.of(entryDate:heardAt:asOf:)` function derives display state from `(entry.date, heard_at, now)` alone. A new RLS-scoped `listens` table (mirroring `favourites`) is the durable source of truth; `ListensStore` wraps it with an optimistic, UserDefaults-cached `[UUID: Date]` so `hasHeard`/`status` are synchronously correct on cold launch. One `markHeard(entry)` call replaces three scattered mechanisms; `CatchUpLog`, the `heardEntryID` AppStorage, and `CatchUp.missedEntries`' check-in dependency are all superseded.

**Tech Stack:** Swift 6 / SwiftUI, `@Observable` stores, Supabase (PostgREST + RLS), Swift Testing (`import Testing`, `@Test`, `#expect`).

**Spec:** `docs/superpowers/specs/2026-06-13-listen-tracking-foundation-design.md`

---

## Conventions used throughout

**Build:** (`xcode-select` points at CommandLineTools, so override `DEVELOPER_DIR`)
```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
```

**Test** (swap `build` → `test`; filter with `-only-testing`):
```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/ListenStatusTests" test
```

- **App-target sources auto-compile:** any new `.swift` under `Daily Music/` is picked up by the Xcode-16 file-system-synchronized group. **No `project.pbxproj` edit needed for app code.**
- **Test target is NOT synchronized:** new test *files* require manual Xcode registration. To avoid that, all new tests in this plan are appended to the already-registered `Daily MusicTests/CatchUpTests.swift` (which already hosts multiple `struct …Tests`).

## File Structure

- **Create** `Daily Music/Models/ListenStatus.swift` — the enum + pure derivation. Sibling to `CatchUp` (shares `windowDays`).
- **Create** `Daily Music/Services/ListensService.swift` — protocol + `MockListensService`.
- **Create** `Daily Music/Services/Supabase/SupabaseListensService.swift` — live PostgREST impl.
- **Create** `Daily Music/ViewModels/ListensStore.swift` — observable store, local cache, legacy migration.
- **Create** `docs/superpowers/specs/listen-tracking.sql` — the migration (hand-applied in the dashboard).
- **Modify** `Daily Music/App/AppEnvironment.swift` — wire `listens` service + `listensStore`.
- **Modify** `Daily Music/Views/TodayView.swift` — `markHeard` on listen; auto-open keys off the store; drop `heardEntryID`.
- **Modify** `Daily Music/Views/VaultView.swift` — `markHeard` via store (2 sites); `missedRecentEntries` via `heardAt`.
- **Modify** `Daily Music/Views/MainTabView.swift` — badge via `heardAt`.
- **Modify** `Daily Music/Models/ListeningCeremony.swift` — `shouldAutoOpen(hasHeardToday:)`.
- **Modify** `Daily Music/Models/CatchUp.swift` — reimplement `missedEntries(in:heardAt:)`; delete `CatchUpLog`.
- **Modify** `Daily Music/Views/SettingsView.swift` — drop the `heardEntryID` reset line.
- **Modify** `Daily MusicTests/CatchUpTests.swift` — new test structs; update `missedEntries`/log tests.
- **Modify** `Daily MusicTests/PlaybackTests.swift` — update the three `shouldAutoOpen` tests.

---

## Task 1: `ListenStatus` enum + pure derivation

**Files:**
- Create: `Daily Music/Models/ListenStatus.swift`
- Test: `Daily MusicTests/CatchUpTests.swift` (append a new `struct ListenStatusTests`)

- [ ] **Step 1: Write the failing tests**

Append to `Daily MusicTests/CatchUpTests.swift` (after the existing `import`s are already present at the top — do not re-add them):

```swift
struct ListenStatusTests {
    private let calendar = Calendar(identifier: .gregorian)

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 12))!
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
    }

    @Test func todaysDropNotYetHeardIsUnheard() {
        let status = ListenStatus.of(entryDate: day(0), heardAt: nil, calendar: calendar, asOf: now)
        #expect(status == .unheard)
    }

    @Test func futureDropIsUnheard() {
        let status = ListenStatus.of(entryDate: day(1), heardAt: nil, calendar: calendar, asOf: now)
        #expect(status == .unheard)
    }

    @Test func heardOnItsOwnDayIsHeardSameDay() {
        let status = ListenStatus.of(entryDate: day(-2), heardAt: day(-2), calendar: calendar, asOf: now)
        #expect(status == .heardSameDay)
    }

    @Test func heardLaterIsCaughtUp() {
        // Dropped 5 days ago, heard 2 days ago.
        let status = ListenStatus.of(entryDate: day(-5), heardAt: day(-2), calendar: calendar, asOf: now)
        #expect(status == .caughtUp)
    }

    @Test func missedButStillInsideWindowIsRescuable() {
        let status = ListenStatus.of(entryDate: day(-3), heardAt: nil, calendar: calendar, asOf: now)
        #expect(status == .rescuable)
    }

    @Test func atWindowEdgeIsStillRescuable() {
        // Exactly windowDays (7) old, never heard → still rescuable, not missed.
        let status = ListenStatus.of(entryDate: day(-7), heardAt: nil, calendar: calendar, asOf: now)
        #expect(status == .rescuable)
    }

    @Test func pastTheWindowNeverHeardIsMissed() {
        let status = ListenStatus.of(entryDate: day(-8), heardAt: nil, calendar: calendar, asOf: now)
        #expect(status == .missed)
    }

    @Test func daysLateIsTheGapBetweenDropAndListen() {
        #expect(ListenStatus.daysLate(entryDate: day(-5), heardAt: day(-2), calendar: calendar) == 3)
        #expect(ListenStatus.daysLate(entryDate: day(-2), heardAt: day(-2), calendar: calendar) == 0)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/ListenStatusTests" test
```
Expected: FAIL — compile error, `cannot find 'ListenStatus' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Daily Music/Models/ListenStatus.swift`:

```swift
//
//  ListenStatus.swift
//  Daily Music
//
//  Derived display state for a drop, from (drop date, when it was heard, now).
//  Literal in code; the record-shop vocabulary lives only in these comments and
//  the UI layer. Sibling to CatchUp so the catch-up window constant is shared.
//

import Foundation

enum ListenStatus: Equatable {
    case unheard       // today's (or future) drop, not played yet   → art: "pending"
    case heardSameDay  // played on its own day                       → art: "mint"
    case caughtUp      // played late, inside the catch-up window      → art: "secondhand"
    case rescuable     // missed but still inside the window           → art: "still available"
    case missed        // window closed, never played                 → art: "missing"
}

extension ListenStatus {
    /// Single source of truth. `heardAt` is the EARLIEST listen (first-listen-wins),
    /// so the same-day vs late decision is stable.
    static func of(
        entryDate: Date,
        heardAt: Date?,
        windowDays: Int = CatchUp.windowDays,
        calendar: Calendar = .current,
        asOf now: Date = Date()
    ) -> ListenStatus {
        let entryDay = calendar.startOfDay(for: entryDate)
        let today = calendar.startOfDay(for: now)

        if let heardAt {
            let heardDay = calendar.startOfDay(for: heardAt)
            return heardDay <= entryDay ? .heardSameDay : .caughtUp
        }
        if entryDay >= today { return .unheard }
        let daysOld = calendar.dateComponents([.day], from: entryDay, to: today).day ?? 0
        return daysOld <= windowDays ? .rescuable : .missed
    }

    /// Days between the drop's day and when it was caught up. 0 for same-day.
    static func daysLate(
        entryDate: Date,
        heardAt: Date,
        calendar: Calendar = .current
    ) -> Int {
        let entryDay = calendar.startOfDay(for: entryDate)
        let heardDay = calendar.startOfDay(for: heardAt)
        return max(0, calendar.dateComponents([.day], from: entryDay, to: heardDay).day ?? 0)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the Step 2 command. Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/ListenStatus.swift" "Daily MusicTests/CatchUpTests.swift"
git commit -m "feat(collection): add ListenStatus derivation"
```

---

## Task 2: `ListensService` protocol + mock

**Files:**
- Create: `Daily Music/Services/ListensService.swift`
- Test: `Daily MusicTests/CatchUpTests.swift` (append a new `struct ListensServiceTests`)

- [ ] **Step 1: Write the failing test**

Append to `Daily MusicTests/CatchUpTests.swift`:

```swift
struct ListensServiceTests {
    private func makeEntryID() -> UUID { UUID() }

    @Test func markingHeardRecordsTheEntry() async throws {
        let service = MockListensService()
        let id = makeEntryID()
        try await service.markHeard(entryID: id)
        let heard = try await service.heardEntries()
        #expect(heard[id] != nil)
    }

    @Test func firstListenWinsSoHeardAtIsNeverOverwritten() async throws {
        let service = MockListensService()
        let id = makeEntryID()
        try await service.markHeard(entryID: id)
        let first = try await service.heardEntries()[id]
        try await Task.sleep(for: .milliseconds(10))
        try await service.markHeard(entryID: id)   // second mark must be ignored
        let second = try await service.heardEntries()[id]
        #expect(first == second)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/ListensServiceTests" test
```
Expected: FAIL — `cannot find 'MockListensService' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Daily Music/Services/ListensService.swift`:

```swift
//
//  ListensService.swift
//  Daily Music
//
//  Records the first time a user hears each entry. The seam deals in entry IDs
//  and their heard-at timestamps; ListenStatus turns (entry.date, heard_at) into
//  display state. Mirrors FavoritesService — RLS scopes everything to the user.
//

import Foundation

protocol ListensService {
    /// entry_id → the earliest time the user heard it.
    func heardEntries() async throws -> [UUID: Date]
    /// Insert-if-absent (first listen wins). A repeat call must NOT move heard_at.
    func markHeard(entryID: UUID) async throws
}

// `actor` serializes access to `heard` with no locks (see MockFavoritesService).
actor MockListensService: ListensService {
    private var heard: [UUID: Date] = [:]

    func heardEntries() async throws -> [UUID: Date] { heard }

    func markHeard(entryID: UUID) async throws {
        // First-listen-wins: only the first mark sets the timestamp.
        if heard[entryID] == nil { heard[entryID] = Date() }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run the Step 2 command. Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Services/ListensService.swift" "Daily MusicTests/CatchUpTests.swift"
git commit -m "feat(collection): add ListensService + mock"
```

---

## Task 3: `SupabaseListensService` + migration SQL

**Files:**
- Create: `Daily Music/Services/Supabase/SupabaseListensService.swift`
- Create: `docs/superpowers/specs/listen-tracking.sql`

No unit test (requires a live Supabase backend); verified by compiling.

- [ ] **Step 1: Write the migration SQL**

Create `docs/superpowers/specs/listen-tracking.sql`:

```sql
-- Listen tracking: one row the first time a user hears an entry.
-- Backs the ListenStatus derivation and the hero collection count.
-- Apply by hand in Supabase Dashboard → SQL Editor.

create table if not exists public.listens (
  user_id  uuid not null references auth.users(id) on delete cascade,
  entry_id uuid not null references public.daily_entries(id) on delete cascade,
  heard_at timestamptz not null default now(),
  primary key (user_id, entry_id)
);

alter table public.listens enable row level security;

-- Owner-scoped. Insert + select only: a collection never updates or shrinks.
drop policy if exists "see own listens" on public.listens;
create policy "see own listens" on public.listens
  for select using (user_id = auth.uid());

drop policy if exists "insert own listens" on public.listens;
create policy "insert own listens" on public.listens
  for insert with check (user_id = auth.uid());

create index if not exists listens_user_heard_at_idx
  on public.listens (user_id, heard_at desc);
```

- [ ] **Step 2: Write the service**

Create `Daily Music/Services/Supabase/SupabaseListensService.swift`:

```swift
//
//  SupabaseListensService.swift
//  Daily Music
//
//  Live listens backed by the `listens` table. RLS scopes every read/write to
//  the signed-in user, so reads don't filter by user_id. The insert sets user_id
//  (RLS WITH CHECK requires it) and uses ON CONFLICT DO NOTHING so a later catch-up
//  never overwrites an earlier same-day heard_at (first-listen-wins).
//

import Foundation
import Supabase

final class SupabaseListensService: ListensService {
    private let client = Supa.client

    func heardEntries() async throws -> [UUID: Date] {
        let rows: [ListenRow] = try await client
            .from("listens")
            .select("entry_id,heard_at")
            .execute()
            .value
        return Dictionary(rows.map { ($0.entry_id, $0.heard_at) },
                          uniquingKeysWith: min)   // keep the earliest if duplicated
    }

    func markHeard(entryID: UUID) async throws {
        let userID = try await client.auth.session.user.id
        // ignoreDuplicates → ON CONFLICT DO NOTHING: heard_at is set once and kept.
        try await client
            .from("listens")
            .upsert(ListenInsert(user_id: userID, entry_id: entryID),
                    onConflict: "user_id,entry_id",
                    ignoreDuplicates: true)
            .execute()
    }
}

// Read shape: entry_id + heard_at. `heard_at` decodes from timestamptz via the
// Supabase client's configured date decoding (ISO-8601), as elsewhere in the app.
private struct ListenRow: Decodable {
    let entry_id: UUID
    let heard_at: Date
}

// Write shape: heard_at is omitted so the column default now() applies server-side.
private struct ListenInsert: Encodable {
    let user_id: UUID
    let entry_id: UUID
}
```

- [ ] **Step 3: Build to verify it compiles**

Run the build command from "Conventions". Expected: BUILD SUCCEEDED.

> If the compiler rejects decoding `heard_at` into `Date` (date strategy mismatch), change `ListenRow.heard_at` to `String` and parse it in `heardEntries()` with the same ISO-8601 approach used by other Supabase row structs in `Daily Music/Services/Supabase/`. Check a sibling service (e.g. one that reads a `timestamptz`) before assuming.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Services/Supabase/SupabaseListensService.swift" "docs/superpowers/specs/listen-tracking.sql"
git commit -m "feat(collection): add live listens service + migration SQL"
```

---

## Task 4: `ListensStore` (observable, cached, migrating)

**Files:**
- Create: `Daily Music/ViewModels/ListensStore.swift`
- Test: `Daily MusicTests/CatchUpTests.swift` (append a new `struct ListensStoreTests`)

- [ ] **Step 1: Write the failing tests**

Append to `Daily MusicTests/CatchUpTests.swift`:

```swift
@MainActor
struct ListensStoreTests {
    private func entry(_ id: UUID = UUID(), date: Date = Date()) -> DailyEntry {
        DailyEntry(id: id, date: date, title: "Song", artist: "Artist",
                   albumArtURL: nil, journalMarkdown: "", appleMusicID: "1",
                   spotifyURI: "spotify:track:1")
    }

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "listens-tests-\(UUID().uuidString)")!
    }

    @Test func markingHeardUpdatesStateAndCount() async {
        let store = ListensStore(service: MockListensService(), defaults: freshDefaults())
        let e = entry()
        store.markHeard(e)
        #expect(store.isHeard(e))
        #expect(store.collectionCount == 1)
    }

    @Test func markHeardIsIdempotent() async {
        let store = ListensStore(service: MockListensService(), defaults: freshDefaults())
        let e = entry()
        store.markHeard(e)
        let first = store.heardAt[e.id]
        store.markHeard(e)
        #expect(store.heardAt[e.id] == first)
        #expect(store.collectionCount == 1)
    }

    @Test func cachePersistsAcrossInstances() async {
        let defaults = freshDefaults()
        let e = entry()
        let store = ListensStore(service: MockListensService(), defaults: defaults)
        store.markHeard(e)
        let restored = ListensStore(service: MockListensService(), defaults: defaults)
        #expect(restored.isHeard(e))
    }

    @Test func legacyHeardIDsAreMigratedOnce() async {
        let defaults = freshDefaults()
        let legacyID = UUID()
        defaults.set([legacyID.uuidString], forKey: "vault.heardEntryIDs")
        let store = ListensStore(service: MockListensService(), defaults: defaults)
        #expect(store.heardAt[legacyID] != nil)
    }

    @Test func loadMergesServerRowsKeepingEarliest() async {
        let defaults = freshDefaults()
        let e = entry()
        let service = MockListensService()
        try? await service.markHeard(entryID: e.id)   // server has a row
        let store = ListensStore(service: service, defaults: defaults)
        await store.load()
        #expect(store.isHeard(e))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/ListensStoreTests" test
```
Expected: FAIL — `cannot find 'ListensStore' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Daily Music/ViewModels/ListensStore.swift`:

```swift
//
//  ListensStore.swift
//  Daily Music
//
//  One reactive source of truth for "what has the user heard, and when". Wraps
//  ListensService (the durable, cross-device store) but ALSO keeps a UserDefaults
//  cache so isHeard/status are correct SYNCHRONOUSLY on cold launch — otherwise
//  the listening ceremony could replay before the server load() returns.
//
//  markHeard is optimistic and first-listen-wins: the first mark sets heard_at,
//  repeats are no-ops. load() merges the server's rows in, keeping the earliest
//  timestamp. Supersedes CatchUpLog (it also migrates that old local set once).
//

import Foundation

@MainActor
@Observable
final class ListensStore {
    /// entry_id → earliest heard_at. Observed: views re-render on change.
    private(set) var heardAt: [UUID: Date] = [:]

    private let service: ListensService
    private let defaults: UserDefaults
    private static let cacheKey = "listens.heardAt"          // [uuidString: epochSeconds]
    private static let legacyKey = "vault.heardEntryIDs"     // old CatchUpLog set
    private static let migratedKey = "listens.migratedLegacy"

    init(service: ListensService, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        hydrateFromCache()
        migrateLegacyIfNeeded()
    }

    func isHeard(_ entry: DailyEntry) -> Bool { heardAt[entry.id] != nil }

    func status(for entry: DailyEntry, asOf now: Date = Date()) -> ListenStatus {
        ListenStatus.of(entryDate: entry.date, heardAt: heardAt[entry.id], asOf: now)
    }

    /// Hero metric: records collected (every row with a heard_at).
    var collectionCount: Int { heardAt.count }

    /// Merge server rows into the cache, keeping the earliest heard_at per entry.
    func load() async {
        guard let remote = try? await service.heardEntries() else { return }
        for (id, date) in remote {
            heardAt[id] = heardAt[id].map { min($0, date) } ?? date
        }
        persist()
    }

    /// Optimistic, first-listen-wins. No-op if already heard (preserves heard_at).
    func markHeard(_ entry: DailyEntry) {
        guard heardAt[entry.id] == nil else { return }
        heardAt[entry.id] = Date()
        persist()
        Task { try? await service.markHeard(entryID: entry.id) }
    }

    private func hydrateFromCache() {
        let raw = defaults.dictionary(forKey: Self.cacheKey) as? [String: Double] ?? [:]
        heardAt = Dictionary(uniqueKeysWithValues: raw.compactMap { key, secs in
            UUID(uuidString: key).map { ($0, Date(timeIntervalSince1970: secs)) }
        })
    }

    private func persist() {
        let raw = Dictionary(uniqueKeysWithValues:
            heardAt.map { ($0.key.uuidString, $0.value.timeIntervalSince1970) })
        defaults.set(raw, forKey: Self.cacheKey)
    }

    /// One-time: fold the old CatchUpLog set into listens (as catch-ups, heard now)
    /// and push each to the server so the records aren't lost on reinstall.
    private func migrateLegacyIfNeeded() {
        guard !defaults.bool(forKey: Self.migratedKey) else { return }
        let now = Date()
        for idString in defaults.stringArray(forKey: Self.legacyKey) ?? [] {
            guard let id = UUID(uuidString: idString), heardAt[id] == nil else { continue }
            heardAt[id] = now
            Task { try? await service.markHeard(entryID: id) }
        }
        persist()
        defaults.set(true, forKey: Self.migratedKey)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run the Step 2 command. Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/ViewModels/ListensStore.swift" "Daily MusicTests/CatchUpTests.swift"
git commit -m "feat(collection): add ListensStore with local cache + legacy migration"
```

---

## Task 5: Wire into `AppEnvironment`

**Files:**
- Modify: `Daily Music/App/AppEnvironment.swift`

Pure wiring (no callers yet) — build stays green.

- [ ] **Step 1: Add the stored properties**

In `Daily Music/App/AppEnvironment.swift`, after the `favorites` property (line 28) add the service, and after `favoritesStore` (line 41) add the store:

```swift
    let favorites: FavoritesService
    let listens: ListensService
```
```swift
    let favoritesStore: FavoritesStore
    let listensStore: ListensStore
```

- [ ] **Step 2: Add the init parameter**

In the `init(...)` signature, after the `favorites: FavoritesService,` parameter add:

```swift
        favorites: FavoritesService,
        listens: ListensService,
```

In the init body, after `self.favorites = favorites` add the assignment, and after `self.favoritesStore = FavoritesStore(service: favorites)` add the store:

```swift
        self.favorites = favorites
        self.listens = listens
```
```swift
        self.favoritesStore = FavoritesStore(service: favorites)
        self.listensStore = ListensStore(service: listens)
```

- [ ] **Step 3: Wire both factories**

In `mock()`, after `favorites: MockFavoritesService(),` add:
```swift
            favorites: MockFavoritesService(),
            listens: MockListensService(),
```

In `live()`, after `favorites: SupabaseFavouritesService(),` add:
```swift
            favorites: SupabaseFavouritesService(),
            listens: SupabaseListensService(),
```

- [ ] **Step 4: Build to verify**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/App/AppEnvironment.swift"
git commit -m "feat(collection): wire ListensService + ListensStore into env"
```

---

## Task 6: Route listen writes through the store

**Files:**
- Modify: `Daily Music/Views/TodayView.swift:105`
- Modify: `Daily Music/Views/VaultView.swift:237` and `:286`

`catchUpLog.markHeard` and the `heardEntryID` write are replaced by `listensStore.markHeard`. `heardEntryID` is still *read* by the auto-open logic — that's removed in Task 8, so leave the `@AppStorage` declaration for now.

- [ ] **Step 1: TodayView — record on listen completion**

In `Daily Music/Views/TodayView.swift`, the `ListeningView` completion (around line 104-110) currently is:
```swift
                    ListeningView(entry: entry, showsRevealIntro: listeningIsCeremony) {
                        heardEntryID = entry.id.uuidString
                        showingListening = false
```
Change the first line of the closure body to also record the listen:
```swift
                    ListeningView(entry: entry, showsRevealIntro: listeningIsCeremony) {
                        heardEntryID = entry.id.uuidString
                        env.listensStore.markHeard(entry)
                        showingListening = false
```

- [ ] **Step 2: VaultView — both catch-up sites**

In `Daily Music/Views/VaultView.swift`, in `openVaultEntry(_:openedFromExternalSource:)` (line ~237):
```swift
        // Opening counts as catching up — the hero and tab badge clear live.
        env.catchUpLog.markHeard(entry)
```
→
```swift
        // Opening counts as catching up — the hero and tab badge clear live.
        env.listensStore.markHeard(entry)
```

In `VaultAllSongsView`'s list button (line ~286):
```swift
                        selectedEntry = entry
                        env.catchUpLog.markHeard(entry)   // counts as catching up
```
→
```swift
                        selectedEntry = entry
                        env.listensStore.markHeard(entry)   // counts as catching up
```

- [ ] **Step 3: Build to verify**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/TodayView.swift" "Daily Music/Views/VaultView.swift"
git commit -m "feat(collection): record listens through ListensStore"
```

---

## Task 7: Reimplement `CatchUp.missedEntries` on `ListenStatus`

**Files:**
- Modify: `Daily Music/Models/CatchUp.swift` (the `missedEntries` function only — leave `CatchUpLog` for Task 9)
- Modify: `Daily Music/Views/MainTabView.swift:55-65` (badge) and the `checkInDays` state it no longer needs
- Modify: `Daily Music/Views/VaultView.swift:107-115` (`missedRecentEntries`)
- Test: `Daily MusicTests/CatchUpTests.swift` — rewrite the `CatchUpTests` `missedEntries` cases

"Missed" now means `ListenStatus == .rescuable`. This drops the `checkInDays` dependency — opening the app without listening no longer clears the badge (intentional, per spec §4).

- [ ] **Step 1: Update the tests first**

In `Daily MusicTests/CatchUpTests.swift`, replace the four `missedEntries` tests inside `struct CatchUpTests` (`dropsOnUnopenedDaysCountAsMissed`, `todayIsNeverMissed`, `dropsOlderThanTheWindowAreJustArchive`, `catchingUpClearsTheEntry`) with:

```swift
    @Test func dropsWithinWindowNotHeardAreRescuable() {
        let rescuable = entry(daysAgo: 2)
        let heard = entry(daysAgo: 1)
        let missed = CatchUp.missedEntries(
            in: [rescuable, heard],
            heardAt: [heard.id: day(-1)],
            calendar: calendar, asOf: now
        )
        #expect(missed.map(\.id) == [rescuable.id])
    }

    @Test func todayIsNeverMissed() {
        let todays = entry(daysAgo: 0)
        let missed = CatchUp.missedEntries(
            in: [todays], heardAt: [:], calendar: calendar, asOf: now
        )
        #expect(missed.isEmpty)
    }

    @Test func dropsOlderThanTheWindowAreJustArchive() {
        let old = entry(daysAgo: 8)
        let missed = CatchUp.missedEntries(
            in: [old], heardAt: [:], calendar: calendar, asOf: now
        )
        #expect(missed.isEmpty)
    }

    @Test func catchingUpClearsTheEntry() {
        let target = entry(daysAgo: 3)
        let missed = CatchUp.missedEntries(
            in: [target], heardAt: [target.id: day(-1)], calendar: calendar, asOf: now
        )
        #expect(missed.isEmpty)
    }
```

(Leave `logPersistsAndRestoresHeardIDs` for now — Task 9 removes it with `CatchUpLog`.)

- [ ] **Step 2: Run to verify the new tests fail**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/CatchUpTests" test
```
Expected: FAIL — `missedEntries` has no `heardAt:` parameter.

- [ ] **Step 3: Reimplement `missedEntries`**

In `Daily Music/Models/CatchUp.swift`, replace the entire `missedEntries(...)` function (the body inside `enum CatchUp`, keeping `windowDays`) with:

```swift
    /// Entries still rescuable: missed but inside the window. Drives the Vault
    /// hero and tab badge. Derived from ListenStatus, so an entry clears the
    /// moment it's heard (rescuable → caughtUp). Note: opening the app without
    /// listening no longer clears it — only an actual listen does.
    static func missedEntries(
        in entries: [DailyEntry],
        heardAt: [UUID: Date],
        calendar: Calendar = .current,
        asOf now: Date = Date()
    ) -> [DailyEntry] {
        entries.filter {
            ListenStatus.of(entryDate: $0.date, heardAt: heardAt[$0.id],
                            calendar: calendar, asOf: now) == .rescuable
        }
    }
```

- [ ] **Step 4: Update MainTabView's badge**

In `Daily Music/Views/MainTabView.swift`, change `missedDropCount` (line ~57):
```swift
    private var missedDropCount: Int {
        CatchUp.missedEntries(
            in: publishedEntries,
            heardAt: env.listensStore.heardAt
        ).count
    }
```
Then remove the now-unused check-in state. Delete the `checkInDays` property (line ~19):
```swift
    @State private var checkInDays: Set<Date> = []
```
and the line that loads it inside the `.task` (line ~45):
```swift
            checkInDays = (try? await env.checkIns.checkInDates()) ?? []
```
(Verify nothing else references it: `grep -n "checkInDays" "Daily Music/Views/MainTabView.swift"` should return no results after.)

- [ ] **Step 5: Update VaultView's `missedRecentEntries`**

In `Daily Music/Views/VaultView.swift` (line ~107):
```swift
    private func missedRecentEntries(_ entries: [DailyEntry]) -> [DailyEntry] {
        CatchUp.missedEntries(
            in: entries,
            heardAt: env.listensStore.heardAt,
            calendar: calendar
        )
    }
```
Then check whether `checkInDays` is still used elsewhere in this file:
```bash
grep -n "checkInDays" "Daily Music/Views/VaultView.swift"
```
If the only remaining hits are its declaration and its `.task` load, remove those two lines too. If the calendar view or anything else still reads it, leave them.

- [ ] **Step 6: Run tests + build to verify**

Run the Step 2 test command (expect PASS for `CatchUpTests`), then the full build (expect BUILD SUCCEEDED).

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Models/CatchUp.swift" "Daily Music/Views/MainTabView.swift" "Daily Music/Views/VaultView.swift" "Daily MusicTests/CatchUpTests.swift"
git commit -m "feat(collection): derive missed/rescuable from ListenStatus"
```

---

## Task 8: Auto-open keys off the store; drop `heardEntryID`

**Files:**
- Modify: `Daily Music/Models/ListeningCeremony.swift`
- Modify: `Daily MusicTests/PlaybackTests.swift` (the three `shouldAutoOpen` tests, lines ~87-99)
- Modify: `Daily Music/Views/TodayView.swift` (the `.onChange` auto-open + remove `heardEntryID`)
- Modify: `Daily Music/Views/SettingsView.swift:489`

`shouldAutoOpen` becomes a pure function of "has today's entry been heard?", computed from `ListensStore`.

- [ ] **Step 1: Update the ceremony tests first**

In `Daily MusicTests/PlaybackTests.swift`, replace the three tests:
```swift
    @Test func autoOpensWhenTodayNotYetHeard() {
        let id = UUID()
        #expect(ListeningCeremony.shouldAutoOpen(todayEntryID: id, heardEntryID: nil))
    }

    @Test func doesNotAutoOpenWhenTodayAlreadyHeard() {
        let id = UUID()
        #expect(!ListeningCeremony.shouldAutoOpen(todayEntryID: id, heardEntryID: id.uuidString))
    }

    @Test func autoOpensWhenHeardWasADifferentDay() {
        #expect(ListeningCeremony.shouldAutoOpen(todayEntryID: UUID(), heardEntryID: UUID().uuidString))
    }
```
with:
```swift
    @Test func autoOpensWhenTodayNotYetHeard() {
        #expect(ListeningCeremony.shouldAutoOpen(hasHeardToday: false))
    }

    @Test func doesNotAutoOpenWhenTodayAlreadyHeard() {
        #expect(!ListeningCeremony.shouldAutoOpen(hasHeardToday: true))
    }
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Daily MusicTests/PlaybackTests" test
```
Expected: FAIL — `shouldAutoOpen(hasHeardToday:)` not found.

- [ ] **Step 3: Update `ListeningCeremony`**

In `Daily Music/Models/ListeningCeremony.swift`, replace `shouldAutoOpen`:
```swift
    /// Auto-open the immersive screen only when today's drop hasn't been heard
    /// yet. The caller derives `hasHeardToday` from ListensStore.
    static func shouldAutoOpen(hasHeardToday: Bool) -> Bool {
        !hasHeardToday
    }
```
(Update the doc comment above it that references `heardEntryID` to describe `hasHeardToday`.)

- [ ] **Step 4: Update TodayView's auto-open + remove `heardEntryID`**

In `Daily Music/Views/TodayView.swift`, the `.onChange(of: loadedEntry?.id)` block (lines ~113-128) currently computes `heard` from the AppStorage string. Replace its guard:
```swift
            .onChange(of: loadedEntry?.id) { _, _ in
                guard let entry = loadedEntry else { return }
                let heard = heardEntryID.isEmpty ? nil : heardEntryID
                guard ListeningCeremony.shouldAutoOpen(todayEntryID: entry.id, heardEntryID: heard) else { return }
```
with:
```swift
            .onChange(of: loadedEntry?.id) { _, _ in
                guard let entry = loadedEntry else { return }
                guard ListeningCeremony.shouldAutoOpen(hasHeardToday: env.listensStore.isHeard(entry)) else { return }
```
Then, in the `ListeningView` completion (changed in Task 6), remove the now-redundant AppStorage write so `markHeard` is the only record:
```swift
                    ListeningView(entry: entry, showsRevealIntro: listeningIsCeremony) {
                        env.listensStore.markHeard(entry)
                        showingListening = false
```
Finally remove the declaration at line ~24:
```swift
    @AppStorage("heardEntryID") private var heardEntryID = ""  // last entry the user listened to
```
(Verify: `grep -n "heardEntryID" "Daily Music/Views/TodayView.swift"` returns nothing.)

- [ ] **Step 5: Remove the SettingsView reset line**

In `Daily Music/Views/SettingsView.swift` (line ~489), delete:
```swift
        defaults.removeObject(forKey: "heardEntryID")
```

- [ ] **Step 6: Run tests + build to verify**

Run the Step 2 test command (expect PASS), then the full build (expect BUILD SUCCEEDED).

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Models/ListeningCeremony.swift" "Daily MusicTests/PlaybackTests.swift" "Daily Music/Views/TodayView.swift" "Daily Music/Views/SettingsView.swift"
git commit -m "feat(collection): auto-open ceremony from ListensStore, drop heardEntryID"
```

---

## Task 9: Remove `CatchUpLog`

**Files:**
- Modify: `Daily Music/Models/CatchUp.swift` (delete the `CatchUpLog` class; keep `enum CatchUp`)
- Modify: `Daily Music/App/AppEnvironment.swift` (remove the `catchUpLog` property + assignment)
- Modify: `Daily MusicTests/CatchUpTests.swift` (remove `logPersistsAndRestoresHeardIDs`)

`CatchUpLog` is fully superseded by `ListensStore`; its old UserDefaults data was already migrated in Task 4.

- [ ] **Step 1: Confirm there are no remaining references**

```bash
grep -rn "catchUpLog\|CatchUpLog" "Daily Music" "Daily MusicTests"
```
Expected remaining hits ONLY in: `CatchUp.swift` (the class itself), `AppEnvironment.swift` (property + init assignment), and `CatchUpTests.swift` (the `logPersistsAndRestoresHeardIDs` test + its use). If anything else still references it, stop and route it through `listensStore` first.

- [ ] **Step 2: Delete the `CatchUpLog` class**

In `Daily Music/Models/CatchUp.swift`, delete the entire `@MainActor @Observable final class CatchUpLog { … }` block (and its leading doc comment about the log). Keep `enum CatchUp { static let windowDays = 7 ; static func missedEntries(...) }` and remove any now-stale comment lines referencing the heard-IDs log.

- [ ] **Step 3: Remove it from `AppEnvironment`**

In `Daily Music/App/AppEnvironment.swift`, delete the property (line ~46):
```swift
    let catchUpLog: CatchUpLog
```
and the assignment in `init` (line ~124):
```swift
        self.catchUpLog = CatchUpLog()
```

- [ ] **Step 4: Remove the obsolete test**

In `Daily MusicTests/CatchUpTests.swift`, delete the `logPersistsAndRestoresHeardIDs` test method.

- [ ] **Step 5: Run the full test suite + build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```
Expected: BUILD SUCCEEDED and all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Models/CatchUp.swift" "Daily Music/App/AppEnvironment.swift" "Daily MusicTests/CatchUpTests.swift"
git commit -m "refactor(collection): remove CatchUpLog, superseded by ListensStore"
```

---

## Final verification

- [ ] Run the full suite (Task 9 Step 5 command). All tests pass, build succeeds.
- [ ] Apply `docs/superpowers/specs/listen-tracking.sql` in the Supabase dashboard before shipping (the live path 500s on `markHeard`/`heardEntries` until the table exists).
- [ ] Confirm the one-time content re-anchor (dashboard data op, per spec §5) is scheduled for launch — out of scope for code, but the foundation assumes it.

## Self-review notes (author)

- **Spec coverage:** §1 enum (Task 1) · §2 derivation + tests (Task 1) · §3 table/service/store + first-listen-wins (Tasks 2-4) · §4 wiring at all three call sites, supersession of `CatchUpLog`/`heardEntryID`/`missedEntries`, the flagged behavior change (Tasks 5-9) · §5 legacy local→server migration (Task 4) + SQL (Task 3); content re-anchor noted as out-of-code · hero count = `collectionCount` (Task 4).
- **Type consistency:** `ListenStatus.of(entryDate:heardAt:windowDays:calendar:asOf:)`, `ListensService.{heardEntries,markHeard}`, `ListensStore.{heardAt,isHeard,status,collectionCount,load,markHeard}`, `CatchUp.missedEntries(in:heardAt:calendar:asOf:)`, `ListeningCeremony.shouldAutoOpen(hasHeardToday:)` — names match across all tasks.
- **Deferred (downstream spec, not here):** Crate/Wall UI, collection-moment animation, variant engine, Curator, monetization.
