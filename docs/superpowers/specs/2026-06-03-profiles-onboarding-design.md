# Profiles & Onboarding — Design

- **Date:** 2026-06-03
- **Status:** Approved (design); pending spec review → implementation plan
- **Topic:** First-run onboarding wizard + user profile (display name + photo)
- **Why now:** This is the foundation of the planned social layer. Friending, friends'
  avatars on favourites, friends-vs-everyone counts, and nudges all require a *real
  person* — stable identity plus a profile with a name and picture — which the app does
  not have yet. This sub-project builds that foundation. The remaining social features
  each get their own spec later.

---

## 1. Summary

A brand-new user enters through **flow C ("quick hello, then in")**: a welcome screen,
a short 3-step onboarding wizard, then the app. The wizard collects a **display name**
and **profile photo**, sets up the **daily reminder** (doubling as the in-context
notification-permission ask), and records a **streaming preference**. Every step is
skippable so the front door stays low-friction.

The profile is `display_name` + `avatar_url` only — **no username**. Friends are added
later by invite link / QR (a separate sub-project), so there is no public handle to
manage. Photos are uploaded to Supabase Storage and cropped to a circle, with a
colorful **initials avatar** as the fallback until (or unless) a photo is set.

## 2. Goals

- First-run wizard: name + photo → reminder (+ notification permission) → streaming
  preference → Today. Shown once; skippable per-step.
- A `UserProfile` (display name + avatar) persisted per user, editable later in Settings.
- Real photo upload (library → crop → downscale → Supabase Storage) with an initials
  fallback used everywhere an avatar renders.
- Reuse existing infrastructure: steps 2–3 write through the current `SettingsService` /
  `UserSettings` and `NotificationService`; onboarding only orchestrates.

## 3. Non-goals (explicitly out of scope here)

- Usernames / handles and friend **search** (we chose invite-link/QR discovery).
- The friend graph, invite links, QR, friends tab, bubbles, counts, nudges.
- The anonymous → email **identity upgrade** flow (needed when a user first creates an
  invite link — built with the friend-graph sub-project).
- Real Sign in with Apple and MusicKit (still gated on a paid Apple Developer account).
- Camera capture for avatars (library picker only in v1).

## 4. Decisions (resolved during brainstorming)

| Question | Decision | Rationale |
|---|---|---|
| First-launch flow | **C — quick hello, then in** | Feels personal immediately, lowest friction; defers "become a real account" to the moment it's needed (adding a friend). |
| Friend discovery / handle | **Invite link / QR; no username** | Simplest data model, most private, fits a close-friends app. No uniqueness/availability/squatting to manage. |
| Profile picture | **Upload a photo + initials fallback** | The real "profile picture" the user asked for; initials keep skippers looking polished. Accepts the cost of new Storage infra. |
| Wizard steps | **All three** (name+photo, reminder, streaming) | A fuller welcome; reminder primes notification permission in-context; streaming sets the "Open in" default. Each step skippable to stay low-friction. |
| Front door in production | **Promote anonymous "Get started" to a real entry** | Flow C is inherently browse-first. Revisits the earlier "email-only release" lean — accepted. Email upgrade deferred to friend-graph. |
| Name/avatar storage shape | **First-class `profiles` columns, not the settings JSONB blob** | Name + avatar are identity other users will read (bubbles, lists); they deserve their own columns + RLS, not a private-prefs blob. |

## 5. User experience

**Welcome** = the existing [`SignInView`](../../../Daily%20Music/Views/SignInView.swift),
offering two doors:
- **Continue with email** — existing magic-link / OTP path.
- **Get started** — creates an anonymous Supabase session (today's DEBUG-only guest path,
  promoted to a real production entry).

After a session exists, if onboarding has not been completed the wizard appears.

**Wizard** — `OnboardingView` owns a step index and renders progress dots. One thing per
screen; each step has Skip; back navigation between steps.

1. **Say hello** — circular avatar control (tap to upload) + name field. Writes via
   `ProfileService`. Skip → leave name/photo unset.
2. **Never miss a day** — reminder time + toggle. Enabling it calls
   `NotificationService.requestAuthorization()` then `scheduleDailyReminder(at:)`, and
   persists to `UserSettings` (`reminderEnabled/Hour/Minute`). This is the in-context
   notification-permission prime. Skip ("Not now") → reminder stays off.
3. **Where do you listen?** — Apple Music / Spotify → `UserSettings.preferredStreamingService`.
   Skip → leave the existing default. "Finish" completes onboarding.

On finish (or skipping through), set `hasCompletedOnboarding = true`; `RootView` swaps to
`MainTabView` using the existing spring transition.

**Editing later** — Settings gains an "Edit profile" row that reuses a shared
`ProfileEditor` (avatar + name), writing through the same `ProfileService` as step 1. If
`display_name` is unset, Settings shows a gentle "Set your name" nudge.

## 6. Data model & storage

**`profiles` table** (already exists with `id uuid pk → auth.users`, `settings jsonb`,
`updated_at`) — add two columns:

```sql
alter table public.profiles
  add column if not exists display_name text,
  add column if not exists avatar_url  text;
```

The existing settings upsert writes only `{id, settings}`; the new profile upsert writes
only `{id, display_name, avatar_url}`. Different columns → they never clobber each other.
Existing `profiles` RLS stays **owner-only** for now; a friend-read policy (or a view
exposing only `display_name` + `avatar_url`) is added with the friend-graph sub-project.

**Avatar storage** — a public-read bucket `avatars`, objects at
`{user_id}/avatar_{timestamp}.jpg` (timestamp busts the CDN cache when a photo changes):

```sql
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "Avatar images are publicly readable"
  on storage.objects for select
  using ( bucket_id = 'avatars' );

create policy "Users upload their own avatar"
  on storage.objects for insert
  with check ( bucket_id = 'avatars'
               and auth.uid()::text = (storage.foldername(name))[1] );

create policy "Users update their own avatar"
  on storage.objects for update
  using ( bucket_id = 'avatars'
          and auth.uid()::text = (storage.foldername(name))[1] );

create policy "Users delete their own avatar"
  on storage.objects for delete
  using ( bucket_id = 'avatars'
          and auth.uid()::text = (storage.foldername(name))[1] );
```

`avatar_url` stores the public URL returned by `getPublicURL`. The image bytes are public
(an avatar is not sensitive); the `display_name` in the owner-only row is not yet readable
by others, which matches "you only display your own profile until the friend graph exists."

## 7. Architecture

Follows the established protocol → mock + Supabase → store pattern wired in
[`AppEnvironment`](../../../Daily%20Music/App/AppEnvironment.swift).

**Model** — `UserProfile`, a Codable value type:

```swift
struct UserProfile: Codable, Equatable {
    let id: UUID
    var displayName: String?
    var avatarURL: String?
}
```

**Service** — `ProfileService` protocol:

```swift
protocol ProfileService {
    func load() async throws -> UserProfile?
    func save(displayName: String?, avatarURL: String?) async throws
    func uploadAvatar(_ jpegData: Data) async throws -> String   // returns public URL
}
```

- `MockProfileService` — in-memory; powers SwiftUI previews of the wizard and Settings
  with no network.
- `SupabaseProfileService` — upserts `{id, display_name, avatar_url}` into `profiles`;
  `uploadAvatar` uploads to `avatars/{uid}/avatar_{ts}.jpg` and returns `getPublicURL`.

**Store** — `ProfileStore` (`@MainActor @Observable`), mirroring `SessionStore` /
`FavoritesStore`:

```swift
@MainActor @Observable
final class ProfileStore {
    private(set) var current: UserProfile?
    private let service: ProfileService
    init(service: ProfileService) { self.service = service }
    func load() async { current = try? await service.load() }
    // save name / set avatar URL, updating `current` optimistically
}
```

Added to `AppEnvironment` (stored property + both `mock()` / `live()` factories), loaded
once signed in (alongside `favoritesStore.load()` in `RootView`).

**Views**
- `OnboardingView` — step container (`enum Step { hello, reminder, listen }`), progress
  dots, next / skip / back, completes by setting `hasCompletedOnboarding`.
- `HelloStep`, `ReminderStep`, `ListenStep` — one per wizard screen.
- `AvatarPickerView` — the circular avatar + upload control (see §8). Reused by
  `HelloStep` and the Settings `ProfileEditor`.
- `InitialsAvatar(name:)` — initials + deterministic gradient; the universal fallback.
- Settings — an "Edit profile" row presenting `ProfileEditor` (avatar + name).

**Gating** — in [`RootView`](../../../Daily%20Music/App/RootView.swift), the signed-in
branch becomes: if `!hasCompletedOnboarding` show `OnboardingView`, else `MainTabView`.
`hasCompletedOnboarding` is `@AppStorage` (local) in v1 — simplest, and identity is per
install anyway until the email upgrade exists. (Noted for later: move completion
server-side to `profiles` once identity is durable across devices.)

## 8. Avatar upload pipeline

1. SwiftUI `PhotosPicker` (PhotosUI) → selected item → `Data`.
   - No `NSPhotoLibraryUsageDescription` required (PhotosPicker runs out-of-process).
2. Circular crop — pan/zoom over a circle mask; output the visible square.
3. Downscale to ~512×512, JPEG quality ≈ 0.8 (`pure` helper: `Data -> Data`).
4. `ProfileService.uploadAvatar(_:)` → public URL → `save(avatarURL:)` + update
   `ProfileStore.current`.
5. While none is set, `InitialsAvatar` renders instead.

Failures fall back to the initials avatar with a non-blocking error and a retry available
in Settings — never blocking wizard completion.

## 9. Edge cases

- **Skip name** → `display_name` null; initials avatar shows a neutral glyph; Settings
  nudges "Set your name". Onboarding still completes.
- **Offline / save failure** → wizard still finishes; settings already keep a UserDefaults
  offline cache; profile writes retry on next Settings save.
- **Avatar upload failure** → keep initials, surface a soft error, retry in Settings.
- **Reinstall** → new anonymous id, no profile → onboarding shows again (acceptable v1).
- **Reduce Motion** → wizard transitions respect the existing Reduce Motion gating.

## 10. Testing

Existing `Daily MusicTests` (Swift Testing, hosted):
- `InitialsAvatar` initials derivation: "Maxime Save" → "MS"; one word → "M"; empty →
  neutral fallback; gradient is deterministic for a given name.
- Image downscale helper: output ≤ 512×512 and is valid JPEG `Data`.

`MockProfileService` enables previewing the full wizard and Settings editor offline.

## 11. Rollout — SQL the user runs (in the spec, applied before/with ship)

1. `profiles` column migration (§6).
2. `avatars` bucket + four storage policies (§6).
3. Verify with a REST round-trip: upsert a `display_name`, upload a test avatar, read the
   public URL back.

A combined `profiles-onboarding.sql` file will be produced during the implementation plan.

## 12. Dependencies handed to later sub-projects

- **Friend graph:** add a friend-read policy (or `display_name`/`avatar_url` view) so
  friends can see each other's name + photo; build invite link / QR.
- **Identity upgrade:** anonymous → email linking when a user first creates an invite
  link, preserving the same `user_id` so the profile carries over.

## 13. Final sanity-checks at review

No blocking questions. Two choices already made but worth a last look before planning:
(a) promoting the anonymous "Get started" entry to production (§4, §5); (b) using a local
`@AppStorage` onboarding-completion flag in v1 rather than a server-side one (§7). Both
can change without reshaping the rest of the design.
