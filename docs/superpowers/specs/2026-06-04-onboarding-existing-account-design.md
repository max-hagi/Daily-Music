# Onboarding for existing accounts — bug fix + polish

**Date:** 2026-06-04
**Status:** Approved, ready for implementation plan

## 1. Problem

An account exists (signed up by email) but never finished onboarding. On a fresh
install the local `hasCompletedOnboarding` flag is `false`, so the wizard runs —
but tapping **Finish** on the "Where do you listen?" step fails with *"Couldn't
save your profile. Check your connection and try again."* The user is stuck and
cannot enter the app.

The user also asked for onboarding polish: pre-fill what the account already
knows, slide animations between steps, a back button, and a visible
required-field indicator on the name.

## 2. Root cause (confirmed)

`profiles.settings` is **NOT NULL** (see
[`friend-graph.sql`](friend-graph.sql) line 40: *"that column is NOT NULL"*,
which is why friend-code generation manually seeds `insert into public.profiles
(id, settings) values (auth.uid(), '{}'::jsonb)`).

[`SupabaseProfileService.save()`](../../../Daily%20Music/Services/Supabase/SupabaseProfileService.swift)
upserts only `{id, display_name, avatar_url}`. When the `profiles` row does **not
exist yet** (no settings ever synced to the cloud), the upsert runs as an INSERT
with `settings = NULL` → NOT NULL violation → throws → the generic error above.
The settings service never hits this because it always provides `settings`.

There is **no signup trigger** creating the row (friend-graph has to seed it
manually), so the row is genuinely absent for an account that froze before
completing onboarding.

**Secondary latent bug:** the reminder time and streaming-service choices persist
through a 600 ms debounce owned by the onboarding view's `SettingsViewModel`. If
the user picks a service and taps Finish within that window, the view tears down
and the debounced `Task` is cancelled — the choice is silently lost.

## 3. Goals / non-goals

**Goals**
- Finish never fails for a valid signed-in user because the row is missing.
- The user's reminder/service choices can't be lost by finishing quickly.
- Onboarding pre-fills name, avatar, reminder, and streaming service from the account.
- Smooth forward/back slide animation between steps; a back button on steps 2–3.
- A visible required indicator on the name field.

**Non-goals (unchanged this round)**
- The onboarding **gate** stays as-is: `RootView.resolveOnboardingStatus()` skips
  the wizard when a `display_name` already exists ("skip if name exists"). No
  change to `RootView`.
- Avatar upload (Storage path/RLS) is untouched — it is a separate, working path.
- The reported "frozen welcome screen" is **assumed to be the same save failure**
  surfacing. If freezing persists after fix A, it is a separate debugging task.

## 4. Design

### A. Ensure the row exists before writing identity (primary fix)

In `SupabaseProfileService.save(displayName:avatarURL:)`, add an idempotent
"seed" upsert before the identity upsert:

```swift
func save(displayName: String?, avatarURL: String?) async throws {
    let userID = try await client.auth.session.user.id

    // profiles.settings is NOT NULL, so an identity-only INSERT (no settings)
    // violates the constraint when the row doesn't exist yet. Seed the row with
    // default settings if missing; ignoreDuplicates leaves an existing row — and
    // its real settings — untouched.
    try await client
        .from("profiles")
        .upsert(ProfileRowSeed(id: userID, settings: UserSettings()),
                onConflict: "id", ignoreDuplicates: true)
        .execute()

    // Row now guaranteed to exist → this takes the UPDATE path.
    try await client
        .from("profiles")
        .upsert(ProfileIdentityUpsert(id: userID, displayName: displayName, avatarURL: avatarURL),
                onConflict: "id")
        .execute()
}

private struct ProfileRowSeed: Encodable {
    let id: UUID
    let settings: UserSettings
}
```

`ignoreDuplicates: true` is supported by supabase-swift
([`PostgrestQueryBuilder.upsert`](../../../build/SourcePackages/checkouts/supabase-swift/Sources/PostgREST/PostgrestQueryBuilder.swift) line 104).
`UserSettings()` is the existing default-valued struct already encoded by the
settings service. Fix lives in the service, so it also protects the Settings
"Edit profile" path. No dashboard change required.

**Optional belt-and-suspenders (dashboard, one line):**
`alter table public.profiles alter column settings set default '{}'::jsonb;` —
makes any future identity-only INSERT safe at the schema level too.

### B. Flush settings on Finish (no lost choice)

Add to `SettingsViewModel`:

```swift
/// Cancel any pending debounce and persist immediately. Used when leaving a
/// screen (e.g. onboarding Finish) so a just-made choice can't be lost.
func flush() async {
    syncTask?.cancel()
    try? await settingsService.save(currentSettings)
}
```

Call it first in `OnboardingView.finish()`:

```swift
Task {
    await settings?.flush()        // persist reminder + service before completing
    do {
        try await env.profileStore.save(displayName: ..., avatarURL: avatarURL)
        hasCompletedOnboarding = true
    } catch {
        saveError = "Couldn't save your profile. Check your connection and try again."
        #if DEBUG
        print("Onboarding finish save failed:", error)   // diagnostic, never silent again
        #endif
    }
    isSaving = false
}
```

### C. Pre-fill from the account

In `OnboardingView`'s `.task`, after creating the `SettingsViewModel`, pull the
cloud settings so the reminder and streaming service reflect the account:

```swift
.task {
    if settings == nil {
        settings = SettingsViewModel(notifications: env.notifications, settings: env.settings)
    }
    await settings?.loadFromCloud()    // pre-select reminder + streaming service
    await env.profileStore.load()
    if let c = env.profileStore.current {
        displayName = c.displayName ?? ""
        avatarURL = c.avatarURL
    }
}
```

`loadFromCloud()` already guards its echo with `isApplyingRemote`, and returns a
no-op if no row/settings exist (falls back to the UserDefaults cache). Name and
avatar pre-fill already exist and stay.

### D. Slide animations between steps

Track direction and give the step content a real identity so SwiftUI runs
insertion/removal transitions:

```swift
private enum NavDirection { case forward, backward }
@State private var direction: NavDirection = .forward

private var slideTransition: AnyTransition {
    .asymmetric(
        insertion: .move(edge: direction == .forward ? .trailing : .leading).combined(with: .opacity),
        removal:   .move(edge: direction == .forward ? .leading  : .trailing).combined(with: .opacity)
    )
}
```

Wrap the `switch step` content in a single container view, apply
`.id(step).transition(slideTransition)`, and drive step changes inside
`withAnimation(.spring(response: 0.45, dampingFraction: 0.85))`. (If the moving
content bleeds past the edges, clip the step container horizontally.) The
existing progress-dots spring stays.

### E. Back button

Replace the top progress-dots row with a header that keeps the dots centered:

```
[ chevron.left (step>0) | spacer | progressDots | spacer | balance-spacer ]
```

The leading slot is a 44×44 back button when `step > 0`, otherwise a clear
44×44 placeholder; a matching clear 44×44 on the trailing keeps the dots
centered. Back calls:

```swift
private func goBack() {
    saveError = nil
    direction = .backward
    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step -= 1 }
}
```

`advance()` sets `direction = .forward` before incrementing. Continue/Finish and
the existing "Skip"/"Skip for now" affordances are unchanged.

### F. Required-name indicator

Add an opt-in flag to the shared `ProfileEditor` so Settings is unaffected:

```swift
struct ProfileEditor: View {
    @Binding var displayName: String
    @Binding var avatarURL: String?
    var nameRequired: Bool = false
    ...
}
```

Below the name field, when `nameRequired` is true, show a small centered caption
— a red `*` + "Required" — that fades out once a non-blank name is entered:

```swift
if nameRequired {
    HStack(spacing: 3) {
        Text("*").foregroundStyle(.red)
        Text("Required").foregroundStyle(.secondary)
    }
    .font(.caption)
    .opacity(displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 1 : 0)
    .animation(.easeInOut(duration: 0.2), value: displayName)
}
```

`OnboardingHelloStep` passes `nameRequired: true`; the Settings "Edit profile"
caller keeps the default (`false`). Style is easily swapped to a label-with-
asterisk above the field if preferred.

## 5. Onboarding Finish — data flow

1. `flush()` cancels the settings debounce and writes `currentSettings`
   (reminder + service) to `profiles` (creates the row with valid settings if
   absent).
2. `profileStore.save()` → `SupabaseProfileService.save()`: seed-upsert
   (no-op now, row exists) → identity upsert (UPDATE) sets name/avatar.
3. `profileStore.load()` refreshes `current`.
4. `hasCompletedOnboarding = true` → `RootView` springs to `MainTabView`.

Either step 1 or the seed in step 2 guarantees the row exists with non-null
settings, so the identity write can never hit the NOT NULL violation again.

## 6. Error handling

- Finish keeps showing the friendly retry message on failure; in DEBUG the real
  error is printed so a future failure is never undiagnosable.
- `flush()` and `loadFromCloud()` use `try?` — a transient settings sync failure
  must not block finishing or crash onboarding (settings also persist locally in
  UserDefaults).

## 7. Testing / verification

- **Manual (the repro):** signed-in account with **no** `profiles` row → run
  onboarding → enter a name → Finish succeeds and lands in the app.
- **Lost-choice race:** pick a non-default streaming service, tap Finish
  immediately → after relaunch the chosen service is still selected.
- **Pre-fill:** with a service/reminder already saved in the cloud, the wizard
  shows them pre-selected.
- **Required indicator:** empty name shows "* Required"; it fades when typed;
  Continue stays disabled while blank.
- **Back + animation:** forward slides left-to-right, back slides the reverse;
  dots stay centered; back is hidden on step 1.
- **Settings unaffected:** "Edit profile" shows no required caption and still saves.

## 8. Files touched

| File | Change |
|------|--------|
| `Services/Supabase/SupabaseProfileService.swift` | A — seed-row upsert + `ProfileRowSeed` |
| `ViewModels/SettingsViewModel.swift` | B — `flush()` |
| `Views/Onboarding/OnboardingView.swift` | B call, C `loadFromCloud`, D transitions, E back button |
| `Views/Onboarding/OnboardingHelloStep.swift` | F — pass `nameRequired: true` |
| `Views/Components/ProfileEditor.swift` | F — `nameRequired` param + indicator |
| *(optional)* Supabase dashboard | A — `settings` default `'{}'::jsonb` |
