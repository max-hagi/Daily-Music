# delete-account Edge Function

Permanently deletes the calling user's account and all their data. Backs the
in-app "Delete account" button (App Store guideline 5.1.1(v) requires in-app
account deletion for any app that supports account creation).

## Deploy

Install the Supabase CLI once, then from the repo root:

```bash
supabase login                      # one-time
supabase link --project-ref jgzegntiwdrotkrswjba
supabase functions deploy delete-account
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are injected
by the platform automatically — do **not** add them to the app or commit them.

## How it works

1. Reads the caller's JWT from the `Authorization` header (sent automatically by
   the iOS app via `client.functions.invoke("delete-account")`).
2. Resolves the user id from that token — a user can only delete themselves.
3. Uses the service-role key to delete their rows in `reactions`, `check_ins`,
   `favourites`, and `profiles`, then deletes the `auth.users` record.

## Optional: let the database cascade instead

If you add `ON DELETE CASCADE` foreign keys to `auth.users(id)`, the explicit
row deletes in `index.ts` become no-ops and you can rely on step 4 alone:

```sql
-- example for one table; repeat per user-scoped table
alter table public.reactions
  drop constraint if exists reactions_user_id_fkey,
  add constraint reactions_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete cascade;
```

## Test

```bash
# Grab a logged-in user's access token from the app/session, then:
curl -i -X POST \
  "https://jgzegntiwdrotkrswjba.supabase.co/functions/v1/delete-account" \
  -H "Authorization: Bearer <USER_ACCESS_TOKEN>"
# → {"success":true}
```
