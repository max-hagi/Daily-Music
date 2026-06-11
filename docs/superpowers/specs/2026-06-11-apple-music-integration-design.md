# Apple Music Deep Integration — Design

**Date:** 2026-06-11
**Status:** Approved design, awaiting implementation plan
**Branch:** `feature/apple-music-integration`

## Goal

Give Apple Music subscribers a richer in-app experience — full-track playback,
save-to-playlist, and richer song metadata — while the app keeps working
exactly as it does today for everyone else (30-sec iTunes previews, "Open in…"
handoff). All of it ships **dormant behind a feature flag** because MusicKit
requires the paid Apple Developer membership, which we don't have yet.

## Decisions made

| Question | Decision |
|---|---|
| Dev account | Not yet — design + build now, flip on later. No runtime MusicKit testing until the account exists. |
| Scope | Full-track playback, add to library playlist, richer metadata/visuals. Album/artist browsing actions: **out**. |
| Activation | Explicit "Connect Apple Music" (onboarding + Settings). No surprise permission prompts; non-Apple users never see one. |
| Where full tracks play | Ceremony + entry detail + vault replays (`.standard` context). Taste-seed swipe deck keeps previews (`.sample` context). |
| Other services | Apple Music only in this build. Surfaces are shaped generically ("Connected services" list, capability-driven save action) so a future `SpotifySession` (save-to-library only — Spotify offers no third-party in-app playback, and new apps face a ~25-user dev-mode cap) slots in additively. |
| Animated artwork | Not possible — public MusicKit doesn't expose it. "Richer visuals" = hi-res artwork, editorial notes, genres, release info. |

## Architecture

Playback already flows through the swappable `MusicEngine` protocol
(`MusicPlayer` → engine). This design adds a **connection layer** (who is
connected, with what capabilities), a **second engine** (full tracks via
`ApplicationMusicPlayer`), and **routing policy** in `MusicPlayer`. The
preview path is untouched for everyone else.

```
Views ──► MusicPlayer ──┬─► PreviewMusicEngine (universal, unchanged)
          │ routing     └─► FullTrackMusicEngine (ApplicationMusicPlayer)
          │
          └── reads AppleMusicSession (connection state + capabilities)
```

### 1. Connection layer

**`MusicServiceConnection`** (protocol, shaped for future services):

- `service: StreamingService`
- `status: ConnectionStatus` — `.notConnected` / `.connected(Capabilities)`
- `connect()` / `disconnect()`

**`Capabilities`** (OptionSet): `.fullPlayback`, `.librarySave`,
`.richMetadata`. A future `SpotifySession` would report only `.librarySave`.

**`AppleMusicSession`** (@MainActor @Observable, owned by `AppEnvironment`):

- `connect()`: `MusicAuthorization.request()` → `MusicSubscription.current`.
  Subscribed → all three capabilities. Authorized-but-unsubscribed →
  `.richMetadata` only (library writes, like full playback, require an
  active Apple Music subscription).
- Persists a "user connected" flag in UserDefaults. On launch, if set,
  re-derives status **silently** (no prompt) from
  `MusicAuthorization.currentStatus` + subscription check.
- Watches `MusicSubscription.subscriptionUpdates` so a lapsed subscription
  downgrades capabilities live — playback quietly returns to previews.
- `disconnect()` clears the flag and status (it cannot revoke the iOS
  permission; it just stops the app using it).
- MusicKit statics (`MusicAuthorization`, `MusicSubscription`) are wrapped in
  a small `AppleMusicAuthorizing` seam so the state machine is unit-testable.

**Feature flag:** `appleMusicConnectEnabled = false` (compile-time constant in
app config). Gates every Connect surface (Settings section, onboarding button).
All code compiles and ships; nothing is visible until the flag flips.

### 2. Playback routing

**`PlaybackContext`** enum:

- `.standard` — ceremony (`ListeningView`), entry detail, vault replays.
  Full track when available.
- `.sample` — taste-seed deck. Always previews (rapid swipe-judging).

**`MusicPlayer` changes:**

- Constructed with the preview engine (as today) + optional
  `fullEngine: MusicEngine?` + the `AppleMusicSession`.
- `toggle(_:context:)` / `restart(_:context:)` gain a context param,
  default `.standard`.
- Routing rule: `context == .standard && capabilities.contains(.fullPlayback)`
  → full engine; otherwise preview engine.
- **Fallback:** if the full engine throws (region gap, network, revoked
  auth), the same call retries on the preview engine. Silent — log only,
  never an error state that blocks playback.
- New `private(set) var isPlayingFullTrack: Bool` so player UI can label
  "Full song" vs "Preview". Progress UI already generalizes
  (elapsed/duration driven).

**`FullTrackMusicEngine`** (repurposed from the dormant
`MusicKitMusicEngine`):

- Replaces the AVPlayer-preview body with `ApplicationMusicPlayer`
  (queue the catalog `Song` by ID). Lock screen + Control Center support
  come free.
- Progress reporting via a timer polling `playbackTime` against the song
  duration; `onFinish` from player state observation.
- Keeps the existing find-or-create "Daily Music" playlist add code.
- `PreviewMusicEngine` is untouched.

### 3. Library save

- `EntryActionCluster` gains a save action, visible only when capabilities
  include `.librarySave`. Calls the existing
  `MusicPlayer.addToDailyPlaylist(_:)`; flips to an "Added ✓" state.
- **`SavedTracksLog`** — small UserDefaults-backed store of saved entry IDs
  (same pattern as `CatchUpLog`), so we never double-add to the playlist and
  the "Added" state survives relaunch.
- `OpenInSection` unchanged — handoff stays the story for other services.

### 4. Richer metadata

- A MusicKit-backed `CatalogInfoService` implementation **decorates** the
  existing iTunes-lookup one: same base lookup, plus `editorialNotes`,
  `genreNames`, release date, hi-res artwork URL — only when the session
  reports `.richMetadata`.
- iTunes remains the universal fallback. All new model fields are optional;
  `SongInfoSheet` renders an editorial-notes section only when present, so
  non-connected users see exactly today's UI.

### 5. Surfaces

- **Settings:** new "Connected services" section — a list with Apple Music as
  its only row: status line ("Not connected" / "Connected · full playback" /
  "Connected · previews only") + Connect / Disconnect. Behind the flag.
- **Onboarding:** the listen step shows an optional, skippable
  "Connect Apple Music" button when the user picks Apple Music as their
  preferred service. Never blocks completing onboarding. Behind the flag.
- **Activation prerequisites** (documented in the dormant engine file today,
  re-checked at flip-on): MusicKit capability in Signing & Capabilities,
  `NSAppleMusicUsageDescription` Info.plist string, real-device testing.

## Error handling summary

Every failure path lands on the current preview experience:

| Failure | Behavior |
|---|---|
| MusicKit auth denied / revoked | Session `.notConnected`; previews everywhere |
| Subscription lapses mid-session | Capabilities downgrade via `subscriptionUpdates`; next play is a preview |
| Song missing from catalog/region | Full engine throws → same call falls back to preview engine |
| Playlist add fails | Thrown to the action cluster → small inline error, retryable |
| MusicKit metadata fetch fails | iTunes lookup result shown as today |

## Testing

- `AppleMusicSession` state machine: unit tests through the
  `AppleMusicAuthorizing` seam (stub auth/subscription responses).
- `MusicPlayer` routing policy: unit tests with stub engines — context ×
  capability matrix, fallback-on-throw.
- `SavedTracksLog`: unit tests (idempotency, persistence round-trip).
- `mock()` environment gets a `MockMusicServiceConnection` so every UI state
  (not connected / connected-subscribed / connected-previews-only / saved ✓)
  is explorable in the simulator **today**, without the entitlement.
- Real-device MusicKit verification (actual auth prompt, full playback,
  playlist writes) is explicitly deferred until the paid account exists.

## Out of scope

- Album/artist browsing actions ("add full album", artist pages).
- Spotify/Tidal connections (future spec; surfaces here are shaped for it).
- Animated album artwork (not exposed by public MusicKit).
- Widget changes.
