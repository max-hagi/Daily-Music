-- Archive Listener Counts migration
-- Companion to todays_listener_count: counts how many distinct users checked in
-- on an ARBITRARY day, so Vault/Favorites archive details can show a real
-- "N listened" badge instead of a fabricated number.
--
-- SECURITY DEFINER because check_ins is RLS owner-only — a plain count would
-- only ever see the caller's own rows. The function exposes nothing but an
-- aggregate count, so it's safe to open to all clients.

create or replace function public.listener_count_on(p_day date)
returns integer
language sql
security definer
set search_path = public
as $$
  select count(distinct user_id)::int from public.check_ins where date = p_day;
$$;

-- Let the app (anon key + signed-in users) call it.
grant execute on function public.listener_count_on(date) to anon, authenticated;
