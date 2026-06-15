# Today Declutter + Earned Listening — Design

**Date:** 2026-06-15
**Status:** Approved design, ready for implementation plan
**Scope:** The Today tab only. Favorites redesign and Insights badges are separate efforts (their own specs).

## Goal

Make Today calm and legible at a glance, and make *collecting* a record something you earn by actually listening. Today currently stacks six control clusters in the one-viewport "song zone" plus four toolbar items; the journal peek and the Open-in row crowd each other at the bottom; and a record is marked collected (`markHeard`, which grades it **mint**) the moment the listening screen's advance button fires — so a song can be collected without hearing a note.

## Summary of decisions

1. **Earned listening.** A record collects as mint only after genuine playback; collection is decoupled from the "done / read story" button.
2. **No auto-ceremony.** The drop announces itself (existing daily reminder + an in-app blind pop-up). The user chooses to listen.
3. **Decluttered song zone (Direction A).** One quiet utility group around the title, a medium-prominent rating, a single evolving primary button, the journal peek alone at the bottom.
4. **Pull-down to listen/replay** replaces the headphones toolbar button.
5. **Streak** moves out of the toolbar into a chip beside the greeting.
6. **Collection state is visible** on Today's cover via the existing Vault sleeve treatment (pending → mint).

---

## 1. Earned listening (the integrity change)

**Rule:** a record collects as mint once the listener has accumulated **≥ `collectThresholdSeconds` (default 25s) of actual playback**, OR the clip reaches its natural end (covers previews shorter than the threshold) — whichever comes first.

- Introduce a single tunable constant (e.g. `ListenThreshold.collectSeconds = 25`). We expect to tweak it during testing.
- Track **accumulated playing time**, not raw scrub position — accumulate elapsed time only while `MusicPlayer.state == .playing`, so scrubbing the progress bar to the end can't fake a collect. Reaching `.finished` always satisfies the rule.
- `ListensStore.markHeard(_:)` stays exactly as-is (optimistic, first-listen-wins, no-op if already heard). What changes is **who calls it and when**: it is called from a playback-progress observer in `ListeningView` when the threshold is crossed — *not* from `onAdvance`.
- On crossing the threshold: fire `Haptics.success()` and animate the cover/sleeve from pending → mint (a small "locked in" moment). Respect Reduce Motion.
- Leaving the player early (advance button, swipe-to-dismiss, app backgrounded) no longer collects. The song simply stays uncollected; the user can come back and listen anytime.
- Re-listening an already-collected song never changes anything (`markHeard` is a no-op once heard). The threshold logic is skipped when the entry is already heard.

**Files:** `ListeningView.swift` (add accumulated-playtime tracking + threshold trigger; remove `markHeard` from the `onAdvance` path), `TodayView.swift` (its `ListeningView` trailing closure currently calls `markHeard` — remove that call; the closure just stops playback + dismisses), new `ListenThreshold` constant (small model file or alongside `ListeningCeremony`).

---

## 2. New-drop announcement (replaces the auto-opening ceremony)

The immersive listening screen no longer auto-opens when today's drop lands. Instead:

**Push (reuses existing local notifications).** `LocalNotificationService` already schedules a rolling 14-day daily reminder at the user's chosen time. Add a deep-link `userInfo = ["url": "dailymusic://today"]` to those reminder requests so tapping the reminder opens the app on the Today tab (the in-app pop-up then handles the rest). Routing follows the same path the monthly recap already uses (`AppPushDelegate` → `RootView.onOpenURL` → `MainTabView`). No remote push / APNs needed.

**In-app blind pop-up.** When the user lands on Today and today's drop is **uncollected**, present a pop-up *over* the song zone:
- Blind tease — the song stays hidden. Copy: date + "Your song of the day is ready" + a one-line "listen all the way to collect it" hint.
- Two actions: **Listen** (primary) → opens the player and begins playback (the artwork bloom *is* the reveal; the old separate "tap to reveal" intro stage is retired). **Maybe later** (secondary) → dismisses to the "before / not collected" song zone.
- Shows at most once per app session per drop. After "Maybe later," the persistent affordance is the song zone's "Listen to collect" button + pull-down; we don't re-nag on every Today visit in the same session.

**Retire the auto-open.** Remove the `onChange(of: loadedEntry?.id)` auto-open block and the `launchIntoCeremony` / `autoOpenDelay` path in `TodayView.swift`. `ListeningCeremony.shouldAutoOpen` / `autoOpenDelay` and `ListeningView.showsRevealIntro` become unused — remove or repurpose. (Day-one onboarding still flows into the first listen, but now via the pop-up's Listen action rather than an automatic full-screen takeover.)

**Files:** `TodayView.swift` (pop-up presentation + state, remove auto-open), `NotificationService.swift` (add deep-link url to daily reminders), new pop-up view (small private view, e.g. `NewDropPrompt`), `ListeningView.swift` (drop `showsRevealIntro` usage), `ListeningCeremony.swift` (clean up).

---

## 3. Decluttered song zone — Direction A

Replaces the current six-cluster stack (greeting → art → title+heart+info → big thumbs → reactions pill → nudge+Open-in row → journal dock) with, top to bottom:

1. **Greeting row:** "Hey {name} — today's song" + the **streak chip** (see §5), in the slot currently used by `preArtworkMessage`. `{name}` is the **onboarding-selected first name** — the same value onboarding greets with ("You're all set, Max"). Update `TodayView.listenerName` to take the first word of the session `displayName` (after stripping any email `@domain`), matching `OnboardingView.firstName`, so a full name like "Max Smith" greets as "Max".
2. **Cover** — album art rendered with the **sleeve treatment** (see §6), with a subtle pull-down cue above it (see §4).
3. **Title / artist row with flanking quiet utilities** — extends the existing `entryIdentityWithInlineControls`: ♡ keep on the left; ☺ react + ⓘ info on the right. Small, low-emphasis (they recede).
4. **Rating** — 👍 / 👎 at **medium prominence**: larger than the utility icons (~44pt target), centered with breathing room, standing on their own (no container). This is the main emotional action. *(Exact sizing to be tuned during testing.)*
5. **Evolving primary button** (see below).
6. **Journal peek dock** — unchanged in spirit, now alone at the bottom.

**Reactions** move from the separate inline `ReactionsBar` pill into the ☺ utility button (which already opens the reactions popover via `reactionButton`). The standalone `inlineReactionsBar` row is removed.

**The first-run rating nudge** ("Tune your Insights") is retained but re-anchored to point at the rating control (a one-time small callout), instead of stacking above the Open-in row.

### Evolving primary button

One full-width button whose meaning depends on collection state (replaces the `OpenInSection` row on Today):

- **Uncollected:** "▶ Listen to collect" (accent fill) with a thin progress bar showing accumulated listening toward the threshold. Tapping opens the player.
- **Collected (mint):** "Open in {default service}" (the current `OpenInSection` primary action, using the `settings.preferredStreamingService` default).

The visible **⋯ more-services menu is removed.** Alternate services remain reachable via **long-press** on the button (a context menu listing the non-default services) and inside the **ⓘ info sheet**. The save-to-library affordance stays available (in the collected state / info sheet) where `canSaveToLibrary`.

**Toolbar** is trimmed to: gear (leading) + **"N listening" live badge** (trailing). The **headphones button is removed** (replaced by pull-down + the Listen button). The share button continues to come from `EntryDetailView` when applicable.

**Files:** `EntryDetailImmersive.swift` (song zone composition: remove `inlineReactionsBar`; relocate nudge; swap `openInSectionWithRatingNudge` for the evolving button), `EntryActionCluster.swift` (utility sizing + rating sizing), `OpenInSection.swift` (remove visible ⋯; add long-press alternates; expose the "Open in default" action for reuse by the evolving button), `TodayView.swift` (toolbar trim).

---

## 4. Pull-down to listen / replay

A pull (overscroll) at the **top** of the song zone opens the listening player:
- A persistent cue at the very top: "⌄ pull down to listen" (uncollected) / "⌄ pull down to replay" (collected).
- The gesture lives at the top edge where there is no content above, so it does not fight the existing snap-scroll to the journal zone (that travels *downward* through content). Threshold ~80pt of pull, with a small haptic on trigger.
- For an uncollected drop, pull-down behaves like the Listen button (opens player; listening collects). For a collected drop, it replays.

**Files:** `EntryDetailImmersive.swift` (top cue + pull gesture on the `ScrollView` / song zone), `TodayView.swift` (wire the trigger to present the player).

---

## 5. Streak chip relocation

Move the streak out of the toolbar into the **greeting row** of the song zone. Preserve all existing behavior in `TodayToolbarStreakBadge` — the tap popover (goal-gradient + best run), the once-per-day flare, and the milestone success haptic — just rendered inline rather than as a `ToolbarItem`.

Because the song zone lives in the shared `EntryDetailView` (also used by Vault/Favorites), Today passes the streak chip in explicitly (e.g. an optional accessory alongside `preArtworkMessage`); Vault/Favorites pass nothing, so it only appears on Today.

The **"N listening" live badge stays in the toolbar** (it's "right now" context, confirmed with the user).

**Files:** `TodayView.swift` (build/pass the streak chip; remove the streak `ToolbarItem`), `EntryDetailView.swift` / `EntryDetailImmersive.swift` (accept + render an optional greeting-row accessory).

---

## 6. Cover sleeve treatment on Today

Render Today's cover through the existing `SleeveView` so collection state reads at a glance and Today speaks the same visual language as the redesigned Vault:
- Uncollected today's drop → pending treatment (accent border + peeking disc).
- Collected → mint treatment (clean sleeve + gloss), animated in at the collect moment (§1).

Use the entry's `ListenStatus` from `ListensStore.status(for:)`. (Today's drop is same-day, so collected = `.heardSameDay` = mint.)

**Files:** `EntryDetailImmersive.swift` (use `SleeveView` for the immersive cover), `SleeveView.swift` (reuse as-is; confirm it composes at hero size — there's already a 132pt preview).

---

## Edge cases

- **Drop not landed yet** → existing `NewDropIncomingView` empty state, unchanged. No pop-up.
- **Already collected on open** → no pop-up; song zone shows mint + "Open in" button; pull-down replays.
- **Partial listen then leave** → uncollected; pop-up may reappear next app session; the "Listen to collect" button persists in-session.
- **Notifications not authorized** → in-app pop-up still works; only the push tap-through is unavailable.
- **Guest / anonymous users** → unchanged; collection and rating still function as today.
- **Reduce Motion** → collect animation, flare, and pull cue degrade to non-animated equivalents.
- **Scrubbing to fake a listen** → prevented by accumulating time only while `.playing`.

## Testing

- `ListenThreshold` / accumulation logic: collects at ≥25s of playing time; collects on `.finished` for sub-threshold clips; does not collect on scrub-to-end without playback; no double-collect; no-op when already heard. (Pure-ish logic — unit test the accumulator/decision, mirroring the existing `ListeningCeremony` test style.)
- New-drop pop-up gating: shows when uncollected, hidden when collected, once-per-session after dismiss.
- Notification deep link routes to Today.
- Manual: full Today flow on device — pull-down, evolving button states, streak chip popover, long-press alternate services, collect micro-moment.

## Out of scope (future specs)

- Favorites redesign (records/sleeves, condition "quality", drag-to-rearrange).
- Insights badges / achievements.
