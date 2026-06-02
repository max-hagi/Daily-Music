# Insights as a Taste Mirror — Design Spec

- **Date:** 2026-06-02
- **App:** Daily Music (SwiftUI + Supabase)
- **Status:** Approved concept; archetype names TBD by user; ready for implementation plan.
- **Supersedes:** the current favorites-genre archetype Insights tab.

## 1. Goal & philosophy

The Insights tab is a **mirror, not a recommender**. It does not suggest what to
play next; it reflects back what the user's own choices reveal about them —
self-discovery.

**The one rule (the honesty guardrail):** every number on screen traces back to a
real, human-entered fact about a song the user actually chose. No AI, no scoring
model, no recommendations, no fabricated signal (this is why the old "discovery
mix" waveform and hardcoded "Pop Perfectionist" were removed). What we *do* is
**transparent arithmetic** — counting how a user's yes/no judgments distribute
across hand-tagged song attributes, and surfacing what stands out.

### Guardrails (must hold for every insight)
1. Never show a category the user hasn't rated into.
2. Never guess a missing tag — an untagged song is silently excluded from that
   dimension's math.
3. Every claim displays its underlying count ("you keep 9 of 11").
4. No fabricated visuals — every bar/number reflects a real count.
5. An "over-index" claim requires a minimum sample, or it stays "forming."

## 2. The personal signal (what's actually personal)

Everyone hears the **same** daily song, so the shared catalog says nothing
personal. The only personal data is what the user *does* with each song:

- **👍 / 👎 rating** — the **everyday taste judgment**, low bar, intended for (potentially)
  every song. This is the primary input for the whole mirror. Captures **negatives**,
  which are as revealing as positives and ~10× denser than favorites over a year.
- **❤️ favorite** — the curated "this one's a keeper" shelf. Stays exactly as-is,
  powering Vault/Favorites. **Not** the mirror's input.
- **🔥❤️😌💫 reactions** — left unchanged. At most, one optional honest line
  ("Your most-used reaction is 😌"). Not core to this spec.

A rating is **three-state**: like / dislike / none. Tapping the active state again
clears it.

## 3. Song tag schema (curation-time, in Supabase)

Optional columns added to `daily_entries`, all decode-safe like `genre` already
is (`decodeIfPresent`, default `nil`). Tagged by hand in the Supabase table editor.

| Tag | Type | Notes |
|---|---|---|
| `genre` | `text` | already exists |
| `year` | `int` | release year; decade is derived (`year/10*10`) |
| `mood` | `text` | one of the fixed Mood set below |
| `energy` | `int` (1–5) | arousal axis: 1 = intimate, 5 = explosive |
| `theme` | `text` | one of the fixed Theme set below |
| `language` | `text` | e.g. "English", "French"; default treat blank as English |

The fixed Mood/Theme values are mirrored by Swift enums (display name + SF Symbol
+ color) so tag values, validation, and chart labels share **one source of truth**.

### Mood vocabulary (9) — valence/flavor axis (energy carries arousal)
Grounded in Thayer/Russell's circumplex, the GEMS-9 scale, and AllMusic's mood clusters.

`Euphoric`, `Joyful`, `Tender`, `Serene`, `Dreamy`, `Nostalgic`, `Melancholy`,
`Defiant`, `Dark`.
*Optional spares (not in v1 unless wanted): Yearning, Playful, Anxious.*

### Theme vocabulary (10) — what the song is *about*
Grounded in common "most popular song themes" sources.

`Love & Romance`, `Heartbreak`, `Longing & Desire`, `Loneliness`,
`Memory & Nostalgia`, `Freedom & Escape`, `Empowerment & Self-Worth`,
`Rebellion & Protest`, `Coming of Age`, `Hope & Perseverance`.
*Optional spares: Celebration, Loss & Mortality, Faith, Wanderlust.*

> Tagging note — keep mood vs theme distinct: mood `Nostalgic` = it *sounds*
> wistful; theme `Memory & Nostalgia` = it's *about* the past. They can co-occur
> or appear independently.

### Dimensions summary
- **Categorical** (distribution + standout): `mood`, `decade`, `theme`, `genre`, `language`.
- **Scalar** (lean + band standout): `energy`.

## 4. The data the user generates

### New table `song_ratings`
```sql
create table song_ratings (
  user_id   uuid not null references auth.users(id) on delete cascade,
  entry_id  uuid not null references daily_entries(id) on delete cascade,
  value     smallint not null check (value in (-1, 1)),  -- 1 = 👍, -1 = 👎
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, entry_id)
);
alter table song_ratings enable row level security;
create policy "own ratings" on song_ratings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```
- A 👍/👎 tap **upserts** `(user_id, entry_id, value)`.
- Re-tapping the active value **deletes** the row (→ "none").

### New tag columns
```sql
alter table daily_entries add column if not exists year     int;
alter table daily_entries add column if not exists mood     text;
alter table daily_entries add column if not exists energy   int;  -- 1..5
alter table daily_entries add column if not exists theme    text;
alter table daily_entries add column if not exists language text;
```

`favourites` and `reactions` tables are unchanged.

## 5. The calculation — `TasteMirror` (pure, deterministic)

Input: the list of songs the user has rated, each as `(DailyEntry tags, value ∈ {+1,-1})`.
No I/O — a pure function over that list, so it is fully unit-testable.

**Overall like-rate** = `count(👍) / count(👍 + 👎)`. This personal average is the
bar every category is measured against (we do **not** need a catalog baseline).

For each **categorical** dimension, group rated songs by their tag value and compute:

```
 like-rate(category) = 👍(category) / ( 👍(category) + 👎(category) )

 dominant   = category with the most 👍 (raw volume)
 over-index = category whose like-rate exceeds the user's overall like-rate
              by >= OVER_INDEX_MARGIN, among categories with >= MIN_PER_CATEGORY ratings
 skip       = category with the lowest like-rate (below overall), same min sample
```

For **energy** (scalar): `lean = mean(energy of 👍 songs)`, mapped to a label
(`<=2.0` Intimate, `2.0–3.5` Balanced, `>=3.5` Explosive), plus a 3-band
(Low 1–2 / Med 3 / High 4–5) like-rate mini-breakdown computed like a categorical
dimension.

### Worked example (illustrative)
User has rated 30 songs: 18 👍 / 12 👎 → **overall like-rate = 60%**.

Dimension = Mood (rated songs grouped by tag):
```
 mood          👍   👎   total  like-rate   vs 60%
 Melancholy     9    2    11      82%       +22  ↑ stands out
 Tender         4    1     5      80%       +20  ↑
 Dreamy         2    2     4      50%       −10
 Euphoric       2    5     7      29%       −31  ↓ skip
 Defiant        1    2     3      33%       −27
                18   12   30
```
- dominant → Melancholy (9 👍)
- over-index → Melancholy (+22, ≥3 rated)
- skip → Euphoric (29%)

The same runs on decade/theme/genre/language/energy.

### Thresholds (named constants, one place, tunable)
```
 MIN_PER_CATEGORY     = 3   // a category needs >=3 ratings to be eligible for over-index/skip
 OVER_INDEX_MARGIN    = 10  // percentage points above overall like-rate to "stand out"
 MIN_RATED_DIMENSION  = 10  // overall ratings before a dimension's tile/section unlocks,
                            //   AND the dimension needs >=2 categories each with >=MIN_PER_CATEGORY
 MIN_RATED_ARCHETYPE  = 20  // overall ratings before the hero archetype resolves
```

## 6. Archetype synthesis (names TBD — identifiers only for now)

The hero name is **not** scored — it's a lookup (`resolve`) on the user's top
standouts, with graceful fallback so there's always a sensible result once
`MIN_RATED_ARCHETYPE` is met.

**Precedence:**
1. `(top mood standout, top decade standout)` — specific combos
2. else `(top mood standout, top theme standout)` — specific combos
3. else `(top mood standout)` — mood-only default
4. else `BALANCED_DEFAULT`

Each catalogue entry has a stable **identifier** (used as the displayed title for
now), a color gradient, and an SF Symbol. The user will replace each identifier
with a real name later; the `id` never changes so renames are cosmetic.

### Starter catalogue (identifiers — rename the `title` later)
```
 id                      matches when…                         (modifier source)
 ──────────────────────────────────────────────────────────────────────────────
 MELANCHOLY_1980S        top mood = Melancholy & top decade = 1980s   (decade)
 MELANCHOLY_DEFAULT      top mood = Melancholy                        (mood-only)
 DEFIANT_PROTEST         top mood = Defiant & top theme = Rebellion   (theme)
 DEFIANT_DEFAULT         top mood = Defiant                           (mood-only)
 EUPHORIC_2010S          top mood = Euphoric & top decade >= 2010s    (decade)
 EUPHORIC_DEFAULT        top mood = Euphoric                          (mood-only)
 SERENE_DEFAULT          top mood = Serene                            (mood-only)
 DREAMY_DEFAULT          top mood = Dreamy                            (mood-only)
 NOSTALGIC_DEFAULT       top mood = Nostalgic                         (mood-only)
 TENDER_DEFAULT          top mood = Tender                            (mood-only)
 JOYFUL_DEFAULT          top mood = Joyful                            (mood-only)
 DARK_DEFAULT            top mood = Dark                              (mood-only)
 BALANCED_DEFAULT        no clear standout (catch-all)                (—)
```
The hero "why it's you" line is **templated from the real standouts**, e.g.
`"Because you keep <mood> <decade> songs more than anything else (<rate>% yes vs <overall>% overall)."`

## 7. Screen layout (top → bottom)

1. **Hero** — synthesized archetype: identifier-as-title, SF Symbol,
   archetype-colored gradient (consistent with current design; **not** album art),
   and the cited "why it's you" line. Before `MIN_RATED_ARCHETYPE`: a *forming*
   state — "Your portrait takes shape at 20 ratings — N to go."
2. **"What stands out" strip** — up to 4 tiles, each one honest sentence + number
   (top mood, the era you live in, energy lean, the theme you return to). Each tile
   unlocks independently (progressive reveal); locked tiles read "rate N more."
3. **Breakdown (the proof)** — one collapsible section per dimension; each a
   horizontal **like-rate bar chart** (category · count · rate) with the
   over-indexed category flagged "↑ stands out" and the skip marked. Where the user
   digs into *why*.
4. **Wrapped button** — keep the existing "See your month" → `WrappedView`.

Progressive reveal everywhere: nothing shows until its threshold is met; locked
slots show a short "rate N more" prompt rather than empty space.

## 8. Today screen change

Add an unobtrusive **👍 / 👎 control** near the existing play/reaction area that
records a rating (upsert/toggle-to-none). ❤️ favorite stays a separate control and
keeps its current meaning. Keep visual weight light so the screen doesn't feel like
a rating chore.

## 9. Components / files

New / changed Swift units (each one purpose, testable in isolation):

- `Models/DailyEntry.swift` — add optional `year, mood, energy, theme, language`;
  add computed `decade: Int?`. Supabase row mapping uses `decodeIfPresent`.
- `Models/MusicTaxonomy.swift` (new) — `enum Mood`, `enum Theme` (raw value = stored
  string; display name, SF Symbol, color). Single source of truth for tag values,
  validation, and labels. Energy band helper here too.
- `Services/RatingService.swift` (new) — protocol + `MockRatingService`:
  `rate(entry:value:)`, `clear(entry:)`, `myRatings() -> [UUID: Int]`.
- `Services/Supabase/SupabaseRatingService.swift` (new) — upsert/delete/select on
  `song_ratings`.
- `Models/TasteMirror.swift` (new) — **pure engine**. Input: `[(DailyEntry, Int)]`.
  Output: `Mirror` (per-dimension breakdowns with dominant/over-index/skip, overall
  like-rate, energy lean, resolved archetype, per-insight lock states). No I/O.
- `Models/TasteProfile.swift` — re-key catalogue to identifiers; `resolve(standouts:)`
  per §6 precedence; drop the genre-only/favorites-based resolution.
- `ViewModels/InsightsViewModel.swift` — rebuild around `RatingService` + `EntryService`
  → `TasteMirror`; expose sections + lock states. No longer favorites-driven.
- `Views/InsightsView.swift` — rebuild: hero / standout strip / breakdown / wrapped.
- `Views/TodayView.swift` + `ViewModels/TodayViewModel.swift` — add 👍/👎 control and
  record rating (likely a small `RatingBar` component alongside `ReactionsBar`).
- `App/AppEnvironment.swift` — register `ratingService` in `.mock()` and `.live()`.
- Tests: `TasteMirrorTests` — unit-test the math (dominant, over-index margin, min
  sample, energy lean, archetype precedence, lock thresholds) against fixed inputs.

## 10. Testing

`TasteMirror` is pure, so it is the primary test surface (TDD candidate): feed
fixed `[(entry, value)]` arrays and assert the breakdowns, standouts, overall
like-rate, energy lean, archetype id, and lock states. View-model and Supabase
layers verified in the simulator with mock data, per existing project practice.

## 11. Deferred (YAGNI)

- Catalog-baseline over-indexing — personal like-rate is enough and simpler.
- Reaction-derived and time-of-day/check-in "rhythm" insights.
- MusicKit auto-tagging of genre/mood/energy — revisit when a paid Apple Developer
  account exists; until then all tags are hand-authored.
- Sharing the archetype via `ShareCard` — possible later hook, not in this scope.

## 12. Open items for the user

- **Archetype names** — rename each identifier's `title` in the catalogue.
- Confirm the final **Mood (9)** and **Theme (10)** sets (spares listed if you want swaps).
- Threshold tuning (`MIN_RATED_*`, `OVER_INDEX_MARGIN`) once real data exists.
- A short **tagging cheat-sheet** for curation (what each mood/theme means) — can be
  generated from `MusicTaxonomy.swift` once finalized.
