# Daily Music — Engagement & Monetization Strategy

**Date:** 2026-06-06
**Status:** Approved (brainstorming) — pending user spec review
**Scope:** Product/strategy design. Defines the engagement loop, the free/paid
line, the paid tier, the onboarding taste-seed, and a phased rollout. Code-level
implementation plans come later (per phase), each as its own spec → plan.

## Thesis (the whole strategy in two sentences)

1. **Engagement and monetization are one mechanism seen from two sides.** The
   same investment that makes someone return daily — the taste-mirror becoming a
   portrait of *them*, the keepers and reflections piling up — is exactly what
   makes the *archive* worth paying for. We are not bolting a paywall onto an
   engagement loop; we are charging for the deep end of the same loop.
2. **The slowness is the precondition for monetization, not the obstacle.** If
   every song were always available, the Vault would be worthless. One-song-a-day
   manufactures the scarcity that makes "the ones you let slip" worth paying to
   recover.

## North star (decided)

**Sustainable & pure.** Cover costs and support the curation; a bit of profit for
the creator's time. Not venture scale. For this audience (intentional,
anti-algorithmic, taste-cultivating), **purity is the conversion strategy** —
they reward authenticity and punish manipulation, so the ethical model and the
profitable model are the same model. No dark patterns, no manufactured FOMO, no
drip-paywalls.

## The product as a category

Daily Music is **a reflective practice that happens to use music as its medium** —
not a music app with journaling bolted on. Closer kin: Day One, a Calm, the Sunday
paper, a good Substack essayist. This category retains for years because it ties
to a user's sense of growth and self-understanding, not to entertainment that has
to out-shout TikTok. Consequence for the money frame: **we sell the preservation
and deepening of a personal reflective practice**, never "music access."

---

## Section 1 — The engagement spine (four "slow" engines)

Every engine runs on fuel a slow app has in abundance — none needs volume or
instant gratification. This is why the niche and the need for engagement are not
in tension.

1. **Anticipation** — the daily pull. You don't know today's song until you open
   it. A variable reward with a **hard once-a-day cap**: same neurochemistry as
   the infinite feed, opposite ethics. Replaces doomscrolling.
2. **Ritual / synchrony** — the shared now. Everyone hears the *same* song today
   (Durkheim's collective effervescence; the Wordle effect). "N listening today,"
   friends' reactions, the daily expiry all say *today is a shared event.* Pieces
   already exist (shared counts, friends).
3. **Identity accrual** — the mirror becoming you. Every rating/keeper/reflection
   deposits into the taste-mirror (endowment / IKEA effect). **This is also the
   monetization engine:** the more it is "yours," the more the full archive is
   worth unlocking to complete the picture.
4. **Micro-completion** — the daily small act. One satisfying bit of closure per
   day (rate, keep, react, reflect). Zeigarnik effect, but where the feed keeps
   the loop open forever, we offer *one clean completion a day.* You feel
   finished, not hungry. That feeling is the brand.

---

## Section 2 — The free experience (the sacred ritual)

**Governing principle:** the free tier is a *complete* reflective practice. We
never interrupt the daily moment to ask for money. The wall sits only at the
*edges* (deep past, power-browsing), never in the center. You cannot paywall the
enlightenment — that is the free gift that earns the trust that makes people pay.

**Free, forever, for every user:**
- **Today's drop** — curated 30s taste (fade, not cut) · full art · the
  **complete editorial essay** (never truncated, never gated).
- **Daily reflection (new)** — one optional prompt under the essay: *"What did
  this stir in you?"* Write a line or skip. Private. Becomes part of the vault.
- **Daily acts** — 👍/👎 rate · react · **❤️ keep** (one tap; kept songs live in
  the vault forever).
- **Listen out** — Open in their service (full track) · Add to Daily Playlist
  (full versions stack in their own library).
- **The mirror, unfolding** — free; first read by end of onboarding (the seed
  front-loads ~12 of the ~20 ratings the archetype needs), archetype ~a week of
  daily use later.
- **Their vault** — today + everything kept + their reflections.
- **The shared ritual** — listener count, friends, friends' reactions.

**Behind the line:** the *full* archive (every past entry, including un-kept
ones) · archive search/browse by mood/era/genre · patron depth (Section 3).

---

## Section 3 — The paid tier

### Pricing model (subscription AND one-time, both)
For this audience, subscription fatigue is high, so a one-time option can convert
*better* than recurring billing. Frame as a choice of relationship, not a trick.
- **Annual** — default ("2 months free"); the sustainable backbone.
- **Monthly** — low-commitment way in (optional; can add later).
- **Lifetime — "Founding Patron"** — one payment, yours forever; priced ~3–4×
  annual (not a fire-sale, or it eats recurring revenue); positioned as patronage
  ("you believed early"). Early lifetime sales = cash infusion + loudest
  evangelists; scarcity of "founding" status is itself the draw.

*Apple economics:* 30% yr1 / 15% after — but the **Small Business Program** drops
to 15% from day one while under $1M/yr (just enroll). Lifetime = a non-consumable
IAP, supported alongside subscriptions. Implement via **RevenueCat**.

### The anchor
**Full archive + search** (everything missed, browsable by mood/era/genre).

### Patron perks + sequencing (all four chosen; sequenced to validate before over-building)
- **Launch:** extended **curator notes** (bonus editorial per pick — pure writing,
  no new tech, all moat) + a simple **Founding-Patron badge** (trivial flag that
  makes the Lifetime tier emotionally real). Together they answer the only first
  question: *will people pay for the voice + the archive?*
- **Fast-follow (first months):** **longitudinal taste-mirror** — how taste
  shifted over months + reflection themes. Real engine work *and* meaningless
  until months of history exist, so it ripens on its own.
- **Seasonal (first year-end):** **year-in-music keepsake** — exportable journal
  of the year (songs + reflections) as a shareable artifact. Seeds exist in
  `WrappedView` + `ShareCard`. A gift-able re-engagement + conversion moment.
- **Phase 2/3:** the **contribution economy** (below).

This spreads a **monetization cadence across the whole year** (launch core →
deepen with data → seasonal keepsake → community), each beat a built-in
re-engagement/conversion moment. The cadence is itself a retention strategy.

### Contribution economy (best idea + most dangerous idea — staged to Phase 2/3)
- *Why powerful:* eases the solo one-a-day curation burden; co-creation is the
  deepest engagement (a featured pick bonds a user for life); "support with money
  **or** contribution" is the public-radio model and fits sustainable & pure.
- *Why dangerous:* the moat is the **singular editorial voice**. The instant the
  crowd picks the daily song, it becomes "just another playlist app."
- **The rule that protects the moat:** the **daily drop stays curator-only,
  forever.** Contribution is a *separate, secondary* surface — a patron may
  *submit* a song + a few lines *for the curator's consideration*; the curator
  still chooses and still writes. A featured contributor gets **credited**
  (status) and **comped** patron time ("contributors don't pay") — but featuring
  is a **scarce honor the curator grants**, never a free-access loophole anyone
  can farm. Needs a community + moderation, so **not** at launch.

---

## Section 4 — Cold-start onboarding (the taste-seed)

Lives **inside the existing wizard** (`OnboardingView`): after
`OnboardingHelloStep` (step 0, name), insert these as new steps, bump
`totalSteps`, reuse the visual pattern (heavy rounded 28pt title → secondary
subtitle → content), and keep them **skippable** so they never block (respects
"pure"). Personable and playful, using the person's name.

1. **A hello from the curator** (atmosphere, not data — the "warm welcome"). One
   screen, the curator's voice naming the philosophy up front (*"one song a day,
   with a story; no feed, nothing to catch up on, just today"*). Pre-frames the
   slowness as intentional before it can read as lacking (Cialdini commitment).
2. **"Let's find your starting frequency"** — ~6 playful **"this or that?"**
   rounds, each pairing two **real past entries** (covers, + a 30s taste once
   audio is wired). Tap the one that pulls you → writes a 👍 on the picked entry
   and a 👎 on the other to the existing **`song_ratings`** table. Honest signal
   that feeds the **existing `TasteMirror` engine — zero new logic.** Forced
   choice (not a grid) because the standout engine needs both directions to find
   over-indexing, and a quiz feels charming where "rate 1–5" feels like work.
   (Cover-grid is a viable faster fallback: tapped = 👍, untapped = 👎.)
3. **The payoff — an instant first read.** ~6 rounds ≈ 12 ratings, tripping the
   existing ~10-rating dimension threshold, so onboarding *ends* on a reveal
   (*"you lean nocturnal & a little melancholic 🌙 — let's see how it grows"*).
   Cold-start solved; archetype still unlocks ~a week in, so there's something to
   return *for*.

**Trojan horse:** the rounds are real vault entries, so onboarding is a guided
first walk through the archive — the taste-seed and the paywall preview are the
same screen. Copy says *"a starting point"* (recognition picks, not full listens)
— honest, on-brand, avoids over-claiming.

---

## Section 5 — Rollout (phased, gated to dev-account timing)

- **Phase 0 — now (no paid account; all free-tier, all shippable):**
  iTunes preview audio bridge · optional daily reflection · onboarding taste-seed
  · polish the daily ritual · **start the audience** (free "song of the day"
  newsletter/IG/TikTok — the single most important non-code task) · optional
  Founding-Patron presale / tip jar to validate willingness-to-pay.
- **Phase 1 — paid Apple Developer account (audio + money unlock together):**
  swap iTunes bridge → MusicKit previews (same `MusicService` seam) · real Sign
  in with Apple · paywall via RevenueCat (annual + lifetime; monthly optional) ·
  launch perks (curator notes + Founding-Patron badge) · TestFlight → App Store.
- **Phase 2 — first months:** longitudinal taste-mirror · lean into viral
  primitives (friend graph, shareable cards) + sustained audience-building.
- **Phase 3 — seasonal / once a community exists:** year-in-music keepsake (first
  year-end) · contribution economy.

Nothing is ever blocked: free-tier value + audience are built now; the money
machinery slots in exactly when the dev account makes it possible — by which
point there is an audience primed to convert.

---

## Audio reality (a hard industry constraint, not an app limitation)

- **No full-song playback for free non-subscribers, through any service, ever** —
  full on-demand streams pay per-play royalties. Full songs play only when **the
  listener brings their own subscription** (MusicKit for Apple Music subscribers;
  Spotify SDK remote-control for Spotify Premium), or if you become a licensed
  service (not an indie path).
- **The 30-second preview is the universal free floor** (Shazam, Apple Browse,
  Last.fm all live here). Available *now* with no paid account via the **iTunes
  Search API** (`itunes.apple.com/search` → `previewUrl` → plain `AVPlayer`),
  which also returns genre + release year (two taste-mirror dimensions). Caveats:
  coverage isn't 100%; the API's terms target affiliate/search use, so treat it
  as a **development/early bridge** and migrate to MusicKit previews at launch
  (you'll have the paid account by then anyway).
- **The reframe (load-bearing for the brand):** the 30s is the *spark*; **the
  journal is the substance / "whole picture."** A chosen clip + an essay about why
  the song matters is a *more* complete picture than full playback with no story.
  Make the snippet feel **authored, not amputated:** curate the clip, fade don't
  cut, name it honestly ("a taste — hear it all in Apple Music →"). Full song is
  always one tap away (Open-in + Add to Daily Playlist).
- **Audio and money arrive in the same box:** the paid Apple Developer account
  unlocks MusicKit previews *and* in-app purchase together.

---

## Honest viability assessment

**Verdict: achievable for the stated goal (cover costs + modest profit), but the
deciding factor is distribution, not this design.**

- **The design de-risks the usual failure modes** (weak retention, low
  willingness-to-pay, ethos/audience mismatch) by using battle-tested mechanisms
  (habit, endowment, scarcity, identity, patronage) aimed at an audience that pays
  for meaning. These drive **retention and conversion among engaged users**.
- **They do not create acquisition.** The anti-algorithm positioning (a correct
  filter) also spreads slower. **Reach is a separate job.**
- **Benchmarks (illustrative):** freemium converts ~1–5% to paid; Apple takes 15%
  (SBP); ~$25–30/yr blended per payer.
  - Cover costs (~few hundred/yr): ~30–40 paying fans — easy.
  - ~$1k/mo profit: ~500 payers → ~10–17k downloads over time — realistic *with*
    distribution effort.
  - Replace an income ($50k+): tens of thousands of payers — breakout exception.
- **Energy budget: ~80% distribution, ~20% this design.** The editorial voice is
  itself the marketing engine (start a free newsletter/socials now, before the app
  ships). Built-in viral primitives: shared daily song, friend graph, shareable
  cards (the Wordle $0-ad-spend playbook).

**Primary risks:** (1) distribution/reach; (2) niche TAM is small by design
(right for ethos, caps ceiling at "nice indie income"); (3) solo curation burden
(mitigated later by the contribution economy); (4) audio ToS gray area (bridge
only; MusicKit at launch).

## Success metrics (how we'll know it's working)

- **Activation:** onboarding completion + reaching the first taste read.
- **Retention:** D7 / D30 of activated users (the habit loop working).
- **Conversion:** free → paid (target ~2–5%).
- **Economics:** ARPPU; break-even payer count (~30–40 covers costs).
- **Virality:** friend-invite rate + share-card shares (acquisition health).

## Explicitly NOT in the initial deployment (YAGNI)

Contribution economy · longitudinal taste-mirror · year-in-music keepsake ·
monthly tier (maybe) · push/nudges (need APNs = paid account) · any crowd input
to the daily drop.

## Implementation deltas (for later per-phase planning)

- **`reflections`** table (`user_id`, `entry_id`, `text`, `created_at`, owner-only
  RLS) + `ReflectionService` (mock + Supabase) behind the existing seam + one
  optional text field under the essay in `EntryDetailView`.
- **Onboarding taste-seed** writes to the existing `song_ratings`; add steps to
  `OnboardingView`, bump `totalSteps`.
- **`daily_entries.extended_notes text`** (patron-only curator notes).
- **Audio:** new `iTunesPreviewMusicEngine` behind `MusicService` now;
  `MusicKitMusicEngine` (already built) activated at launch.
- **Paywall:** RevenueCat; a `PaywallView`; `VaultViewModel` gates full archive vs.
  keepers-only by entitlement; archive search.
- **Founding-Patron badge:** a `profiles` flag surfaced on profile/avatar.
