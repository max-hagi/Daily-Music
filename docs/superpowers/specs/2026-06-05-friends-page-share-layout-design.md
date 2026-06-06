# Friends page share + layout rework

**Date:** 2026-06-05
**Status:** Approved design, ready for implementation planning

## 1. Goal

Make the Friends tab feel like a friends surface first, and an invite surface second.

Today, tapping **Share invite** opens a small intermediate sheet that contains a
second **Share your invite** button. That extra step is redundant: the first tap
should open the native iOS share sheet directly, with AirDrop, Messages, social
apps, and the system share destinations.

The visual hierarchy should also change. Confirmed friends should become the hero
element of the page; adding a friend should become a compact utility panel.

## 2. Scope

**In:**
- `Views/Friends/FriendsView.swift` share-invite flow.
- Friends tab layout hierarchy.
- Confirmed friends, incoming requests, empty state, and add-by-code presentation.
- Small supporting view extraction inside `FriendsView` if it keeps the screen readable.

**Out:**
- New backend fields or RPCs.
- Changes to friend request semantics.
- Changes to `FriendInsightsView` behavior.
- Push notifications, friend search, public handles, or invite analytics.

## 3. Current behavior

`FriendsView` currently renders the page as a `List` with this order:
1. `addFriendSection`
2. `requestsSection`, if any
3. `friendsSection`

`addFriendSection` contains a large QR code, the user's six-character friend code,
a **Share invite** button, and the manual code-entry form.

The share flow is:
1. User taps **Share invite**.
2. `showShare = true`.
3. SwiftUI presents a custom sheet.
4. The sheet contains a `ShareLink`.
5. User taps the `ShareLink`.
6. The native iOS share sheet opens.

Steps 3-5 should disappear.

## 4. Chosen design: friends-first stack

Option A from the visual companion is the chosen direction.

The Friends tab should render in this priority order:
1. Header/title.
2. Confirmed friends as the main content.
3. Incoming requests, if any.
4. Compact add-friend panel.

If there are no confirmed friends yet, the empty friend state still leads the page,
but it should be modest and social: "No friends yet" plus a direct share affordance.
It should not become a large QR/code poster.

## 5. Direct share behavior

Replace the intermediate `.sheet(isPresented: $showShare)` flow with a direct native
share trigger.

Preferred implementation:
- Remove `@State private var showShare = false`.
- Remove the custom sheet that wraps `ShareLink`.
- Render `ShareLink(item: friendLink)` directly as the **Share invite** control in
  the compact add-friend panel and empty state.

The shared item remains:

```swift
private var friendLink: String { "dailymusic://friend/\(store.myCode)" }
```

Tapping **Share invite** should immediately hand control to the system share sheet.

## 6. Friends as hero content

Confirmed friends should no longer be a plain, secondary `Section("Your friends")`
below the invite block.

Each friend row should feel like the primary repeated element:
- Avatar on the left.
- Display name as the main line.
- A short secondary line such as "Open their taste mirror" or similar.
- A trailing affordance that makes the row feel tappable.
- Existing navigation to `FriendInsightsView(friend:onOpenEntry:)` remains.
- Existing swipe-to-remove behavior remains.

The first friend can be visually a little richer than the rest if that fits the
SwiftUI implementation, but it is not required. The important hierarchy is that
the friend list appears before invite controls and uses more visual weight than
the add-friend panel.

## 7. Requests

Incoming requests should remain easy to notice and act on.

Recommended placement:
- If confirmed friends exist, render requests between the friends list and the
  compact add-friend panel.
- If no confirmed friends exist, render requests immediately after the empty friend
  state.

Request rows keep the current behavior:
- Avatar + display name.
- Accept button.
- Decline button.
- `store.respond(request, accept:)` unchanged.

## 8. Compact add-friend panel

The add-friend UI should become a compact utility panel at the bottom of the
Friends tab content.

It should include:
- A small **Your invite** row with the current friend code.
- A direct `ShareLink` button.
- A single-line manual code-entry row with `TextField("Enter a 6-digit code", ...)`
  and **Send**.
- Existing normalization/validation behavior from `enteredCode` unchanged.
- Existing error message display unchanged, but visually subordinate.

The QR code should no longer dominate the page.

Recommended QR treatment:
- Remove the large QR from the default top-level layout, or reduce it to a small
  secondary element inside the compact panel.
- If kept visible, it should be smaller than the friend avatars/cards and should
  not sit above the confirmed friends.

## 9. Empty state

When `store.friends.isEmpty`, show a friend-first empty state rather than leading
with the add-friend block.

Suggested content:
- Title: "No friends yet"
- Supporting text: "Share your invite to start comparing taste mirrors."
- Primary action: direct **Share invite** `ShareLink`
- Secondary path: the compact manual code-entry row below

Avoid reintroducing the redundant share step in the empty state.

## 10. Data flow

No data model changes.

Existing store/service calls remain:
- `store.load()`
- `store.send(code:)`
- `store.respond(_:accept:)`
- `store.remove(_:)`

The page still pre-fills `enteredCode` from `UserDefaults.standard["pendingFriendCode"]`
after `store.load()`.

## 11. Error handling

Manual send errors remain sourced from `store.errorMessage` and displayed below the
manual code-entry row.

Share behavior does not need a custom error surface. If the system share sheet is
cancelled or unavailable, the app should rely on native iOS behavior.

## 12. Testing and verification

Implementation should verify:
- Tapping **Share invite** opens the native share sheet directly, without an
  intermediate Daily Music sheet.
- Friends render above the add-friend controls when friends exist.
- Empty state still gives a clear invite path when no friends exist.
- Incoming requests still accept/decline correctly.
- Manual code entry still normalizes to six allowed characters, disables **Send**
  until valid, clears focus on success, and shows errors on failure.
- Swipe-to-remove still works for confirmed friends.

Given this is primarily SwiftUI presentation, a build plus manual simulator check
is acceptable. Add focused unit tests only if implementation changes store logic;
do not add backend or broad UI-test infrastructure for this rework.

## 13. Files

| File | Change |
|------|--------|
| `Views/Friends/FriendsView.swift` | EDIT — direct share trigger, friends-first layout, compact add-friend panel |
| `Views/Components/QRCodeView.swift` | NO CHANGE expected — only reused smaller or omitted from default layout |
| `ViewModels/FriendsStore.swift` | NO CHANGE expected |
| `Services/FriendService.swift` | NO CHANGE expected |

