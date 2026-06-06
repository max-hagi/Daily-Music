# Friend nudges - manual per-friend push notifications

**Date:** 2026-06-06
**Status:** Approved design, ready for implementation planning

## 1. Goal

Accepted friends can send each other a small push notification that says, in
effect, "come check Daily Music." V1 is deliberately manual and one-to-one: tap a
Nudge control beside a friend, the backend verifies the relationship and
cooldown, then APNs delivers the notification to that friend if they have enabled
notifications.

## 2. Scope

**In:** a per-friend Nudge action in the Friends experience, a new push-token
registration path, a Supabase Edge Function that sends APNs notifications, a
server-side nudge audit/cooldown table, mock nudge behavior for DEBUG, and
store-level loading/error/cooldown state.

**Out:** group nudges, smart/automatic inactivity nudges, freeform user messages,
an in-app inbox, notification action buttons, marketing campaigns, and any
cross-user access that bypasses the existing friendship checks.

## 3. Current Context

- `NotificationService` is local-only today. It schedules the daily reminder on
  device with `UNUserNotificationCenter` and has no backend push-token concept.
- `FriendService` owns the friendship surface. Live friend access goes through
  Supabase RPCs and the `are_friends(a, b)` helper; mock friend data already
  powers previews and DEBUG exploration.
- Earlier social specs intentionally deferred nudges because remote push needs
  APNs capability, a paid Apple Developer account, and backend secrets.
- The app already uses Supabase Edge Functions for privileged backend work
  (`delete-account`), so the nudge sender should follow that pattern rather than
  putting APNs credentials in the iOS app.

## 4. Product Behavior

- Show a compact `Nudge` action only for accepted friends. It should not appear
  on incoming requests, outgoing request states, or the add-friend panel.
- Placement: a small `bell.badge` label/button in the accepted friend row, with
  the same action also available on the friend-insights screen header or toolbar.
  If row navigation and the button conflict, keep navigation on the main row
  content and make the button borderless or trailing-only.
- Notification copy is fixed, not user-authored:
  `"<Display Name> nudged you to check Daily Music."`
- The notification opens Daily Music to the main Today/root experience via a
  simple deep link such as `dailymusic://today`. If route handling is not in
  place yet, tapping the push can simply open the app root for v1.
- After a successful send, show lightweight confirmation in place: `Nudged`.
- Enforce one delivered nudge per sender-recipient pair per rolling 24-hour
  window in the backend. During cooldown the UI can show `Nudged today` and
  disable the control when it already knows that state, but the server remains
  authoritative.
- If the recipient has no registered push token, return a gentle user-facing
  state: `They need notifications enabled first.`

## 5. Backend Data

### `push_tokens`

Stores devices that can receive APNs pushes.

```sql
create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios')),
  token text not null,
  environment text not null check (environment in ('sandbox', 'production')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, token)
);
alter table public.push_tokens enable row level security;
```

RLS: users may insert/update/delete/select only their own token rows. Token
registration can be an owner-only RPC if that keeps client code simpler.

### `friend_nudges`

Records attempts and powers cooldowns.

```sql
create table if not exists public.friend_nudges (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('sent', 'no_tokens', 'rate_limited', 'failed')),
  apns_id text,
  error text,
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);
alter table public.friend_nudges enable row level security;
```

RLS can allow users to see their own sent/received nudge rows, but writes should
happen only through the Edge Function. A partial index on
`(sender_id, recipient_id, created_at desc)` keeps cooldown lookups fast.

## 6. Edge Function

Add `supabase/functions/send-friend-nudge/index.ts`.

Request:

```json
{ "recipient_id": "uuid" }
```

Flow:

1. Read and validate the caller's Supabase JWT.
2. Reject self-nudges.
3. Verify `public.are_friends(auth.uid(), recipient_id)`.
4. Check `sent` `friend_nudges` rows from the last 24 hours for this
   sender-recipient pair and reject with `rate_limited` if one already exists.
5. Load the sender's profile display name, with a fallback such as `A friend`.
6. Load the recipient's active `push_tokens`.
7. If no tokens exist, insert a `no_tokens` row and return a user-facing
   no-token result. This records the attempt but does not burn the recipient's
   24-hour nudge cooldown because no notification was delivered.
8. Send APNs payloads from the Edge Function and insert a `sent` or `failed`
   audit row.

Required Edge Function secrets:

- `APNS_TEAM_ID`
- `APNS_KEY_ID`
- `APNS_PRIVATE_KEY`
- `APNS_TOPIC`
- `APNS_ENVIRONMENT` (`sandbox` or `production`)

APNs payload:

```json
{
  "aps": {
    "alert": {
      "title": "Daily Music",
      "body": "<Display Name> nudged you to check Daily Music."
    },
    "sound": "default"
  },
  "url": "dailymusic://today",
  "type": "friend_nudge"
}
```

## 7. iOS Services

Keep daily local reminders separate from remote push infrastructure.

Add a push registration service:

```swift
protocol PushRegistrationService: Sendable {
    func registerDeviceToken(_ token: Data) async throws
    func unregisterCurrentDevice() async throws
}
```

Live implementation submits the APNs token to Supabase (`push_tokens` RPC or
owner-only upsert). Mock implementation stores the most recent token in memory.

Add a nudge service:

```swift
enum FriendNudgeResult: Equatable {
    case sent
    case noRecipientToken
    case rateLimited(nextAllowedAt: Date?)
}

protocol FriendNudgeService: Sendable {
    func sendNudge(to friendID: UUID) async throws -> FriendNudgeResult
}
```

`SupabaseFriendNudgeService` invokes `send-friend-nudge`. `MockFriendNudgeService`
records send attempts and simulates one-per-day cooldowns, so the Friends UI is
testable without APNs.

`Daily_MusicApp` should add an app delegate bridge with
`UIApplicationDelegateAdaptor` to receive `didRegisterForRemoteNotifications` and
forward the token into the live push-registration service. Register for remote
notifications after the user grants notification permission; sender permission is
not required to send a nudge, but recipient permission is required to receive one.

## 8. Store and UI State

Extend `FriendsStore` or add a focused `FriendNudgeStore` owned by
`AppEnvironment`. Preferred v1: add a focused nudge store so the existing
friends/request loading state stays simple.

Store state per friend:

- `idle`
- `sending`
- `sent`
- `noRecipientToken`
- `rateLimited`
- `failed(message)`

The Friends row and friend-insights header consume the same state. Tapping Nudge:

1. Immediately sets that friend's state to `sending`.
2. Calls `FriendNudgeService.sendNudge(to:)`.
3. Maps the result to `sent`, `noRecipientToken`, or `rateLimited`.
4. On errors, shows a short inline message or toast-style alert without
   reloading the whole Friends tab.

## 9. Guardrails

- Backend is authoritative for friendship, cooldown, and sender identity.
- No freeform text; users cannot compose arbitrary push content.
- No nudges to non-friends or pending-request users.
- One delivered nudge per sender-recipient pair per rolling 24-hour window.
- APNs tokens are stored owner-only and never exposed through regular friend
  reads.
- If APNs fails for one token but succeeds for another token on the same user,
  return `sent` and record the per-token failure in logs or the audit row.

## 10. Testing

- Pure/store tests: state transitions for success, no-token, rate-limited, and
  thrown-error cases.
- Mock service tests: second nudge to the same friend on the same day returns
  `rateLimited`; different friends remain independent.
- SQL/manual backend checks: non-friend rejected, self rejected, accepted friend
  allowed, cooldown enforced, no-token recipient returns `no_tokens`.
- Edge Function test harness with APNs mocked: validates JWT handling, payload
  shape, and audit-row status.
- iOS verification: build the app; manually confirm the button appears only for
  accepted friends. Live push delivery needs a physical device and APNs
  capability/secrets configured.

## 11. Implementation Phasing

1. **Contracts + mock UI:** add `FriendNudgeService`, mock implementation, nudge
   store, and Nudge buttons with simulated results.
2. **Backend schema + Edge Function:** add `push_tokens`, `friend_nudges`, and
   `send-friend-nudge` with mocked APNs in tests.
3. **Device token registration:** add app delegate bridge, live
   `PushRegistrationService`, and token upsert/removal behavior.
4. **Live send path:** wire `SupabaseFriendNudgeService` into `AppEnvironment`,
   configure APNs secrets, and test on a physical device.
5. **Polish:** cooldown labels, friend-insights duplicate control, and friendly
   error copy.

## 12. Files

| File | Change |
|------|--------|
| `Daily Music/Services/FriendNudgeService.swift` | NEW - protocol, result enum, mock service |
| `Daily Music/Services/PushRegistrationService.swift` | NEW - protocol + mock/live token registration |
| `Daily Music/Services/Supabase/SupabaseFriendNudgeService.swift` | NEW - invokes Edge Function |
| `Daily Music/ViewModels/FriendNudgeStore.swift` | NEW - per-friend send/cooldown state |
| `Daily Music/App/AppEnvironment.swift` | EDIT - wire nudge + push-registration services |
| `Daily Music/Daily_MusicApp.swift` | EDIT - app delegate bridge for device tokens |
| `Daily Music/Views/Friends/FriendsView.swift` | EDIT - compact Nudge button on accepted friend rows |
| `Daily Music/Views/Friends/FriendInsightsView.swift` | EDIT - Nudge action in header/toolbar |
| `supabase/functions/send-friend-nudge/index.ts` | NEW - authenticated APNs sender |
| `docs/superpowers/specs/friend-nudges.sql` | NEW - schema/RLS helpers for manual application |
| `Daily MusicTests/FriendNudgeTests.swift` | NEW - store/mock behavior |
