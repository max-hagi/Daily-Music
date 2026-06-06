-- Friend Nudges backend schema and RPCs

-- 1) Push tokens
create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios')),
  token text not null,
  environment text not null check (environment in ('sandbox', 'production')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, token)
);

alter table public.push_tokens enable row level security;

drop policy if exists "see own push tokens" on public.push_tokens;
create policy "see own push tokens" on public.push_tokens
  for select using (user_id = auth.uid());

drop policy if exists "insert own push tokens" on public.push_tokens;
create policy "insert own push tokens" on public.push_tokens
  for insert with check (user_id = auth.uid());

drop policy if exists "update own push tokens" on public.push_tokens;
create policy "update own push tokens" on public.push_tokens
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "delete own push tokens" on public.push_tokens;
create policy "delete own push tokens" on public.push_tokens
  for delete using (user_id = auth.uid());

create or replace function public.register_push_token(
  p_token text,
  p_platform text,
  p_environment text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.push_tokens (user_id, platform, token, environment, last_seen_at)
  values (auth.uid(), p_platform, p_token, p_environment, now())
  on conflict (user_id, token) do update
    set platform = excluded.platform,
        environment = excluded.environment,
        last_seen_at = now();
end; $$;

grant execute on function public.register_push_token(text, text, text) to authenticated;

create or replace function public.unregister_push_token(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.push_tokens
  where user_id = auth.uid()
    and token = p_token;
$$;

grant execute on function public.unregister_push_token(text) to authenticated;

-- 2) Friend nudges
create table if not exists public.friend_nudges (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('sent', 'no_tokens', 'rate_limited', 'failed')),
  apns_id text,
  error text,
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

alter table public.friend_nudges enable row level security;

drop policy if exists "see own friend nudges" on public.friend_nudges;
create policy "see own friend nudges" on public.friend_nudges
  for select using (sender_id = auth.uid() or recipient_id = auth.uid());

create index if not exists friend_nudges_sender_recipient_created_at_idx
  on public.friend_nudges (sender_id, recipient_id, created_at desc)
  where status = 'sent';

