-- Daily Music — Insights taste mirror migration. Run in the Supabase SQL editor.
-- (Already applied to the live project; kept here for the record / fresh setups.)

-- 1) Song tag columns (safe to re-run).
alter table daily_entries add column if not exists year     int;
alter table daily_entries add column if not exists mood     text;
alter table daily_entries add column if not exists energy   int;   -- 1..5
alter table daily_entries add column if not exists theme    text;
alter table daily_entries add column if not exists language text;

-- 2) Per-user 👍/👎 ratings.
create table if not exists song_ratings (
  user_id    uuid not null references auth.users(id) on delete cascade,
  entry_id   uuid not null references daily_entries(id) on delete cascade,
  value      smallint not null check (value in (-1, 1)),  -- 1 = 👍, -1 = 👎
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, entry_id)
);

alter table song_ratings enable row level security;

create policy "song_ratings owner read"
  on song_ratings for select using (auth.uid() = user_id);

create policy "song_ratings owner write"
  on song_ratings for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
