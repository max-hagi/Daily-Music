# Spotify Connect — Design

**Date:** 2026-06-11
**Status:** Approved design, awaiting implementation plan
**Branch:** `feature/spotify-connect`

## Goal

Spotify users can connect their account and save the daily song to a private
**"Daily Music" playlist** in their Spotify library — the same save experience
Apple Music subscribers get. Ships **live immediately** (no feature flag):
unlike MusicKit, Spotify OAuth needs no paid Apple account, so this is fully
buildable and testable on a real device today.

What Spotify connect does NOT do (platform limits, not choices):

- **No in-app playback upgrade.** Spotify offers third-party iOS apps no
  streaming; previews stay on the iTunes path, "Open in Spotify" stays the
  playback handoff.
- **No rich metadata.** Editorial-notes-style content isn't in their Web API.
- Capabilities reported: **`[.librarySave]` only.**

## Decisions made

| Question | Decision |
|---|---|
| Save target | Find-or-create a **private "Daily Music" playlist** — parity with Apple Music. Not Liked Songs. |
| Rollout | **Live immediately.** The Settings "Connected services" section becomes always-visible with the Spotify row active; the Apple Music row stays behind `FeatureFlags.appleMusicConnect`. |
| Onboarding | Same skippable nudge as Apple Music: picking Spotify on the listen step shows "Connect Spotify to save songs". |
| Scopes | `playlist-modify-private` + `playlist-read-private` only — minimal consent screen, no Liked Songs or profile access. |
| Distribution caveat | Spotify dev mode caps usage at you + ~25 allowlisted users until their extended-quota review. Fine for TestFlight-circle scale; revisit before a wide public launch. |

## App registration (already done)

- **Client ID:** `af09508c18cf406e963ed6fc82be10ba` — public by design (it
  ships in the binary); lives in a committed `SpotifyConfig.swift`.
- **Client secret:** NOT used. PKCE flows authenticate with the client ID
  alone. The secret stays in the Spotify dashboard and must never enter the
  repo, the app, or any chat/log.
- **Redirect URI:** `dailymusic://spotify-callback` — registered in the
  dashboard, must match character-exactly. Uses the `dailymusic://` scheme the
  app already declares in Info.plist; `ASWebAuthenticationSession` intercepts
  the callback directly, so it never collides with `dailymusic://friend/…`
  deep links in `RootView.onOpenURL`.

## Architecture

Three focused units behind the existing `MusicServiceConnection` protocol —
mirroring how `AppleMusicSession` is split from its `AppleMusicAuthorizing`
seam — plus one altitude fix that makes both services symmetric.

```
EntryActionCluster (save button)
        │  "which connected service grants .librarySave?"
        ▼
MusicServiceConnection (protocol)  ←  + saveToLibrary(entry) [NEW]
        ├─ AppleMusicSession   (absorbs MusicKit playlist code from the engine)
        └─ SpotifySession      (state machine; composes the two units below)
                ├─ SpotifyAuthenticator  (PKCE + token refresh + Keychain)
                └─ SpotifyLibraryAPI     (Web API: find/create playlist, add track)
```

### 1. Altitude fix: saves move from playback to connection

Library saving currently lives on `MusicEngine.addToDailyPlaylist` /
`MusicPlayer.addToDailyPlaylist` — a leftover from when Apple Music was the
only save path. Saving is a *connection* concern, not a playback concern:

- `MusicServiceConnection` gains `func saveToLibrary(_ entry: DailyEntry) async throws`.
- `AppleMusicSession` implements it with the MusicKit find-or-create playlist
  code **moved out of `FullTrackMusicEngine`**.
- `MusicEngine.addToDailyPlaylist` and `MusicPlayer.addToDailyPlaylist` are
  **deleted** (engines become pure playback; `PreviewMusicEngine`'s throwing
  stub and the `addToPlaylistUnavailable` error case go away).
- The save button asks the environment for the first connected service whose
  capabilities contain `.librarySave` and calls `saveToLibrary` on it.

### 2. `SpotifyAuthenticator` — PKCE + tokens

- **Connect flow:** generate a code verifier (43–128 chars, unreserved set)
  and S256 challenge → open `ASWebAuthenticationSession` at
  `https://accounts.spotify.com/authorize?client_id=…&response_type=code&redirect_uri=dailymusic://spotify-callback&scope=playlist-modify-private%20playlist-read-private&code_challenge_method=S256&code_challenge=…&state=…`
  → user logs in/approves → session hands back the callback URL → validate
  `state`, extract `code` → POST `https://accounts.spotify.com/api/token`
  (code + verifier, no secret) → access token (~1 h) + refresh token.
- **Storage:** both tokens in the **Keychain** (small `KeychainStore` helper,
  `kSecClassGenericPassword`, service `"daily-music.spotify"`). Not
  UserDefaults — these are real credentials.
- **Refresh:** `validAccessToken()` returns the cached token if fresh,
  otherwise POSTs the refresh grant first. Spotify rotates refresh tokens —
  always persist the new one when returned. Refresh failure (revoked access)
  throws a distinct "needs reconnect" error.
- **Seam:** the session talks to a `SpotifyAuthenticating` protocol;
  the real implementation owns `ASWebAuthenticationSession` + URLSession.
  Pure PKCE helpers (verifier generation, S256 challenge) are standalone
  functions — unit-tested against RFC 7636 test vectors.

### 3. `SpotifyLibraryAPI` — Web API client

- `findOrCreatePlaylist()` → `GET /v1/me/playlists` (paged, look for name
  "Daily Music") else `POST /v1/users/{id}/playlists` with
  `{"name": "Daily Music", "public": false}`; needs the user id from
  `GET /v1/me` (id only — no extra scope needed). Playlist ID is cached in
  UserDefaults after first resolution so saves are one request.
- `addTrack(spotifyID:to:)` → `POST /v1/playlists/{id}/tracks` with
  `{"uris": ["spotify:track:<id>"]}`.
- Track ID comes from the entry's stored Spotify link/URI (already on
  `DailyEntry`; parse the id out of either `spotify:track:X` or
  `open.spotify.com/track/X` forms).
- Injectable transport (`(URLRequest) async throws -> (Data, URLResponse)`)
  so request building + response parsing are unit-testable offline.
- If the cached playlist was deleted by the user (404 on add), re-resolve
  find-or-create once and retry.

### 4. `SpotifySession` — the `MusicServiceConnection`

@MainActor @Observable, owned by `AppEnvironment`, sibling of `AppleMusicSession`:

- `connect()` → authenticator PKCE flow → on success
  `status = .connected([.librarySave])`. User-cancelled login = quiet return
  to `.notConnected` (not an error).
- `restore()` on launch (called next to the Apple Music restore in
  `RootView`): if the Keychain holds tokens → `.connected([.librarySave])`
  without network. First save after a long absence exercises refresh.
- `saveToLibrary(entry)` → `validAccessToken()` → `SpotifyLibraryAPI`. A
  "needs reconnect" refresh failure flips status to `.notConnected` and
  rethrows so the save button shows its existing error alert.
- `disconnect()` → wipe Keychain tokens + cached playlist ID →
  `.notConnected`. (Full revocation lives at spotify.com/account/apps —
  the Settings row footer mentions this.)

### 5. Surfaces

- **Settings → Connected services:** section header becomes unconditionally
  "Connected services". Rows: Spotify (always) + Apple Music (behind its
  flag). Spotify row mirrors the Apple Music row: status line
  ("Not connected" / "Connected · saves to your Daily Music playlist") +
  Connect / Disconnect.
- **Onboarding listen step:** the existing private prompt generalizes — picked
  service == .spotify → Spotify connect button (always); == .appleMusic →
  Apple Music button (flag-gated). Still skippable, never blocks Finish.
- **Save button (EntryActionCluster):** gating changes from
  `env.appleMusic…librarySave` to "any connected service grants
  `.librarySave`"; the action calls that service's `saveToLibrary`. Shared
  `SavedTracksLog` keeps the "Added ✓" state — entry-scoped, service-agnostic.
- **mock():** a fake `SpotifyAuthenticating` + stub transport make the
  connected/save states explorable in the simulator.

## Error handling

| Failure | Behavior |
|---|---|
| User cancels the Spotify login sheet | Quiet return to `.notConnected` — no alert |
| `state` mismatch on callback | Treat as failed login (quiet), log |
| Token refresh fails (access revoked) | Session → `.notConnected`; save rethrows → existing "couldn't save" alert; row shows Connect again |
| 403 from API (user not on the dev-mode allowlist) | Save alert with a clearer message ("This Spotify app is in development mode — ask Max to allowlist your account") |
| Cached playlist deleted (404 on add) | Re-run find-or-create once, retry the add |
| Offline | Standard throw → existing save-failed alert, retryable |
| Rate limit (429) | Single retry after `Retry-After`; then surface the alert |

## Testing

- PKCE helpers: RFC 7636 test vectors (verifier charset/length, S256
  challenge of a known verifier).
- `SpotifySession` state machine via a fake `SpotifyAuthenticating`:
  connect success/cancel, restore-from-keychain, disconnect wipes, refresh
  failure downgrade.
- `SpotifyLibraryAPI` via stub transport: request shapes (URL, method, body,
  auth header), playlist found vs created, 404-retry, track-ID parsing from
  both URI and URL forms.
- Save-button routing: service-selection logic (Apple vs Spotify vs none)
  unit-tested on the environment/cluster helper.
- Keychain store: round-trip on device/simulator.
- **End-to-end on a real device with your account** — the full OAuth round
  trip, playlist creation, and a visible save in the Spotify app. (This is
  the part MusicKit couldn't give us; here it's the acceptance test.)

## Out of scope

- Spotify playback of any kind (platform limit).
- Extended-quota / public-launch review prep (revisit before wide release).
- Liked Songs saves, multiple playlists, playlist artwork.
- Tidal or other services (the protocol keeps the door open).
