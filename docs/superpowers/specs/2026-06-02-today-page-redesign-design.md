# Today Page Redesign — Design Spec

- **Date:** 2026-06-02
- **App:** Daily Music (SwiftUI + Supabase, iOS 26 / Liquid Glass)
- **Status:** Approved concept; ready for implementation plan.
- **Goal:** Declutter the Today page into a calm, single-screen "song" zone with a distinct, reading-mode "story" (journal) zone revealed on scroll; replace the stack of playback/library/streaming buttons with a heart icon, an info panel, and one "Open in [service]" action.

## 1. Decisions (the brief)

- **No in-app player.** Remove the Play/preview button, "Add to Library," and the separate Apple Music/Spotify buttons. Full-track playback isn't possible without a paid Apple Developer account + an Apple Music subscriber (or Spotify Premium SDK), so listening happens via **Open in**. The `MusicPlayer`/`MusicEngine`/`MusicKitMusicEngine` code stays in the repo as dormant infra for later full-track playback — just not rendered.
- **Open in:** a single primary **"Open in [default service]"** button (service logo + name) + a small **⋯** to open *this* song in another service without changing the default.
- **Default streaming service:** chosen in **Settings** — Apple Music · Spotify · Tidal (default **Apple Music**) — persisted in the synced `UserSettings` blob.
- **More info:** an **ⓘ** opens a sheet with real catalog facts from the free **iTunes lookup API** (album, release date, track length, genre, label) + the song's **curated tags** (mood, energy, theme, decade, language).
- **Favorite → heart icon** (not a full-width button); fills red when saved.
- **Reactions bar stays as-is.** The **👍/👎 rating stays** (it powers Insights).
- **Greeting line shrinks** (small, single line). **Share stays** in the top-right toolbar.
- **Two-zone scroll** with snap "resistance" + a motion/background transition marking the boundary between the song and the journal. Scoped to the immersive (Today) presentation; Vault/Favorites keep their standard scroll.

## 2. Layout — two zones, one scroll (Today / immersive only)

**Zone 1 — the song (≈ one viewport, no scroll needed):**
1. Top toolbar (unchanged): settings gear (leading), live "N listening" badge + Share (trailing).
2. **Shrunk greeting** — one small, single line (e.g. "Today's song, [name]"); de-emphasized, not removed.
3. **Album art** — the focal point (prominent, per UX research), over the blurred-art backdrop.
4. Title + artist.
5. **Action cluster** — one row of glass icon-buttons: **❤️ favorite** · **👍 👎 rating** · **ⓘ info**. (Reuses `RatingBar`; favorite + info are new small glass circles.)
6. **Reactions bar** (`ReactionsBar`, unchanged).
7. **Open-in section** (`OpenInSection`).
8. A subtle "scroll for the story" affordance (chevron + hint) at the bottom edge.

**Zone 2 — the story (journal):**
- A visually distinct **reading surface** (calm solid/material background, not the art wash) with a grabber handle + a heading (the song title or "Today's story"), then `JournalText`.
- Reveal mechanics (the "resistance"):
  - The scroll uses **view-aligned snap targets** so dragging from the song into the story **snaps** at the boundary (`.scrollTargetBehavior(.viewAligned)` with `.scrollTargetLayout()`); Zone 1 is sized to the viewport via `containerRelativeFrame(.vertical)` so it's a full-height snap target.
  - Zone 2 animates in with `.scrollTransition` (opacity + slight upward offset/scale as it enters).
  - Zone 2 carries **its own background** that rises over the art wash as you scroll — the visual "entering reading mode" cue.
- Inside Zone 2 the journal scrolls normally for its length (no paging trap on long entries).

## 3. Components / files

**Create:**
- `Models/StreamingService.swift` — `enum StreamingService: String, CaseIterable, Identifiable { appleMusic="Apple Music", spotify="Spotify", tidal="Tidal" }`. Provides `displayName`, a `logo` view/symbol, and `func url(for: DailyEntry) -> URL?`:
  - Apple Music → `entry.appleMusicURL` (exact, from `appleMusicID`).
  - Spotify → `entry.spotifyURL` (exact, from `spotifyURI`).
  - Tidal → search fallback: `https://tidal.com/search?q=<artist title, percent-encoded>` (no Tidal ID stored).
  Logos: Apple = SF Symbol `applelogo`; Spotify = existing `SpotifyLogoIcon`; Tidal = a simple text/glyph wordmark (no trademarked asset).
- `Services/CatalogInfoService.swift` — `protocol CatalogInfoService { func info(appleMusicID:) async throws -> CatalogInfo }` + `struct CatalogInfo` (all optional: `album, releaseDate, durationSeconds, genre, label, artworkURL`). `MockCatalogInfoService` returns sample data. Live impl GETs `https://itunes.apple.com/lookup?id=<id>` and decodes `results[0]` (`collectionName`, `releaseDate`, `trackTimeMillis`, `primaryGenreName`, etc.). No auth.
- `Views/SongInfoSheet.swift` — the ⓘ panel: loads `CatalogInfo` async (graceful spinner/skeleton, degrades to tags-only if offline), shows catalog facts + the entry's curated tags as labeled rows. `.presentationDetents([.medium, .large])`.
- `Views/OpenInSection.swift` — primary "Open in [default]" button (reads `env.settings`/the settings VM for `preferredStreamingService`) + a `Menu` (⋯) listing the other two services; each opens `service.url(for: entry)` via `openURL`/`Link`. Falls back gracefully if a URL is nil.

**Modify:**
- `Models/UserSettings.swift` — add `var preferredStreamingService = "Apple Music"` + CodingKey + `decodeIfPresent` line.
- `Views/SettingsView.swift` — add a **Default streaming service** `Picker` (Apple Music/Spotify/Tidal) bound through `SettingsViewModel` (persists to the `profiles` blob + UserDefaults, existing mechanism).
- `ViewModels/SettingsViewModel.swift` — expose/bind `preferredStreamingService` (mirror existing setting bindings).
- `Views/EntryDetailView.swift` —
  - Remove `PreviewPlayButton`, `AddToPlaylistButton`, the full-width `FavoriteButton`, and the inline Apple/Spotify `Link`s.
  - Add the **action cluster** (heart icon + `RatingBar` + info icon) and **`OpenInSection`**.
  - Convert favorite to a small heart **icon button** (reuse the shared `FavoritesStore` toggle).
  - For the immersive presentation only: wrap content in the **two-zone snap scroll** with the journal reveal + reading-surface background. Non-immersive (Vault/Favorites) keeps the current single scroll but gets the same action cluster + Open-in.

**Unchanged / kept dormant:** `MusicPlayer`, `MusicEngine`, `MockMusicEngine`, `MusicKitMusicEngine` (no UI entry point now; retained for later full-track playback). `AppEnvironment.musicPlayer` may stay wired but unused.

## 4. Data flow

- **Open in:** Settings picker → `UserSettings.preferredStreamingService` → synced to `profiles` (+ UserDefaults cache) → `OpenInSection` reads it → `StreamingService(rawValue:)` → `url(for: entry)` → open externally.
- **Info:** ⓘ tap → `SongInfoSheet` → `CatalogInfoService.info(appleMusicID:)` (live: iTunes lookup; mock: sample) → render facts + `entry`'s curated tags. Network failure → show tags only.
- **Favorite / rating / reactions:** unchanged (shared `FavoritesStore`, `RatingService`, `ReactionsService`).

## 5. UX principles applied (from research)
- **Prominent album art + single clear hierarchy**, generous white space, related controls **clustered** (favorite/rating/info together; reactions together; listen action separate). [a3logics, onething]
- **Liquid Glass** icon buttons for depth without clutter. [Apple new-design gallery]
- **Scroll-transition reveal** for the journal (`scrollTransition`, view-aligned snap) — content reacts to scroll and reveals in stages. [WWDC23 "Beyond scroll views"]
- Distinct **reading surface** for the journal so browsing vs reading is unmistakable.

## 6. Honesty guardrails
- No fake/non-functional player UI (none shown at all).
- Info panel degrades to curated-tags-only when offline; never blanks.
- "Open in" only deep-links; Tidal clearly a search (no fabricated exact link).

## 7. Deferred (YAGNI)
- Full-track in-app playback + scrubbing (MusicKit `ApplicationMusicPlayer`, paid dev account + subscriber) — infra kept, not built now.
- Exact Tidal deep links (need Tidal track IDs at curation) — search fallback for now.
- Richer MusicKit metadata in the info panel (editorial notes, composer) — when paid.

## 8. Open items for the user
- Tidal web/app deep-link format may need a tweak once tested on device (`tidal.com/search?q=` chosen as a reasonable default).
- Optional: store Tidal IDs at curation later for exact links.
