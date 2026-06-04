-- Profiles & Onboarding migration
-- Adds identity columns to the existing `profiles` table and a public `avatars`
-- Storage bucket with owner-scoped write policies.

-- 1) Identity columns (the existing row already has: id uuid pk, settings jsonb, updated_at)
alter table public.profiles
  add column if not exists display_name text,
  add column if not exists avatar_url  text;

-- 2) Public-read avatars bucket
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- 3) Storage RLS. NOTE: the folder check compares auth.uid()::text (lowercase)
--    against the first path segment, so the app MUST upload to a lowercased uuid
--    folder: "{uid.lowercased}/avatar_*.jpg".
create policy "Avatar images are publicly readable"
  on storage.objects for select
  using ( bucket_id = 'avatars' );

create policy "Users upload their own avatar"
  on storage.objects for insert
  with check ( bucket_id = 'avatars'
               and auth.uid()::text = (storage.foldername(name))[1] );

create policy "Users update their own avatar"
  on storage.objects for update
  using ( bucket_id = 'avatars'
          and auth.uid()::text = (storage.foldername(name))[1] );

create policy "Users delete their own avatar"
  on storage.objects for delete
  using ( bucket_id = 'avatars'
          and auth.uid()::text = (storage.foldername(name))[1] );
