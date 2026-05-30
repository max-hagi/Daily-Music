# Daily Music — v1 Design

**Date:** 2026-05-30
**Status:** Approved (brainstorming)
**Platform:** SwiftUI iOS app, target iOS 26.5, Xcode 16 (synchronized file groups)

## Concept

A human-curated "one song a day + journal entry" app. Each day every user sees
the **same** curated song and an accompanying journal piece. The moat is the
editorial voice, not the technology. End goal: ship to the App Store. This spec
covers a focused v1 that proves the core loop — *open app → see today's song +
journal → listen → react* — with the rest layered on later.

## Key decisions

- **Music (option D):** Apple Music in-app 30-sec previews via MusicKit, plus
  Spotify deep-link-out. "Add to Daily Playlist" works on the Apple side after a
  one-time connect. Richer Spotify playback deferred to a later version.
- **Content (option A):** one shared song + journal entry per day for everyone.
  No genre personalization in v1.
- **Accounts:** Sign in with Apple, plus a DEBUG-only guest bypass that never
  ships in a release build.
- **Backend:** Supabase (Postgres + Auth + Row-Level Security). The Supabase
  table editor doubles as the CMS for authoring daily entries.
- **Notifications:** local on-device notifications (UserNotifications) at a fixed
  time in v1. No push server yet.

### Corrections to the original (Gemini) notes

- Spotify deprecated `preview_url` and locked down its Web API (late 2024); the
  Spotify iOS SDK requires Premium and remote-controls the Spotify app rather
  than playing audio in-app. So in-app previews are **Apple-only** in v1.
- "Add to playlist" requires a one-time user authorization on both services — it
  is not silent/background.
- Sign in with Apple is only *mandatory* when a third-party login is also offered.

## v1 feature cut

Hero screen (song + journal), Apple Music 30-sec preview, Open in
Spotify/Apple Music deep links, connect Apple Music + add-to-playlist,
Sign in with Apple, favorites/hearts, daily local notification, Calendar/Vault.

**Deferred to v2+:** streaks, custom notification times, social-share image
generator, Spotify add-to-playlist / richer playback, genre personalization /
surprise picks, subscriptions (RevenueCat).

## Architecture

SwiftUI with a light MVVM split and a protocol-based service layer so the UI can
run on mock data today and swap to live Supabase/MusicKit by filling in one
implementation per protocol.

```
App entry → RootView (auth gate)
├─ Views        — SwiftUI layout
├─ ViewModels   — @Observable, own async load + state per screen
└─ Services (protocols + mock impls):
   ├─ AuthService          — session, Sign in with Apple, sign out, guest
   ├─ EntryService         — fetch today's entry, fetch published history
   ├─ FavoritesService     — toggle / list hearted entries
   ├─ MusicService         — MusicKit preview playback, add-to-playlist
   └─ NotificationService  — schedule the daily local notification
```

`AppEnvironment` is an `@Observable` container holding the five service
protocols; it is injected into the SwiftUI environment. v1 wires the mock
implementations; later we swap in `SupabaseEntryService`, `MusicKitMusicService`,
etc. without touching the views.

### Service seam (what's mock now / real later)

| Protocol | v1 mock | Real impl later |
|---|---|---|
| AuthService | in-memory session, instant sign-in | Supabase Auth + Sign in with Apple |
| EntryService | hardcoded sample entries | Supabase `daily_entries` query |
| FavoritesService | in-memory set | Supabase `favorites` table |
| MusicService | logs + fakes playback state | MusicKit `ApplicationMusicPlayer` |
| NotificationService | real `UNUserNotificationCenter` (no deps) | same |

## Data model (Supabase)

```
daily_entries
  id             uuid pk
  date           date unique         -- one entry per calendar day
  title          text
  artist         text
  album_art_url  text
  journal_md     text                -- journal piece (markdown)
  apple_music_id text                -- Apple catalog ID (preview + add-to-playlist)
  spotify_uri    text                -- deep link / "Open in Spotify"
  published_at   timestamptz         -- future entries hidden until their day

favorites
  user_id    uuid   -- references auth.users
  entry_id   uuid   -- references daily_entries
  created_at timestamptz
  primary key (user_id, entry_id)
```

**RLS:** `daily_entries` readable by anyone where `published_at <= now()`;
`favorites` readable/writable only by their owner. Authoring tomorrow's entry =
inserting a row.

## Screens & navigation

`TabView` with **Today**, **Vault**, **Favorites**; **Settings** from a toolbar.

- **Today** — album art, title/artist, play/pause preview, journal (markdown),
  heart, Open-in buttons, Add to Daily Playlist.
- **Vault** — list/calendar of past published entries → reuses the detail view.
- **Favorites** — list of hearted entries → detail view.
- **Settings** — auth status, connect Apple Music, notification toggle + time,
  DEBUG guest bypass.

## Key flows

1. **Launch → session check.** Existing session → main tabs; else sign-in
   screen (with DEBUG "skip").
2. **Load today's song.** `TodayViewModel.fetchEntry(for: today)` →
   `loading / loaded / empty / error`. `empty` ("no song yet today") is a
   designed state.
3. **Preview playback.** `MusicService` plays the entry's `apple_music_id`;
   MusicKit authorization prompted on first play; no subscription needed for a
   30-sec preview.
4. **Add to Daily Playlist.** First tap authorizes + find-or-creates a
   "Daily Music" library playlist, then adds the track.
5. **Favorite.** Optimistic toggle; revert on failure.
6. **Daily notification.** Schedule a repeating local notification at the
   chosen time.

## Error handling & edge cases

- No entry for today → `empty` state with friendly copy.
- Network/Supabase failure → `error` state with retry.
- MusicKit denied / no Apple Music → hide/disable preview, keep deep-link
  buttons; surface a one-line explanation.
- Favorite write fails → revert optimistic UI, toast.
- Notification permission denied → reflect in Settings, link to system settings.

## Testing

ViewModels tested against fake services (the protocol seam). Cover: load states
(loaded/empty/error), favorite toggle + rollback, playback state transitions.

## Out of scope for v1

Everything in the "Deferred to v2+" list above, plus real push infrastructure
and any admin UI beyond the Supabase table editor.
