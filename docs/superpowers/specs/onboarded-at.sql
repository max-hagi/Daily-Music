-- Onboarding completion flag
-- Records WHEN a user finished the first-run wizard, keyed to their profile row
-- (auth.uid()). NULL = has not onboarded. This is the server source of truth; the
-- app keeps a local @AppStorage cache only as a launch-time optimization.

-- 1) The column. Nullable timestamp: NULL until the wizard's Finish step stamps it.
alter table public.profiles
  add column if not exists onboarded_at timestamptz;

-- 2) Backfill. Anyone who already has a display_name went through onboarding before
--    this column existed — stamp them so they are NOT shown the wizard again.
update public.profiles
  set onboarded_at = coalesce(updated_at, now())
  where onboarded_at is null
    and coalesce(btrim(display_name), '') <> '';

-- No new RLS policy needed: the existing owner-update policy on public.profiles
-- already lets a user write their own row, which is the only row the client stamps.
