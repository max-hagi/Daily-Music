# Listen-Tracking Foundation — Design Spec

**Date:** 2026-06-13
**Status:** Approved for planning
**Relationship to other specs:** This corrects and replaces **Phase 1** of
`COLLECTION_REDESIGN_SPEC.md`. That spec's `PressingState` assumed same-day
listens were already tracked; they are not. Everything downstream in the big
spec (the Crate, the Wall, the collection-moment animation, the variant engine,
the Curator, monetization) is unchanged and consumes the `ListenStatus` defined
here.

---

## 0. The problem this fixes

The collection redesign's hero metric is "records you've collected," split into
*heard on its own day* vs *caught up later*. The original spec claimed this was
derivable with "no backend change, no migration" from data the app already
tracks. It is not:

- `checkInDays` records **"opened the app that day,"** not "listened."
  (`CheckIns.checkInDates()`, used by `Streak` and `CatchUp`.)
- The persistent `heardEntryIDs` set in `CatchUpLog` is populated **only by the
  Vault catch-up flow** (`VaultView.swift` → `catchUpLog.markHeard`), i.e. *late*
  listens by definition.
- Same-day listens only ever set the singular `heardEntryID` **AppStorage
  string** (`TodayView.swift:105`), which is overwritten every day and holds just
  the last entry.

So a record heard on its own day in the past lives in none of these. The
distinction the redesign is built on is **underivable for history**, and the
hero count inherits the gap.

**Root fix:** persist every listen with a timestamp, server-side, and derive
state purely from `(entry.date, heard_at, now)`. `checkInDays` goes back to
doing exactly one job — the streak.

---

## 1. The state — literal in code, thematic in comments

```swift
enum ListenStatus: Equatable {
    case unheard       // today's (or future) drop, not played yet   → art: "pending"
    case heardSameDay  // played on its own day                       → art: "mint"
    case caughtUp      // played late, inside the catch-up rules       → art: "secondhand"
    case rescuable     // missed but still inside the 7-day window     → art: "still available"
    case missed        // window closed, never played                  → art: "missing"
}
```

The "pressing / sleeve / mint / 2nd-pressing" vocabulary lives **only** in those
trailing comments and the UI/copy layer — never in type or case names. Case names
are cosmetic and may be tuned (`today`, etc.) before implementation; this is the
agreed shape.

**`daysLate` instead of more cases.** The original `withinThree` instinct is
served by a computed value, not extra enum cases:

```swift
/// Days between the drop's day and when it was caught up. 0 for same-day.
static func daysLate(entryDate: Date, heardAt: Date,
                     calendar: Calendar = .current) -> Int
```

so copy can say "within 3 days" / "2nd pressing" without fragmenting the enum.

**Counts toward the hero collection number:** `heardSameDay` + `caughtUp` (every
row with a `heard_at`). `rescuable`, `unheard`, and `missed` do not. Equivalently:
the hero count is the number of this user's `listens` rows.

---

## 2. Pure derivation (single source of truth)

A sibling to `CatchUp` so the window constant is shared.

```swift
extension ListenStatus {
    static func of(
        entryDate: Date,
        heardAt: Date?,
        windowDays: Int = CatchUp.windowDays,   // 7
        calendar: Calendar = .current,
        asOf now: Date = Date()
    ) -> ListenStatus {
        let entryDay = calendar.startOfDay(for: entryDate)
        let today    = calendar.startOfDay(for: now)

        if let heardAt {
            let heardDay = calendar.startOfDay(for: heardAt)
            return heardDay <= entryDay ? .heardSameDay : .caughtUp
        }
        if entryDay >= today { return .unheard }
        let daysOld = calendar.dateComponents([.day], from: entryDay, to: today).day ?? 0
        return daysOld <= windowDays ? .rescuable : .missed
    }
}
```

Notes:
- `heard_at` is the **earliest** listen (first-listen-wins, §3), so the same-day
  vs late decision is stable.
- `daysOld <= windowDays` matches `CatchUp.missedEntries`' existing boundary
  (`day >= today - 7` is still rescuable).

**Acceptance:** pure function, unit-tested with a fixed `asOf`, mirroring the
style of `Streak.compute` tests. Required cases: heard today (`heardSameDay`),
caught-up-day-3 (`caughtUp`, `daysLate == 3`), missed-window-closed (`missed`),
missed-but-still-in-window (`rescuable`), today-not-yet-heard and future
(`unheard`). Tests must be registered in the Xcode test target manually
(per project convention for new test files).

---

## 3. Storage — the backend addition

A new `listens` table mirroring `favourites` / `check_ins`: RLS owner-scoped,
composite key, **insert + select only** (a collection never updates or shrinks).

### Migration SQL (`docs/superpowers/specs/listen-tracking.sql`, hand-applied)

```sql
-- Listen tracking: one row the first time a user hears an entry.
-- Backs the ListenStatus derivation and the hero collection count.

create table if not exists public.listens (
  user_id  uuid not null references auth.users(id) on delete cascade,
  entry_id uuid not null references public.daily_entries(id) on delete cascade,
  heard_at timestamptz not null default now(),
  primary key (user_id, entry_id)
);

alter table public.listens enable row level security;

drop policy if exists "see own listens" on public.listens;
create policy "see own listens" on public.listens
  for select using (user_id = auth.uid());

drop policy if exists "insert own listens" on public.listens;
create policy "insert own listens" on public.listens
  for insert with check (user_id = auth.uid());

create index if not exists listens_user_heard_at_idx
  on public.listens (user_id, heard_at desc);
```

No update or delete policy on purpose: listens are permanent. No `SECURITY
DEFINER` count RPC needed — the hero count is the user's own row count, which RLS
already scopes (unlike `favourite_count`, which totals across users for social
proof).

### Service + store (cloned from the favorites pair)

```swift
protocol ListensService {
    func heardEntries() async throws -> [UUID: Date]      // entry_id → heard_at
    func markHeard(entryID: UUID) async throws            // insert-if-absent
}
```

- `SupabaseListensService.markHeard` upserts with
  `onConflict: "user_id,entry_id", ignoreDuplicates: true` (Postgres `on conflict
  … do nothing`) so a later Vault open **never overwrites** an earlier same-day
  `heard_at`. `heard_at` defaults to `now()` server-side — the client does not
  send it, because `markHeard` fires at the moment of listening.
- `MockListensService` for previews/tests, like `MockFavoritesService`.
- `ListensStore` (`@MainActor @Observable`) clones `FavoritesStore`: an
  optimistic in-memory `[UUID: Date]` the views observe, `load()` on launch,
  optimistic insert on `markHeard` with rollback on failure. Wired into
  `AppEnvironment` as `env.listens`.

---

## 4. Wiring into existing code

One `markHeard(entry)` call replaces three scattered mechanisms.

- **Same-day listen** — `TodayView.swift:105` (`ListeningView` completion): call
  `await env.listens.markHeard(entry.id)`. Remove the `heardEntryID` AppStorage
  write.
- **Catch-up listen** — `VaultView.swift:237` and `:286`: replace
  `env.catchUpLog.markHeard(entry)` with `await env.listens.markHeard(entry.id)`.
- **Ceremony auto-open** — `ListeningCeremony.shouldAutoOpen` currently keys off
  the `heardEntryID` string. Switch it to consult `ListensStore` ("has today's
  entry been heard?"). To avoid a re-ceremony race before the server `load()`
  returns on cold launch, `ListensStore` hydrates its cache from the one-time
  local migration (§5) first, then reconciles with the server.

### What this supersedes

- **`CatchUpLog`** (UserDefaults) → deleted; superseded by `listens` +
  `ListensStore`.
- **`heardEntryID` AppStorage** → deleted; auto-open keys off `ListensStore`.
  (`SettingsView.swift:489` removes this key on reset — drop that line.)
- **`CatchUp.missedEntries`** → reimplemented as "entries whose `ListenStatus`
  is `.rescuable`," dropping its `checkInDays` / `heardEntryIDs` parameters. The
  Vault badge keeps working and clears naturally when a record is heard
  (`markHeard` → `caughtUp` → no longer `rescuable`).

### Intentional behavior change (flagged)

Today, opening the app on a drop's day clears it from the missed badge **even if
the user never listened** (`missedEntries` excludes `openedDays`). Under the new
rule, only an actual listen clears it. A user who opens without listening will
see that drop as `rescuable` (and `missed` after the window). This is the correct
resolution of the check-in≠listen conflation and is intended, but it means the
badge may surface more items than before for open-without-listen users.

---

## 5. Transition & one-time migrations

Two separate operations, both one-time:

1. **Content re-anchor (data op, not code).** Before launch, re-date the existing
   `daily_entries` catalog so drops cluster around the present day going forward —
   the same approach as `docs/seeds/2026-06-11-compact-past-entries.sql`. This
   keeps the catalog shallow at launch so no user faces a deep wall of `missed`.
   Done by hand in the dashboard.

2. **Local → server listen migration (code, runs once).** On first launch after
   this ships, read the legacy `vault.heardEntryIDs` UserDefaults set and
   bulk-`markHeard` each into `listens` (do-nothing on conflict, `heard_at =
   now()`). These were all catch-up (late) listens, so they correctly become
   `caughtUp`. After migrating, the key is harmless to leave.

**Accepted consequences of the rules (per product decision):**
- Same-day-in-the-past listens were never persisted, so they are unrecoverable
  and will read as `rescuable`/`missed` per the window. Acceptable.
- A user who joins long after launch sees older drops as `missed`. The relief
  valve is the premium **back-catalog collecting** feature (`COLLECTION_REDESIGN_SPEC`
  §7), out of scope here.

---

## 6. Scope boundary

**In scope (this spec):** `ListenStatus` enum + pure derivation + tests; the
`listens` table, service, store, and `markHeard` wiring at the three call sites;
the supersession of `CatchUpLog` / `heardEntryID` / `CatchUp.missedEntries`; the
two one-time migrations; the hero collection count as a derived value.

**Out of scope (downstream, already in `COLLECTION_REDESIGN_SPEC`):** the Crate
flip-through UI, the Wall, the collection-moment animation, the streak→variant
engine, the Curator voice/pose layer, and monetization. All of those read
`ListenStatus` and the collection count; none are touched here.

---

## 7. Resolved questions

- **Do `caughtUp` records count toward the hero number?** Yes — any row with a
  `heard_at`. Only `missed`/`rescuable`/`unheard` are gaps.
- **Are `missed` sleeves always visible?** Yes (downstream UI concern, but the
  data supports it — gaps are honest history).
- **Signal for "listened"?** Completing the listening ceremony. No dwell timer,
  no explicit "keep" tap — fits the anti-tracking, care-based thesis.
- **Per-user or global drop dates?** Global (`daily_entries`), per-user listens.
  No `joined_at` gating in the derivation — a new user simply has no `listens`
  rows for pre-join drops, so the normal window rules apply.

## 8. Open (cosmetic / deferred)

- Exact `ListenStatus` case names (`today` vs `heardSameDay`, etc.) — cosmetic,
  lock during implementation.
- `daysLate` granularity buckets for copy ("within 3 days") — UI concern,
  downstream.
