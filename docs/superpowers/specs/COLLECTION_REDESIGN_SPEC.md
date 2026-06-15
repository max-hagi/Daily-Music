# Collection & Streak Redesign — Implementation Spec

A working spec for Claude Code. The product name is deliberately omitted; it is the
last, cheapest step. The mascot is referred to as **the Curator** throughout. Wire
asset slots as placeholders so art drops in later without code changes.

---

## 0. The thesis (keep this in view)

The app rebels against algorithmic recommendation. The retention model must therefore
be **identity-based, not anxiety-based**. A record collection grows and never resets;
a streak resets and breeds churn (the existing `Streak.swift` comments already name
this failure mode). So: **the collection is the hero metric. The streak is demoted to a
quiet engine that earns cosmetic variants.** Every mechanic below is care-framed, not
threat-framed. The Curator *saved you a record*; it never *guilts* you.

---

## 1. Core mechanic: the pressing state

Each `DailyEntry` gains a **derived** display state. It is computed, never stored, from
data the app already tracks (`checkInDays`, `CatchUp`, `CatchUpLog.heardEntryIDs`). No
backend change, no migration.

### New type: `PressingState`

```
enum PressingState {
    case pending      // today's entry, not yet listened — record on the counter
    case mint         // listened on its own day — clean sleeve, full credit
    case secondhand   // caught up within the CatchUp window — worn sleeve, "used copy"
    case missing      // window expired, never heard — empty sleeve, permanent gap
}
```

### Derivation rule (single source of truth)

Put this next to `CatchUp` (same file or a sibling) so the window constant is shared.

- `pending`  — `calendar.isDateInToday(entry.date)` AND not yet heard today.
- `mint`     — the entry's day is in `checkInDays` (user opened the app that day) AND
               the entry was heard. Use `heardEntryIDs` plus the existing
               `heardEntryID` AppStorage for today's same-day listen.
- `secondhand` — entry's day NOT in `checkInDays`, but `entry.id` is in
               `heardEntryIDs` (caught up later). Independent of the 7-day window:
               once you rescue it, it stays secondhand forever.
- `missing`  — entry's day NOT in `checkInDays`, NOT in `heardEntryIDs`, AND the day is
               older than `CatchUp.windowDays`. Before the window closes it is still
               rescuable, so render it as `pending`-styled "still available" in the
               crate, not as a gap.

**Acceptance:** pure function, fully unit-tested with a fixed `asOf` date. Cases: heard
today, missed-but-rescued-day-3, missed-and-window-closed, future/pending. Mirror the
test style already used for `Streak.compute`.

---

## 2. Today — the collection moment (highest priority for "satisfying")

This is the dopamine peak of the app and the thing that decides whether users return
tomorrow (peak-end rule). Spend real polish budget here before anywhere else.

**The animation**, fired when the listening ceremony completes (the existing
`ListeningView` completion handler, where `heardEntryID` is already set):

1. The album art (already on screen) shrinks and settles onto a vinyl disc that spins
   up briefly. Reuse `ArtworkPalette` so the label color matches the art.
2. The disc slides into a sleeve.
3. The sleeve animates toward the Crate (Vault) tab in the tab bar, scaling down.
4. On arrival: a single `Haptics.thud()` (the "thunk"), the Vault tab badge ticks up,
   the collection count increments with a quick count-up.

Respect `reduceMotion` (the app already does this for the archetype reveal): degrade to
a clean crossfade + the same haptic + count-up.

**Curator handoff (pre-listen):** before listening, Today shows the Curator presenting
the day's record ("I pressed you something for today"). Asset slot only; ship with a
text-only placeholder so the screen works before art exists.

**Acceptance:** animation runs once per first-listen of a day, never replays on
re-open, honours `reduceMotion` and `Haptics.isEnabled`, and the Vault badge + count
update live (they already recompute from observed state).

---

## 3. Vault → the Crate

Rename the surface to the Crate in copy (not the type names yet — leave that for the
rename pass). Two presentations, toggle between them; the calendar already exists so
keep it.

**Crate view (new default):**
- Horizontal flip-through of sleeves, newest first, with a slight 3D tilt as cards pass
  center (the crate-digging gesture). `VaultViewModel` already returns
  `publishedHistory()` newest-first; no data change.
- Month dividers like genre dividers in a shop ("June 2026").
- Pressing state is legible at a glance:
  - `mint` — clean sleeve, crisp art.
  - `secondhand` — worn corners + a small "2nd pressing" stamp.
  - `missing` — empty/dimmed sleeve, no art, faint "missed" mark. This is the only
    "loss" surface and it must read as *gentle*, not punitive.
  - rescuable (missed but within window) — normal art with a subtle "still available"
    affordance that opens the listen flow.

**Calendar view:** keep the existing `CalendarMonthView`; stamp days with pressing
state colors. Keep reactions stamping as-is.

**Acceptance:** flip-through is 60fps on a mid-tier device, state styling is driven
solely by `PressingState`, calendar toggle preserved, missed-drop catch-up still clears
the badge (it already does via `CatchUpLog`).

---

## 4. Favorites → the Wall (identity + growth loop)

Favorites becomes the display wall: framed records, mounted on the existing
`favoritesBackground` gradient.

- Drag-to-rearrange (persist order; `FavoritesStore` currently stores a `Set` — add an
  ordered array alongside it, keep the Set for fast `isFavorite` checks).
- Tapping a frame opens the entry; long-press to reframe/remove with `Haptics.thud()`.
- The share card (you already have `ShareCard` / `WrappedShareCard`) renders the Wall,
  not a stat line. People screenshot identity, not numbers — this is the organic
  acquisition loop. Make the Wall share card genuinely beautiful.

**Acceptance:** order persists across launches, optimistic toggle behavior preserved,
share card exports the Wall at high resolution.

---

## 5. Streak → the quiet variant engine

Keep `Streak.swift` exactly as-is computationally. Change only its role and rendering.

- **Demote the number.** The current run stays as the small toolbar badge already in
  `TodayView` — restyle the flame as a small spinning 45. It is not the hero.
- **Hero number is the collection count** (count of `mint` + `secondhand` entries),
  shown on the Crate and Wall.
- **Runs earn pressing variants** (cosmetic only):
  - 7-day run → that week's record mints in a colored pressing.
  - 30-day → gold pressing.
  - 100-day → splatter.
  Map these to the existing `Streak.milestones`.
- **Variable-ratio surprise:** ~1-in-20 days, the day's record is a "limited pressing"
  (special label/foil), independent of streak. This is the strongest habit mechanic in
  existence and costs only art variants. Keep odds tunable behind a constant.
- **Breaking a run removes nothing.** It only pauses progress to the next variant.
  Frame as opportunity cost, never loss. `Streak.best` survives as a "longest run" stat
  in Insights/Wrapped.
- Keep `SharedStreak.publish` and the widget working; the widget can show collection
  count as primary and the run as secondary.

**Acceptance:** no streak reset ever destroys collected records; variants are purely
cosmetic; `best` preserved; widget still updates.

---

## 6. The Curator (mascot) integration points

Code-side, the mascot is a set of **named asset slots + a copy layer**. Define an enum
of moods so the artist's deliverables map 1:1 and the app works with placeholders.

```
enum CuratorPose {
    case presenting    // Today, pre-listen: "pressed you something"
    case holding       // notification / at-risk: "held one behind the counter"
    case celebrating   // milestone / variant earned
    case shrug         // missed window: gentle, not disappointed
    case idle          // empty states
}
```

- All notification copy and milestone copy routes through one `CuratorVoice` source so
  tone stays consistent (warm record-shop owner; care-based scarcity; never guilt).
  Existing `ReminderCopy.swift` is the place to anchor this.
- Ship every slot with a text/SF-Symbol placeholder. Art is a drop-in later.

**Acceptance:** every Curator surface renders correctly with placeholders; no hard
dependency on final art to build, test, or TestFlight.

---

## 7. Monetization (build last, after the loop is validated)

Free forever, no ads: the daily drop, the Crate, the Wall, basic insights.

Premium tier (record-club framing, e.g. "the Club"):
- **Back-catalog collecting** — drops from before the user joined. Doubles as the
  new-user cold-start fix (empty crate problem).
- **Wall/shelf themes** and **premium variant styles**.
- **Deeper insights / extended Wrapped.**
- **Vacation hold** — free but limited (e.g. 1–2 per quarter); the Curator "holds your
  records." Extra holds are a paid convenience.

**Hard line, never cross:** do not sell streak repair, and do not sell the ability to
fill a `missing` sleeve. The gaps must mean something or the whole premise collapses.

---

## 8. Build order (for Claude Code)

1. `PressingState` + derivation + unit tests. *(pure logic, zero UI risk)*
2. Today collection-moment animation + Curator placeholder handoff.
3. Crate flip-through (Vault), state styling, calendar toggle.
4. Wall (Favorites) ordering + share card.
5. Variant engine + variable-ratio surprise + streak demotion.
6. Curator voice/pose layer with placeholders.
7. Monetization scaffolding (gated, off by default).
8. **Rename pass — last.** Display name, copy, bundle ID decision, asset swap.

Each phase is independently shippable and leaves the app in a working state.

---

## 9. Open questions to resolve before/while building

- Collection count definition: do `secondhand` records count toward the hero number?
  (Recommended yes — rescued still counts, only `missing` is a gap.)
- Should `missing` sleeves be hideable by the user, or always visible as honest history?
  (Recommended always visible; that honesty is the identity.)
- Variant rarity odds and which milestones map to which colorways (needs the artist's
  variant set defined first).
