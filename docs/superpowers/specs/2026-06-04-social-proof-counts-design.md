# Social-Proof Counts (v1) — Design

- **Date:** 2026-06-04
- **Status:** Approved (design) — proceeding to implementation
- **Topic:** All-users favourite counts on the song detail + Vault day markers that show your reaction emoji

---

## 1. Summary

Two pieces of "social proof," both all-users for v1:

1. **Favourite count** on the song detail (`EntryDetailView`, shown in both the Today tab
   and any opened Vault day): a small "🤍 N" beside the heart, nudged ±1 optimistically
   when you tap the heart.
2. **Vault day marker = your reaction emoji.** In the month calendar, a day you reacted to
   shows that emoji in place of the generic accent dot; days you didn't react to keep the
   dot. Turns the Vault into a visual diary of how each song felt.

Reaction counts already render and are already all-users (`reaction_counts` RPC) — unchanged.

## 2. Non-goals

- The **all-vs-friends toggle** (feature #6) — needs the friend graph; deferred to that
  sub-project. Count methods are shaped so adding a `.friends` scope later is one extra
  parameter, no restructuring.
- Real-time count updates (counts load on appear, like reactions today).
- Favourite counts on the calendar *cells* (too small once they carry the emoji marker) —
  the count lives on the detail, which both Today and opened Vault days present.

## 3. Data layer (mirrors existing patterns)

- **Favourite count:** add to `FavoritesService`:
  ```swift
  func count(entryID: UUID) async throws -> Int
  ```
  `MockFavoritesService` returns a stable seed (e.g. `1203 + (isFav ? 1 : 0)`).
  `SupabaseFavouritesService` calls a new `favourite_count(p_entry)` **`SECURITY DEFINER`**
  RPC — identical shape to `reaction_counts` ([SupabaseReactionsService.swift:52](../../../Daily%20Music/Services/Supabase/SupabaseReactionsService.swift)).
- **My reactions (bulk):** add to `ReactionsService`:
  ```swift
  func myReactions() async throws -> [UUID: String]   // entryID → emoji
  ```
  Mirrors `favoriteIDs()`. `MockReactionsService` returns its in-memory `mine`.
  `SupabaseReactionsService` selects the current user's own `reactions` rows
  (`user_id`, `entry_id`, `emoji`) — RLS already permits reading your own rows.
  The per-emoji count RPC is untouched.

## 4. SQL (user runs once; mock works without it)

`docs/superpowers/specs/social-proof-counts.sql`:
```sql
create or replace function public.favourite_count(p_entry uuid)
returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::int from public.favourites where entry_id = p_entry;
$$;

grant execute on function public.favourite_count(uuid) to anon, authenticated;
```

## 5. UI

- **`EntryDetailView`:** a compact favourite count next to the heart/favourite control
  (e.g. `🤍 1,204`). Loaded on appear via `favorites.count(entryID:)`; adjusted ±1
  optimistically when the heart is toggled so it feels instant; re-fetched on failure.
  Shown on Today and on opened Vault days.
- **`CalendarMonthView`:** gains a `reactions: [UUID: String]` parameter. In `dayCell`, a
  day whose `entry.id` is in the map renders `Text(emoji)` where the
  `Circle().fill(.accentColor)` dot ([CalendarMonthView.swift:144](../../../Daily%20Music/Views/Components/CalendarMonthView.swift)) was; otherwise the dot stays.
- **`VaultView`:** loads the reactions map via `env.reactions.myReactions()` and passes it
  into `CalendarMonthView`.

## 6. Testing

- `MockFavoritesService.count` + `MockReactionsService.myReactions` round-trips.
- Optimistic favourite-count ±1 logic (a small helper or inline view-model state).
- The marker-selection rule ("reacted day → emoji, else dot") is simple and sim-verified.

## 7. Factoring for friends (later)

`count(entryID:)` and `reaction_counts` stay all-users now. When the friend graph lands, a
`scope: .all | .friends` parameter (defaulting to `.all`) plus friend-aware SQL variants add
the toggle without changing call sites that don't need it.
