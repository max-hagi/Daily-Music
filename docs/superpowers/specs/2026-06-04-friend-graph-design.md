# Friend Graph — Design

- **Date:** 2026-06-04
- **Status:** Approved (design) — implement Phase B first, then Phase C
- **Topic:** A request/approve friending system (invite code + QR) and a Friends tab that shows a friend's insights

---

## 1. Summary & decisions

- **Identity = email-first.** Anonymous/guest is DEBUG-only and never ships, so every
  production user is a durable email account. No anon→email linking to build.
- **Model = request + approve.** Entering/scanning someone's code sends *them* a request,
  which they approve in the Friends tab.
- **Invite = a per-user friend code + QR + custom-scheme link.** The code (e.g. `MX4K2P`)
  is encoded as `dailymusic://friend/<code>` for both a tappable link and a QR; the system
  Camera or a tap opens the app and prefills the code. Manual code entry is the fallback.
- **Access via RPCs, not loosened RLS.** Every table stays **owner-only**. All cross-user
  reads (a friend's profile, a friend's ratings) go through `SECURITY DEFINER` functions
  that check `are_friends(a, b)`. Nothing is exposed except through a guarded function.

## 2. Non-goals (own later sub-projects)

- Friend-avatar bubbles on favourited entries.
- The all-vs-friends count toggle (favourites/reactions/listening).
- Nudges (need push / APNs / paid account).
- In-app camera QR **scanner** (system Camera + the custom-scheme link cover v1).
- Universal `https://` links (need the paid account + web hosting).

## 3. Data model

**`profiles`** — add one column:
```sql
alter table public.profiles add column if not exists friend_code text unique;
```
The code is a 6-char A–Z/2–9 string (no ambiguous 0/O/1/I), generated **server-side** by
`claim_friend_code()` (§4) the first time the user opens "Add friend", so uniqueness is
guaranteed atomically (retry on the rare unique-collision).

**`friendships`** — one row per pair, status carries the request state:
```sql
create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);
alter table public.friendships enable row level security;
-- You can see rows you're part of; writes happen through the RPCs below.
create policy "see own friendships" on public.friendships
  for select using (requester_id = auth.uid() or addressee_id = auth.uid());
```

**Helper** (used inside the read RPCs):
```sql
create or replace function public.are_friends(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$$;
```

## 4. RPCs (all `SECURITY DEFINER`, `grant execute … to authenticated`)

- `claim_friend_code() returns text` — returns the caller's code, generating + storing a
  unique one on first call.
- `send_friend_request(p_code text) returns uuid` — find the code's owner; guard against
  self, already-pending, already-friends; insert `(requester = auth.uid(), addressee = owner,
  'pending')`; return the new id. Raises a friendly message on each failure.
- `respond_to_request(p_id uuid, p_accept boolean) returns void` — accept → `status =
  'accepted'`; decline → delete; only where `addressee_id = auth.uid()` and still pending.
- `remove_friend(p_id uuid) returns void` — delete a friendship you're part of.
- `incoming_requests() returns table(request_id uuid, user_id uuid, display_name text,
  avatar_url text, created_at timestamptz)` — pending rows where you're the addressee, joined
  to the requester's profile (so the inbox can show name + avatar before acceptance).
- `my_friends() returns table(friendship_id uuid, user_id uuid, display_name text,
  avatar_url text)` — accepted friends with their profile fields.
- `friend_ratings(p_friend_id uuid) returns table(...song_ratings columns...)` — the
  friend's ratings, but only if `are_friends(auth.uid(), p_friend_id)`; powers Phase C.

All SQL lives in `docs/superpowers/specs/friend-graph.sql` (user runs it; mock works without).

## 5. Services & models

- `Friend { id: UUID, profile: UserProfile, friendshipID: UUID }`
- `FriendRequest { id: UUID, profile: UserProfile, createdAt: Date }` (id = request/friendship id)
- `FriendService` protocol (mock + Supabase):
  ```swift
  func myCode() async throws -> String
  func friends() async throws -> [Friend]
  func incomingRequests() async throws -> [FriendRequest]
  func sendRequest(code: String) async throws            // throws a user-facing message
  func respond(requestID: UUID, accept: Bool) async throws
  func remove(friendshipID: UUID) async throws
  func friendRatings(friendID: UUID) async throws -> [SongRating]   // Phase C
  ```
  `MockFriendService` holds in-memory friends/requests for previews + dev. `SupabaseFriendService`
  calls the RPCs above. Wired into `AppEnvironment` (mock/live), with a `FriendsStore`
  (`@MainActor @Observable`) holding `friends` + `requests` + the pending-request badge count.

## 6. UI — Friends tab (new tab in `MainTabView`)

A `NavigationStack` with three zones:
- **Add friend:** your code shown big + a QR (`CoreImage` `CIQRCodeGenerator` of the
  `dailymusic://friend/<code>` link) + a Share button; below, a field to enter a friend's code.
- **Requests:** incoming pending requests (avatar + name) with **Approve** / **Decline**.
  Tab shows a badge with the count.
- **Friends:** list of accepted friends (avatar + name); tap → their insights; swipe → remove.

Avatars reuse `AvatarPickerView`'s sibling — `InitialsAvatar` + `AsyncImage` (already built).

## 7. Deep link

- Info.plist `CFBundleURLTypes` registers scheme `dailymusic`.
- `RootView`/app `.onOpenURL` parses `dailymusic://friend/<code>` → routes to the Friends tab
  with the code prefilled (and, if signed in, offers to send the request).

## 8. Phase C — friend insights

Reuse the pure `TasteMirror` engine on `friend_ratings(friendID)`. The current `InsightsView`
reads the signed-in user's data; refactor it to accept a **ratings source** (and a title/owner
name) so the same screen renders either "your" or "<friend>'s" insights, read-only. The friend
page hides the 👍/👎 inputs and any "edit" affordances.

## 9. Testing

- Pure: friend-code generator (length, allowed charset, no ambiguous chars).
- `MockFriendService` round-trips: send → appears as incoming → approve → appears in friends;
  decline removes it; remove deletes.
- `FriendsStore` badge count reflects `incomingRequests`.
- RPC guards are validated manually against live (self-code, duplicate, non-existent code).

## 10. Implementation phasing

- **Phase B (this build):** SQL (friend_code, friendships, helper, all RPCs); `FriendService`
  (+mock+Supabase) + `FriendsStore` + `AppEnvironment` wiring; the Friends tab (add / requests /
  list); the deep link. Ships a complete friending experience.
- **Phase C (fast follow):** `friend_ratings` consumption + the `InsightsView` refactor to render
  a friend's read-only insights.

## 11. Identity note

No Phase A work: production is email-only already (anonymous front door was never added; guest is
`#if DEBUG`). Friending assumes a signed-in real user, which the `RootView` gate guarantees. In
dev, the mock `FriendService` powers the UI without any live accounts.
