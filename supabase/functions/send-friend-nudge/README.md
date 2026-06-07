# send-friend-nudge Edge Function

Sends a fixed friend-to-friend APNs notification after verifying the caller is
signed in, the recipient is an accepted friend (`are_friends`), and the sender
has not delivered a `sent` nudge to the same recipient in the last 24 hours.
Every attempt is recorded in `public.friend_nudges` for the cooldown + audit.

Apply `docs/superpowers/specs/friend-nudges.sql` to the database before using
this function — it creates `push_tokens`, `friend_nudges`, and the token RPCs.

## Deploy

```bash
supabase functions deploy send-friend-nudge
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are injected
by the Supabase platform — you do not set them by hand.

## Required secrets

These come from your Apple Developer account (Keys → an APNs Auth Key, `.p8`):

```bash
supabase secrets set APNS_TEAM_ID=<10-char-team-id>
supabase secrets set APNS_KEY_ID=<10-char-key-id>
supabase secrets set APNS_PRIVATE_KEY="$(cat AuthKey_<key-id>.p8)"
supabase secrets set APNS_TOPIC=maxhagi.Daily-Music
supabase secrets set APNS_ENVIRONMENT=sandbox
```

- `APNS_TOPIC` is the app bundle identifier (`maxhagi.Daily-Music`).
- Use `APNS_ENVIRONMENT=sandbox` for development builds (tokens registered by a
  DEBUG build) and `production` for TestFlight / App Store builds. The function
  only sends to device tokens registered for the configured environment, so the
  app's registered environment and this secret must match.

## Manual test

```bash
curl -i -X POST \
  "https://jgzegntiwdrotkrswjba.supabase.co/functions/v1/send-friend-nudge" \
  -H "Authorization: Bearer <USER_ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"recipient_id":"<ACCEPTED_FRIEND_USER_ID>"}'
```

Expected responses:

```json
{"status":"sent"}
{"status":"no_tokens"}
{"status":"rate_limited","next_allowed_at":"2026-06-07T12:00:00.000Z"}
```
