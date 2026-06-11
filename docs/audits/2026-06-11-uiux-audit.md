# App-wide UI/UX audit — 2026-06-11

Principles applied (from the design-principles discussion, adapted to iOS):
hierarchy by size/position, choice overload, spacing/typography/radius/shadow
consistency, semantic color, interaction states, micro-interactions. Screens
reviewed: Today, Vault, Favorites, Insights (just redesigned), Friends,
Settings, EntryDetail, Listening, Wrapped, onboarding + design system
(`Theme.swift`, `Styles.swift`).

## What's already strong (don't churn)

- `Theme.Spacing` (4/8/16/24/32) exists and is used widely — the 4-pt grid is
  mostly respected.
- Glass language centralized (`glassCardStyle`, `glassPillStyle`,
  `glassIconButtonStyle`); pressed states everywhere via
  `PrimaryActionButtonStyle` / `PressableCardButtonStyle` / glass
  `.interactive()`.
- Haptics centralized and settings-gated; Reduce Motion respected in every
  animated view checked.
- Every screen has loading/empty/failed states (`LoadStateView`,
  `ContentUnavailableView` with retry); icon-only buttons carry
  `accessibilityLabel`s.
- Micro-interactions are genuinely good: numeric `contentTransition` on live
  counters, undo banner with auto-dismiss, streak milestone haptic fired once,
  pulsing live badge.
- Semantic color is sane: red = live, orange = streak, green/red =
  accept/decline, pink = favorites.

## Findings

### P1 — Hierarchy & choice overload (the motivating principle)

**1. "Everything is a hero."** Four screens open with a near-identical
full-width gradient hero card (big icon badge top-left, eyebrow top-right,
~36 pt heavy title, subtitle): Vault (`vaultHero`), Favorites (`hero`),
Insights (archetype hero), FriendInsights. When every screen shouts, none
does. The archetype hero has earned its size (it's the screen's point); the
Favorites hero spends ~200 pt of prime space announcing a single number
("12 favorites").
*Fix:* keep the hero treatment only where the hero IS the content (Insights,
Vault's data-driven catch-up). Shrink Favorites' to a compact header row or a
navigation-bar subtitle.

**2. Vault stat cards are high-weight, low-value.** Two metric cards with
32 pt heavy numbers show "N songs" and "N this month" — trivia, displayed at
the same visual rank as the calendar and recent picks
([VaultView.swift:197](Daily Music/Views/VaultView.swift)).
*Fix:* demote to one quiet line (e.g. under the calendar title: "214 songs ·
9 this month") and let the catch-up hero + calendar own the screen.

**3. Friends requests row typography wobble.** The whole request row inherits
`.font(.title3)` while names use `.headline` — accept/decline icons render
larger than intended ([FriendsView.swift:92](Daily Music/Views/Friends/FriendsView.swift:92)).
Minor, but it's the only screen where row scale jumps.

### P2 — Token consistency

**4. Typography ramp is bypassed.** 30+ distinct hardcoded
`.system(size:)` values across Views (9–64). `Font.dmDisplay/dmTitle/
dmHeadline/dmNumber` exist but screens hand-roll their own 28/32/34/36-pt
heavies. Fixed sizes also ignore Dynamic Type (accessibility).
*Fix:* extend the ramp (`dmHero` 36, `dmStat` 32, `dmCardTitle` 20…), prefer
`.system(.textStyle, design: .rounded)` relative styles where feasible, and
migrate screen by screen.

**5. Corner radii: 14 distinct values (2–28).** `Theme.Radius` defines only
`card=22` and `small=12`, and most call sites hardcode literals (16, 18, 20,
26, 28…).
*Fix:* expand the scale — chip 8, control 13, row 18, card 22, hero 28 —
and migrate. Rows alone use 16/18/20 interchangeably today.

**6. Brand gradients live inline.** Favorites' pink hero gradient and Vault's
teal-orange hero gradient are raw `Color(red:…)` literals duplicated into
their shadow colors ([FavoritesView.swift:153](Daily Music/Views/FavoritesView.swift:153),
[VaultView.swift:161](Daily Music/Views/VaultView.swift:161)). Backgrounds for
the same screens already live in `Theme.Surface` — heroes should too.

**7. Shadows are ad hoc.** Radii 7–36 with assorted opacities. Mostly fine in
feel, but undefined: add `Theme.Shadow` (one soft card shadow, one accent
glow) per the "more blur, less opacity, never the focal point" rule.

**8. Pill insets repeated.** Every glass pill hand-rolls
`.padding(.horizontal, 11).padding(.vertical, 7)` (streak badge, live badge,
listened badge). Move the insets into `GlassPillModifier` so the pill is one
call.

### P3 — Structure & component hygiene

**9. Duplicated hero scaffold** (same finding as #1, structural angle): the
icon-badge/eyebrow/title/subtitle-on-gradient layout is hand-rolled ≥4 times.
Extract a `HeroCard` component; consistency then comes free and the size
hierarchy is enforced in one place.

**10. `EntryDetailView.swift` is 706 lines / ~47 members** — the immersive
two-zone layout, the action cluster, and the shared headers belong in
separate files. It's the file most likely to be edited next, and the hardest
to hold in context.

**11. Button vocabulary drifts.** Primary actions are sometimes
`PrimaryActionButtonStyle` (Wrapped button), sometimes `.borderedProminent`
(New-drop refresh, retry buttons). *Fix:* one rule — primary =
`PrimaryActionButtonStyle(tint:)`, secondary = `.bordered` with tint (the iOS
"ghost button"), destructive = role-based.

**12. Row chevron color drifts.** `EntryRow` uses `.tertiary`,
`VaultTintedEntryRow` uses palette accent, quiet rows use `.secondary` — pick
one (secondary) outside artwork-tinted contexts.

## Suggested fix batches (each independently shippable)

1. **Tokens** — extend `Theme` (type ramp, radius scale, shadow pair, hero
   gradients into `Theme.Surface`), move pill insets into `GlassPillModifier`.
   No visual change intended; pure consolidation. (Findings 4–8)
2. **Hierarchy pass** — `HeroCard` component; Favorites hero shrink; Vault
   stat demotion; Friends row font fix. (Findings 1–3, 9)
3. **Button + chevron vocabulary** — sweep to the single rule. (11, 12)
4. **EntryDetailView split** — mechanical refactor, no behavior change. (10)

Batches 1–2 deliver the visible payoff; 3–4 are hygiene.
