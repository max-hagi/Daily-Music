# Friend Graph — Phase B (Friending) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A complete request/approve friending system — a friend code + QR, a requests inbox, and a friends list — backed entirely by `SECURITY DEFINER` RPCs over owner-only tables.

**Architecture:** New `friendships` table + `profiles.friend_code`; all cross-user access via RPCs guarded by `are_friends`. A `FriendService` (mock + Supabase) feeds a `FriendsStore` in `AppEnvironment`; a new Friends tab renders add/requests/list. A `dailymusic://friend/<code>` custom scheme prefills the add field. Friend insights (consuming `friend_ratings`) are Phase C.

**Tech Stack:** SwiftUI (iOS 18 `Tab`), Swift Testing, supabase-swift (Postgrest RPCs), CoreImage (QR).

**Spec:** `docs/superpowers/specs/2026-06-04-friend-graph-design.md`

---

## Conventions (every task)

Export first: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- **BUILD:** `xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5` → `** BUILD SUCCEEDED **`
- **TEST:** `xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests" 2>&1 | tail -20` → `** TEST SUCCEEDED **`
- New APP-target `.swift` files auto-join (synchronized folders); **new TEST files need a 4-part `.pbxproj` entry** (see commit `e4b135d` for the pattern). Module `Daily_Music`; tests use `import Testing` + `@testable import Daily_Music`.
- The working tree has unrelated uncommitted edits to `RatingBar.swift`/`ReactionsBar.swift`/`.gitignore` — never stage those.

## File structure

**Create:**
- `docs/superpowers/specs/friend-graph.sql` — schema + RPCs (user runs it)
- `Daily Music/Models/FriendCode.swift` — pure code generator/normalizer
- `Daily Music/Models/Friend.swift` — `Friend` + `FriendRequest`
- `Daily Music/Services/FriendService.swift` — protocol + `MockFriendService`
- `Daily Music/Services/Supabase/SupabaseFriendService.swift` — live RPC impl
- `Daily Music/ViewModels/FriendsStore.swift` — observable store
- `Daily Music/Views/Components/QRCodeView.swift` — CoreImage QR
- `Daily Music/Views/Friends/FriendsView.swift` — the tab
- `Daily MusicTests/FriendCodeTests.swift`, `Daily MusicTests/FriendsStoreTests.swift`

**Modify:**
- `Daily Music/App/AppEnvironment.swift` — add `friends` + `friendsStore`
- `Daily Music/Views/MainTabView.swift` — Friends tab + badge
- `Daily Music/App/RootView.swift` (or `Daily_MusicApp.swift`) — `.onOpenURL`
- Target Info (Xcode → Info → URL Types) — register `dailymusic` scheme

---

### Task 1: SQL — schema + RPCs (deliverable; user runs it)

**Files:** Create `docs/superpowers/specs/friend-graph.sql`

- [ ] **Step 1: Write the file**

```sql
-- Friend Graph — Phase B

-- 1) Friend code on profiles
alter table public.profiles add column if not exists friend_code text unique;

-- 2) Friendships
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
drop policy if exists "see own friendships" on public.friendships;
create policy "see own friendships" on public.friendships
  for select using (requester_id = auth.uid() or addressee_id = auth.uid());

-- 3) are_friends helper
create or replace function public.are_friends(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$$;

-- 4) claim_friend_code: return caller's code, generating a unique one on first call
create or replace function public.claim_friend_code()
returns text language plpgsql security definer set search_path = public as $$
declare existing text; candidate text; alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  select friend_code into existing from public.profiles where id = auth.uid();
  if existing is not null then return existing; end if;
  -- ensure a row exists (normally it does, post-onboarding); seed settings in case
  -- that column is NOT NULL.
  insert into public.profiles (id, settings) values (auth.uid(), '{}'::jsonb)
    on conflict (id) do nothing;
  loop
    candidate := '';
    for i in 1..6 loop
      candidate := candidate || substr(alphabet, 1 + floor(random()*length(alphabet))::int, 1);
    end loop;
    begin
      update public.profiles set friend_code = candidate where id = auth.uid();
      return candidate;
    exception when unique_violation then
      -- collision, try again
    end;
  end loop;
end; $$;
grant execute on function public.claim_friend_code() to authenticated;

-- 5) send_friend_request
create or replace function public.send_friend_request(p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare target uuid; existing uuid; new_id uuid;
begin
  select id into target from public.profiles where friend_code = upper(p_code);
  if target is null then raise exception 'No one has that code.'; end if;
  if target = auth.uid() then raise exception 'That is your own code.'; end if;
  select id into existing from public.friendships
   where (requester_id = auth.uid() and addressee_id = target)
      or (requester_id = target and addressee_id = auth.uid());
  if existing is not null then raise exception 'You already have a request or friendship with them.'; end if;
  insert into public.friendships(requester_id, addressee_id, status)
    values (auth.uid(), target, 'pending') returning id into new_id;
  return new_id;
end; $$;
grant execute on function public.send_friend_request(text) to authenticated;

-- 6) respond_to_request
create or replace function public.respond_to_request(p_id uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_accept then
    update public.friendships set status = 'accepted'
     where id = p_id and addressee_id = auth.uid() and status = 'pending';
  else
    delete from public.friendships
     where id = p_id and addressee_id = auth.uid() and status = 'pending';
  end if;
end; $$;
grant execute on function public.respond_to_request(uuid, boolean) to authenticated;

-- 7) remove_friend
create or replace function public.remove_friend(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.friendships
   where id = p_id and (requester_id = auth.uid() or addressee_id = auth.uid());
end; $$;
grant execute on function public.remove_friend(uuid) to authenticated;

-- 8) incoming_requests (pending, where I'm the addressee) + requester profile
create or replace function public.incoming_requests()
returns table(request_id uuid, user_id uuid, display_name text, avatar_url text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select f.id, p.id, p.display_name, p.avatar_url, f.created_at
  from public.friendships f join public.profiles p on p.id = f.requester_id
  where f.addressee_id = auth.uid() and f.status = 'pending'
  order by f.created_at desc;
$$;
grant execute on function public.incoming_requests() to authenticated;

-- 9) my_friends (accepted, either direction) + their profile
create or replace function public.my_friends()
returns table(friendship_id uuid, user_id uuid, display_name text, avatar_url text)
language sql stable security definer set search_path = public as $$
  select f.id,
         case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end as user_id,
         p.display_name, p.avatar_url
  from public.friendships f
  join public.profiles p
    on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
  where f.status = 'accepted' and (f.requester_id = auth.uid() or f.addressee_id = auth.uid());
$$;
grant execute on function public.my_friends() to authenticated;

-- 10) friend_ratings (Phase C): a friend's ratings, only if accepted-friends
create or replace function public.friend_ratings(p_friend_id uuid)
returns table(entry_id uuid, value smallint)
language sql stable security definer set search_path = public as $$
  select r.entry_id, r.value from public.song_ratings r
  where r.user_id = p_friend_id and public.are_friends(auth.uid(), p_friend_id);
$$;
grant execute on function public.friend_ratings(uuid) to authenticated;
```

- [ ] **Step 2: Commit**
```bash
git add "docs/superpowers/specs/friend-graph.sql"
git commit -m "feat(friends): friend-graph schema + RPCs SQL"
```

- [ ] **Step 3: MANUAL** — user runs the file in Supabase → SQL Editor before live friending. Mock works without it.

---

### Task 2: `FriendCode` generator (TDD)

**Files:** Create `Daily MusicTests/FriendCodeTests.swift`, `Daily Music/Models/FriendCode.swift`

- [ ] **Step 1: Failing test**
```swift
import Testing
@testable import Daily_Music

struct FriendCodeTests {
    @Test func generatesSixAllowedChars() {
        let code = FriendCode.generate()
        #expect(code.count == 6)
        #expect(code.allSatisfy { FriendCode.alphabet.contains($0) })
    }
    @Test func alphabetExcludesAmbiguous() {
        for c in "01OI" { #expect(!FriendCode.alphabet.contains(c)) }
    }
    @Test func normalizeUppercasesAndStrips() {
        #expect(FriendCode.normalize(" mx4k2p ") == "MX4K2P")
        #expect(FriendCode.normalize("a-b!c") == "ABC")   // strips non-alphabet
    }
}
```
- [ ] **Step 2: Run TEST** → red: `cannot find 'FriendCode' in scope` (remember to register the test file in the pbxproj).
- [ ] **Step 3: Implement**
```swift
//  FriendCode.swift — pure helpers for the shareable friend code.
import Foundation

enum FriendCode {
    /// No ambiguous 0/O/1/I.
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate(length: Int = 6) -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    /// Uppercase and keep only allowed characters (for user-entered codes).
    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { alphabet.contains($0) })
    }
}
```
- [ ] **Step 4: Run TEST** → `** TEST SUCCEEDED **`
- [ ] **Step 5: Commit**
```bash
git add "Daily Music/Models/FriendCode.swift" "Daily MusicTests/FriendCodeTests.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "feat(friends): add FriendCode generator (TDD)"
```

---

### Task 3: Models `Friend` + `FriendRequest`

**Files:** Create `Daily Music/Models/Friend.swift`

- [ ] **Step 1: Create**
```swift
//  Friend.swift — a confirmed friend and a pending incoming request.
import Foundation

struct Friend: Identifiable, Equatable {
    let friendshipID: UUID
    let profile: UserProfile
    var id: UUID { profile.id }
}

struct FriendRequest: Identifiable, Equatable {
    let id: UUID          // the friendship/request row id
    let profile: UserProfile
    let createdAt: Date
}
```
- [ ] **Step 2: BUILD** → succeeds
- [ ] **Step 3: Commit**
```bash
git add "Daily Music/Models/Friend.swift"
git commit -m "feat(friends): add Friend + FriendRequest models"
```

---

### Task 4: `FriendService` protocol + mock

**Files:** Create `Daily Music/Services/FriendService.swift`

- [ ] **Step 1: Create**
```swift
//  FriendService.swift — the friending seam. All cross-user access is via RPCs
//  live; the mock keeps an in-memory graph so the UI is explorable offline.
import Foundation

protocol FriendService: Sendable {
    func myCode() async throws -> String
    func friends() async throws -> [Friend]
    func incomingRequests() async throws -> [FriendRequest]
    func sendRequest(code: String) async throws
    func respond(requestID: UUID, accept: Bool) async throws
    func remove(friendshipID: UUID) async throws
    func friendRatings(friendID: UUID) async throws -> [UUID: Int]   // Phase C
}

enum FriendError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let m) = self { return m } else { return nil } }
}

actor MockFriendService: FriendService {
    private var code = FriendCode.generate()
    private var friendList: [Friend]
    private var requests: [FriendRequest]
    private var ratingsByFriend: [UUID: [UUID: Int]] = [:]

    init() {
        let alex = UserProfile(id: UUID(), displayName: "Alex Rivera", avatarURL: nil)
        let sam  = UserProfile(id: UUID(), displayName: "Sam", avatarURL: nil)
        friendList = [Friend(friendshipID: UUID(), profile: alex)]
        requests = [FriendRequest(id: UUID(), profile: sam, createdAt: Date())]
    }

    func myCode() async throws -> String { code }
    func friends() async throws -> [Friend] { friendList }
    func incomingRequests() async throws -> [FriendRequest] { requests }

    func sendRequest(code raw: String) async throws {
        let c = FriendCode.normalize(raw)
        guard c.count == 6 else { throw FriendError.message("That code looks too short.") }
        guard c != code else { throw FriendError.message("That is your own code.") }
        // Mock: just acknowledge — no real recipient.
    }

    func respond(requestID: UUID, accept: Bool) async throws {
        guard let idx = requests.firstIndex(where: { $0.id == requestID }) else { return }
        let req = requests.remove(at: idx)
        if accept { friendList.append(Friend(friendshipID: req.id, profile: req.profile)) }
    }

    func remove(friendshipID: UUID) async throws {
        friendList.removeAll { $0.friendshipID == friendshipID }
    }

    func friendRatings(friendID: UUID) async throws -> [UUID: Int] {
        ratingsByFriend[friendID] ?? [:]
    }
}
```
- [ ] **Step 2: BUILD** → succeeds
- [ ] **Step 3: Commit**
```bash
git add "Daily Music/Services/FriendService.swift"
git commit -m "feat(friends): add FriendService protocol + mock"
```

---

### Task 5: `FriendsStore` (TDD)

**Files:** Create `Daily MusicTests/FriendsStoreTests.swift`, `Daily Music/ViewModels/FriendsStore.swift`

- [ ] **Step 1: Failing test**
```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct FriendsStoreTests {
    @Test func loadPopulatesAndBadgeCounts() async {
        let store = FriendsStore(service: MockFriendService())
        await store.load()
        #expect(store.friends.count == 1)
        #expect(store.requestCount == 1)
        #expect(store.myCode.count == 6)
    }
    @Test func approveMovesRequestToFriends() async {
        let store = FriendsStore(service: MockFriendService())
        await store.load()
        let req = store.requests[0]
        await store.respond(req, accept: true)
        #expect(store.requestCount == 0)
        #expect(store.friends.count == 2)
    }
}
```
- [ ] **Step 2: Run TEST** → red (register test file in pbxproj).
- [ ] **Step 3: Implement**
```swift
//  FriendsStore.swift — owns the friends list + incoming requests for the app.
import Foundation

@MainActor
@Observable
final class FriendsStore {
    private(set) var friends: [Friend] = []
    private(set) var requests: [FriendRequest] = []
    private(set) var myCode: String = ""
    private(set) var errorMessage: String?

    private let service: FriendService
    init(service: FriendService) { self.service = service }

    var requestCount: Int { requests.count }

    func load() async {
        myCode = (try? await service.myCode()) ?? myCode
        friends = (try? await service.friends()) ?? friends
        requests = (try? await service.incomingRequests()) ?? requests
    }

    /// Returns true on success; sets errorMessage on failure.
    func send(code: String) async -> Bool {
        errorMessage = nil
        do { try await service.sendRequest(code: code); await load(); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }

    func respond(_ request: FriendRequest, accept: Bool) async {
        try? await service.respond(requestID: request.id, accept: accept)
        await load()
    }

    func remove(_ friend: Friend) async {
        try? await service.remove(friendshipID: friend.friendshipID)
        await load()
    }
}
```
- [ ] **Step 4: Run TEST** → succeeds
- [ ] **Step 5: Commit**
```bash
git add "Daily Music/ViewModels/FriendsStore.swift" "Daily MusicTests/FriendsStoreTests.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "feat(friends): add FriendsStore (TDD)"
```

---

### Task 6: `SupabaseFriendService`

**Files:** Create `Daily Music/Services/Supabase/SupabaseFriendService.swift`

- [ ] **Step 1: Create**
```swift
//  SupabaseFriendService.swift — live friending via SECURITY DEFINER RPCs.
import Foundation
import Supabase

final class SupabaseFriendService: FriendService {
    private let client = Supa.client

    func myCode() async throws -> String {
        try await client.rpc("claim_friend_code").execute().value
    }

    func friends() async throws -> [Friend] {
        let rows: [FriendRow] = try await client.rpc("my_friends").execute().value
        return rows.map {
            Friend(friendshipID: $0.friendship_id,
                   profile: UserProfile(id: $0.user_id, displayName: $0.display_name, avatarURL: $0.avatar_url))
        }
    }

    func incomingRequests() async throws -> [FriendRequest] {
        let rows: [RequestRow] = try await client.rpc("incoming_requests").execute().value
        return rows.map {
            FriendRequest(id: $0.request_id,
                          profile: UserProfile(id: $0.user_id, displayName: $0.display_name, avatarURL: $0.avatar_url),
                          createdAt: $0.created_at)
        }
    }

    func sendRequest(code: String) async throws {
        // The RPC raises a friendly Postgres error on bad code / dupes; surface it.
        _ = try await client.rpc("send_friend_request", params: ["p_code": FriendCode.normalize(code)]).execute()
    }

    func respond(requestID: UUID, accept: Bool) async throws {
        try await client.rpc("respond_to_request",
                             params: RespondParams(p_id: requestID, p_accept: accept)).execute()
    }

    func remove(friendshipID: UUID) async throws {
        try await client.rpc("remove_friend", params: ["p_id": friendshipID]).execute()
    }

    func friendRatings(friendID: UUID) async throws -> [UUID: Int] {
        let rows: [FriendRatingRow] = try await client
            .rpc("friend_ratings", params: ["p_friend_id": friendID]).execute().value
        return Dictionary(rows.map { ($0.entry_id, Int($0.value)) }, uniquingKeysWith: { a, _ in a })
    }
}

private struct FriendRow: Decodable {
    let friendship_id: UUID; let user_id: UUID; let display_name: String?; let avatar_url: String?
}
private struct RequestRow: Decodable {
    let request_id: UUID; let user_id: UUID; let display_name: String?; let avatar_url: String?; let created_at: Date
}
private struct RespondParams: Encodable { let p_id: UUID; let p_accept: Bool }
private struct FriendRatingRow: Decodable { let entry_id: UUID; let value: Int16 }
```
- [ ] **Step 2: BUILD** → succeeds (if a `params:` type-inference error appears, wrap heterogeneous params in a dedicated `Encodable` struct as done for `RespondParams`).
- [ ] **Step 3: Commit**
```bash
git add "Daily Music/Services/Supabase/SupabaseFriendService.swift"
git commit -m "feat(friends): add SupabaseFriendService (RPCs)"
```

---

### Task 7: Wire into `AppEnvironment`

**Files:** Modify `Daily Music/App/AppEnvironment.swift`

- [ ] **Step 1** — add stored properties after `let profiles: ProfileService`:
```swift
    let friends: FriendService
```
after `let profileStore: ProfileStore`:
```swift
    let friendsStore: FriendsStore
```
- [ ] **Step 2** — add `friends: FriendService,` to `init(...)`; in the body after `self.profiles = profiles`:
```swift
        self.friends = friends
```
next to the other stores:
```swift
        self.friendsStore = FriendsStore(service: friends)
```
- [ ] **Step 3** — `mock()`: add `friends: MockFriendService(),`; `live()`: add `friends: SupabaseFriendService(),`.
- [ ] **Step 4: BUILD** → succeeds
- [ ] **Step 5: Commit**
```bash
git add "Daily Music/App/AppEnvironment.swift"
git commit -m "feat(friends): wire FriendService + FriendsStore into AppEnvironment"
```

---

### Task 8: `QRCodeView`

**Files:** Create `Daily Music/Views/Components/QRCodeView.swift`

- [ ] **Step 1: Create**
```swift
//  QRCodeView.swift — renders a string as a QR using CoreImage (no permissions).
import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let string: String
    var size: CGFloat = 180

    private static let context = CIContext()

    var body: some View {
        Image(uiImage: qrImage())
            .interpolation(.none)            // keep the modules crisp when scaled
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("QR code for your friend link")
    }

    private func qrImage() -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cg = Self.context.createCGImage(output, from: output.extent) else {
            return UIImage(systemName: "qrcode") ?? UIImage()
        }
        return UIImage(cgImage: cg)
    }
}
```
- [ ] **Step 2: BUILD** → succeeds
- [ ] **Step 3: Commit**
```bash
git add "Daily Music/Views/Components/QRCodeView.swift"
git commit -m "feat(friends): add QRCodeView"
```

---

### Task 9: `FriendsView` (the tab)

**Files:** Create `Daily Music/Views/Friends/FriendsView.swift`

- [ ] **Step 1: Create**
```swift
//  FriendsView.swift — the Friends tab: add by code/QR, approve requests, see friends.
import SwiftUI

struct FriendsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var enteredCode = ""
    @State private var showShare = false
    @State private var sendError: String?

    private var store: FriendsStore { env.friendsStore }

    private var friendLink: String { "dailymusic://friend/\(store.myCode)" }

    var body: some View {
        NavigationStack {
            List {
                addFriendSection
                if !store.requests.isEmpty { requestsSection }
                friendsSection
            }
            .navigationTitle("Friends")
            .task { await store.load() }
            .refreshable { await store.load() }
            .sheet(isPresented: $showShare) {
                ShareLink(item: friendLink) { Label("Share your invite", systemImage: "square.and.arrow.up") }
                    .padding()
                    .presentationDetents([.height(120)])
            }
        }
    }

    private var addFriendSection: some View {
        Section("Add a friend") {
            VStack(spacing: 14) {
                QRCodeView(string: friendLink, size: 170)
                Text(store.myCode)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .tracking(4)
                Button { showShare = true } label: {
                    Label("Share invite", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            HStack {
                TextField("Enter a friend's code", text: $enteredCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Send") {
                    Task {
                        if await store.send(code: enteredCode) { enteredCode = "" }
                        sendError = store.errorMessage
                    }
                }
                .disabled(FriendCode.normalize(enteredCode).count != 6)
            }
            if let sendError {
                Text(sendError).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var requestsSection: some View {
        Section("Requests") {
            ForEach(store.requests) { request in
                HStack(spacing: 12) {
                    avatar(request.profile)
                    Text(request.profile.displayName ?? "New friend").font(.headline)
                    Spacer()
                    Button { Task { await store.respond(request, accept: true) } } label: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }.buttonStyle(.plain)
                    Button { Task { await store.respond(request, accept: false) } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
                .font(.title3)
            }
        }
    }

    private var friendsSection: some View {
        Section("Your friends") {
            if store.friends.isEmpty {
                Text("No friends yet — share your code to get started.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.friends) { friend in
                    HStack(spacing: 12) {
                        avatar(friend.profile)
                        Text(friend.profile.displayName ?? "Friend").font(.headline)
                        Spacer()
                        // Phase C will push the friend's insights here.
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) { Task { await store.remove(friend) } }
                    }
                }
            }
        }
    }

    @ViewBuilder private func avatar(_ profile: UserProfile) -> some View {
        if let s = profile.avatarURL, let url = URL(string: s) {
            AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                placeholder: { InitialsAvatar(name: profile.displayName, size: 40) }
                .frame(width: 40, height: 40).clipShape(Circle())
        } else {
            InitialsAvatar(name: profile.displayName, size: 40)
        }
    }
}
```
- [ ] **Step 2: BUILD** → succeeds
- [ ] **Step 3: Commit**
```bash
git add "Daily Music/Views/Friends/FriendsView.swift"
git commit -m "feat(friends): add Friends tab view (code/QR, requests, list)"
```

---

### Task 10: Add the Friends tab to `MainTabView`

**Files:** Modify `Daily Music/Views/MainTabView.swift`

- [ ] **Step 1** — pull the env in and add the tab. Replace the struct body:
```swift
struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        TabView {
            Tab("Today", systemImage: "music.note") { TodayView() }
            Tab("Vault", systemImage: "calendar") { VaultView() }
            Tab("Favorites", systemImage: "heart") { FavoritesView() }
            Tab("Friends", systemImage: "person.2") { FriendsView() }
                .badge(env.friendsStore.requestCount)
            Tab("Insights", systemImage: "chart.bar.fill") { InsightsView() }
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .task { await env.friendsStore.load() }   // so the badge is populated app-wide
    }
}
```
- [ ] **Step 2: BUILD** → succeeds
- [ ] **Step 3: Verify in sim** — five tabs; Friends shows your code + QR, the seeded mock request (Sam) with approve/decline, and the seeded friend (Alex). Approving moves Sam into the list and clears the badge. Screenshot `/tmp/friends.png`.
- [ ] **Step 4: Commit**
```bash
git add "Daily Music/Views/MainTabView.swift"
git commit -m "feat(friends): add Friends tab with request badge"
```

---

### Task 11: Deep link `dailymusic://friend/<code>`

**Files:** Modify `Daily Music/App/RootView.swift`; register the URL scheme in the target.

- [ ] **Step 1: Register the scheme** — in Xcode: target **Daily Music → Info → URL Types → +**, Identifier `maxhagi.Daily-Music`, URL Schemes `dailymusic`. (Or add `CFBundleURLTypes` to the Info.plist.) This is a one-time project setting.

- [ ] **Step 2: Handle the URL** — add to `RootView`'s top-level view a handler that stashes the code in `UserDefaults` so `FriendsView` can prefill it on appear:

In `RootView.body`, attach to the `ZStack`:
```swift
        .onOpenURL { url in
            guard url.scheme == "dailymusic", url.host == "friend" else { return }
            let code = url.lastPathComponent
            if !code.isEmpty { UserDefaults.standard.set(code, forKey: "pendingFriendCode") }
        }
```
In `FriendsView`, consume it in `.task`:
```swift
            .task {
                await store.load()
                if let pending = UserDefaults.standard.string(forKey: "pendingFriendCode") {
                    enteredCode = pending
                    UserDefaults.standard.removeObject(forKey: "pendingFriendCode")
                }
            }
```
- [ ] **Step 3: BUILD** → succeeds
- [ ] **Step 4: Verify** — `xcrun simctl openurl booted "dailymusic://friend/MX4K2P"` launches/opens the app; the Friends tab's code field is prefilled with `MX4K2P`. (Manual: tap into Friends if not auto-selected.)
- [ ] **Step 5: Commit**
```bash
git add "Daily Music/App/RootView.swift" "Daily Music/Views/Friends/FriendsView.swift"
git commit -m "feat(friends): handle dailymusic://friend/<code> deep link"
```

---

### Task 12: Verification pass

- [ ] **Step 1: TEST** → `** TEST SUCCEEDED **` with `FriendCodeTests` + `FriendsStoreTests` green.
- [ ] **Step 2: Mock walkthrough** (sim): Friends tab → approve Sam → friend list has Alex + Sam → swipe-remove works → enter a 6-char code → Send (mock acknowledges) → deep-link prefill works.
- [ ] **Step 3:** Branch ready; finish via `superpowers:finishing-a-development-branch`.

---

## Self-review notes (author)

- **Spec coverage:** friend_code + friendships + are_friends (Task 1) · all RPCs incl. friend_ratings for Phase C (Task 1) · FriendService/Store/wiring (Tasks 4–7) · code+QR+share+enter, requests inbox, friends list (Tasks 8–10) · deep link (Task 11) · email-first identity needs no task (§11). Phase C (friend insights UI) is a separate plan.
- **pbxproj:** Tasks 2 and 5 add test files → need the 4-part registration (app-target files auto-join).
- **Deep link** is last so the core friending ships even if the URL-scheme setting is deferred.
