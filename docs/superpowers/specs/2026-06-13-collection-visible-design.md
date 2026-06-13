# Make the Collection Visible — Design Spec

**Date:** 2026-06-13
**Status:** Approved for planning
**Builds on:** `2026-06-13-listen-tracking-foundation-design.md` (shipped). That phase
added `ListenStatus` and `ListensStore` (`collectionCount`, `status(for:)`,
`heardAt`) but nothing in the UI reads them yet — the engine is invisible. This
phase surfaces it. **No new assets, no reordering, no backend changes.**

---

## 0. Thesis: two surfaces, two gestures

The collection shows up in two places that must feel *different* so they don't
compete:

- **Vault = the Crate.** Everything collected, chronological, functional — where
  you dig and catch up. Rich with artwork, but a *working crate*, not a showcase.
  Opens with a **quiet** count, not a proud wall.
- **Favourites = the Wall.** The hearted subset, framed and displayed — a proud
  "these represent me." This is the showcase; the Vault must not encroach on it.

Same material (album art), opposite feeling. That split resolves the redundancy
risk: a big album mosaic in the Vault would turn the archive into a second
showcase, so the Vault stays textured-but-quiet and the Wall owns "proud."

---

## 1. Shared building block: `SleeveView`

One reusable view renders an entry's artwork with its `ListenStatus` treatment,
so state reads consistently everywhere and there's a single place to tune it.

```
SleeveView(entry: DailyEntry, status: ListenStatus, size: CGFloat)
```

| status | treatment |
|---|---|
| `heardSameDay` (mint) | full-colour artwork, clean |
| `caughtUp` (secondhand) | full-colour + small "2nd" stamp, bottom-trailing corner |
| `missed` | artwork **desaturated + dimmed** (≈grayscale, ~0.4 opacity) + faint mark — gentle, not punitive (decision M-A) |
| `rescuable` / `unheard` | full-colour, clean (still available) |

- Status comes from `env.listensStore.status(for: entry)`.
- Artwork is the existing `entry.albumArtURL` (AsyncImage as elsewhere); the
  "2nd" stamp and dim are SwiftUI overlays/modifiers — no assets.
- **Acceptance:** the four treatments are visually distinct; `missed` reads
  faded, never as an empty/scolding box; reused by both the Vault crate grid and
  the calendar legend.

---

## 2. Vault — the Crate

### 2a. Hero → quiet count (layout B)

A modest card **above** the retained catch-up hero (do not replace the catch-up
hero — it's the rescue affordance):

```
Your collection
147 records · 12 this month
```

- `147` = `ListensStore.collectionCount` (rows with a `heard_at`; i.e.
  `heardSameDay` + `caughtUp`).
- `12 this month` = a new `ListensStore.collectedThisMonth(asOf:calendar:)` —
  count of `heardAt` values falling in the current calendar month.
- Remove the existing published-total trivia line in `calendarSection`
  (`"\(entries.count) songs · \(entriesThisMonth) this month"`) so there is one
  *personal* number, not a competing published-total.

### 2b. Body → crate texture

- The **Recent picks** section becomes a grid of recent entries (newest first)
  rendered through `SleeveView`, so mint / caught-up / missed texture is visible
  while browsing. Missed entries appear here **dimmed** (not hidden) — the crate
  is the honest timeline; the count only tallies collected ones.
- `VaultAllSongsView`'s search rows adopt the same `SleeveView` treatment.

### 2c. Calendar stamped by state

`CalendarMonthView` gains a way to colour each day by `ListenStatus` (pass a
`status(for:)` closure or the `heardAt` map alongside the existing `reactions`):
teal = mint, amber = caught up, dashed outline = missed, blank = no entry / not
yet. Existing reaction stamping is preserved.

**Acceptance:** hero shows the live `collectionCount`; the crate grid + calendar
re-render from observed `ListensStore` state (catching up flips a sleeve from
dimmed → vivid live); the catch-up hero is unchanged.

---

## 3. Favourites — the Wall (display case, layout W2)

Record-shelf showcase of hearted entries on the existing `favoritesBackground`
gradient:

- Rows of framed sleeves sitting on shelf ledges (a divider line under each row),
  with artist/title captions — the proud "representation of me."
- Order: newest-hearted first **by entry date** (no stored hearted-date and no
  reordering this phase, so `FavoritesStore` stays a `Set` — no backend change).
- Tapping a frame opens the entry (existing entry-detail flow).
- Favourites resolve from `FavoritesStore.ids` via `EntryService` (confirm
  `FavoritesView`'s current resolution during planning).

**Acceptance:** hearted records render as a framed shelf wall; tapping opens the
entry; un-hearting removes it live (optimistic, as today); empty state reads as
an invitation, not a void.

---

## 4. Streak — minimal, detached, once-a-day flare

Keep `Streak.swift` computation untouched; change only presentation and add one
flourish.

- **Detach from settings.** Today, the settings gear and the streak badge are
  both `topBarLeading` (TodayView.swift:59 and :75), so they read as one cluster.
  Move the streak to the **trailing** group (ahead of the live-listeners badge),
  leaving settings alone on the leading side.
- **More minimal.** Drop the `glassPillStyle` chrome in the resting state:
  render a small flame glyph + monospaced count in a low-emphasis (secondary)
  style, smaller than today. The milestone-day emphasis (tint) may remain only on
  milestone days.
- **First-extension-of-the-day flare.** When today's check-in first makes the
  streak alive (`isAliveToday` becomes true and we haven't flared today), play a
  brief SwiftUI flare on the flame (scale pulse + a quick radial flourish drawn
  in SwiftUI — no asset) plus a light `Haptics`. Once per day.
  - Guard with a pure, testable helper, mirroring the existing milestone guard
    (`lastCelebratedStreakMilestone`): `StreakFlare.shouldFlare(lastFlareDay:
    isAliveToday: asOf:) -> Bool`, persisted via an AppStorage day-stamp.
  - Respect `reduceMotion` (degrade to a simple opacity fade, same haptic) and
    `Haptics.isEnabled`.

**Acceptance:** streak no longer sits beside the settings gear; resting state is
visibly lighter; the flare fires exactly once on the first daily extension,
never replays on re-open the same day, and honours `reduceMotion`/`Haptics`.
The spec's "flame → spinning 45" restyle stays **deferred** (an art decision).

---

## 5. Scope boundaries

**In scope:** `SleeveView`; the Vault count hero (B) + `collectedThisMonth`;
crate-textured recent/all-songs lists; calendar state stamps; the Favourites
shelf Wall (display-only); the streak relocation + minimal restyle + daily flare.

**Deferred (downstream, not here):** the full crate-dig flip-through (3D tilt
browse), drag-to-rearrange on the Wall (needs a stored order / backend column),
the streak→45 restyle, the Today→Vault collection-moment animation, pressing
variants, the Curator.

---

## 6. Testing

Swift Testing (`@Test`/`#expect`), new tests appended to an already-registered
file to avoid manual pbxproj registration.

- `ListensStore.collectedThisMonth` — fixed `asOf`; rows in/out of the current
  month counted correctly. Pure-ish (store + injected calendar/now).
- `StreakFlare.shouldFlare` — fires when alive-today and not yet flared today;
  not when already flared today; not when not alive. Fixed `asOf`, mirrors
  `ListeningCeremony`/`Streak` test style.
- `SleeveView` status→treatment mapping, calendar stamping, and the Wall layout
  are visual — verified by building + manual check in the simulator.

---

## 7. Resolved questions

- **Does the Vault feel barren without a mosaic?** No — richness comes from the
  state-textured crate grid + colour calendar (a working crate), distinct from
  the proud Wall.
- **Two numbers competing?** No — the published-total trivia line is removed; the
  hero's personal `collectionCount` is the only number.
- **Wall order without reordering?** Newest-hearted-first by entry date,
  deterministic, no backend.
- **Streak placement?** Trailing group, separated from settings; resting state
  minimal; celebratory only on the first daily extension via the flare.
