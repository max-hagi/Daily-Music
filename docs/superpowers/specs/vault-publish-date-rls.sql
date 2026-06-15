-- Tighten daily_entries read policy: gate on the entry's calendar day, not just
-- published_at. published_at is stored in UTC, so a "tomorrow" row published at
-- 04:00 UTC is technically fetchable hours early by any client that skips the
-- app-side date filter (added to publishedHistory() on 2026-06-11). This makes
-- the database enforce the same rule.
--
-- "Today" is computed in America/Toronto: the server runs in UTC, so a plain
-- current_date would flip to tomorrow at 8 PM Toronto time and re-open the leak.
--
-- Apply by hand in Supabase Dashboard → SQL Editor (like the other spec files).

-- Drop whatever SELECT policy currently exists on daily_entries (name was set
-- in the dashboard at v1 setup; this finds it regardless of name).
do $$
declare p record;
begin
  for p in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'daily_entries' and cmd = 'SELECT'
  loop
    execute format('drop policy %I on public.daily_entries', p.policyname);
  end loop;
end $$;

create policy "read published entries up to today"
  on public.daily_entries
  for select
  using (
    published_at <= now()
    and date <= (now() at time zone 'America/Toronto')::date
  );

-- Verify: should list exactly one SELECT policy with the new qual.
--   select policyname, qual from pg_policies
--   where tablename = 'daily_entries' and cmd = 'SELECT';
