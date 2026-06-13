-- Listen tracking: one row the first time a user hears an entry.
-- Backs the ListenStatus derivation and the hero collection count.
-- Apply by hand in Supabase Dashboard → SQL Editor.

create table if not exists public.listens (
  user_id  uuid not null references auth.users(id) on delete cascade,
  entry_id uuid not null references public.daily_entries(id) on delete cascade,
  heard_at timestamptz not null default now(),
  primary key (user_id, entry_id)
);

alter table public.listens enable row level security;

-- Owner-scoped. Insert + select only: a collection never updates or shrinks.
drop policy if exists "see own listens" on public.listens;
create policy "see own listens" on public.listens
  for select using (user_id = auth.uid());

drop policy if exists "insert own listens" on public.listens;
create policy "insert own listens" on public.listens
  for insert with check (user_id = auth.uid());

create index if not exists listens_user_heard_at_idx
  on public.listens (user_id, heard_at desc);
