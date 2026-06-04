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
