-- Social-Proof Counts migration
-- A SECURITY DEFINER function so the client can read the TOTAL number of
-- favourites for an entry across all users — the `favourites` table itself is
-- RLS owner-only, so a plain count would only ever see the caller's own rows.

create or replace function public.favourite_count(p_entry uuid)
returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::int from public.favourites where entry_id = p_entry;
$$;

-- Let the app (anon key + signed-in users) call it.
grant execute on function public.favourite_count(uuid) to anon, authenticated;
