# Onboarding OTP recovery + reminder step simplification

**Date:** 2026-06-06
**Status:** Approved in chat; awaiting written-spec review

## 1. Problem

The email sign-in sheet currently stores its OTP flow state locally:

- `email`
- `code`
- `codeSent`

If the user closes the sheet after requesting a code, reopening the sheet starts
from the email-entry step again. That is fragile during onboarding because users
often leave the app or close the sheet while checking their email for the code.

The onboarding reminder step also has two ways to opt out: a `Daily reminder`
toggle inside the step and a parent `Skip for now` button below it. The toggle
adds a redundant decision at the exact point where the wizard already has a
clear affirmative action (`Continue`) and a clear opt-out action (`Skip for now`).

## 2. Goals / non-goals

**Goals**
- Keep the email sign-in sheet on code entry after a code has been sent, even if
  the sheet is dismissed and reopened during the same app run.
- Replace the pending OTP email when sending/resending a code succeeds, and
  clear it only when the user deliberately starts over or signs in successfully.
- Do not preserve OTP-pending state across full app relaunch.
- Simplify the reminder onboarding step so `Continue` enables reminders at the
  selected time and `Skip for now` leaves reminders off.

**Non-goals**
- No persistent storage for OTP state (`UserDefaults`, Keychain, database).
- No change to Supabase OTP expiration or verification behavior.
- No change to the existing post-sign-in onboarding gate.
- No redesign of Settings' reminder controls; the toggle can remain in Settings
  where users need an ongoing preference switch.

## 3. Current state

`EmailSignInSheet` owns the OTP UI state with local `@State`, so dismissing the
sheet destroys the fact that an email code is pending.

`SessionStore` already owns the app-wide auth session, loading state, and auth
errors. It is the right scope for an in-memory pending-email-code state because
it survives view teardown during one app run without persisting across relaunch.

`OnboardingReminderStep` owns a `Toggle("Daily reminder")`. `OnboardingView`
already displays `Skip for now` on optional steps, including reminders.

## 4. Design

### A. Move pending OTP state into `SessionStore`

Add in-memory state to `SessionStore`:

```swift
private(set) var pendingEmailCodeEmail: String?

var hasPendingEmailCode: Bool {
    pendingEmailCodeEmail != nil
}
```

`sendEmailCode(to:)` should normalize/trim the email it receives. On success, it
sets `pendingEmailCodeEmail` to that normalized email. On failure, it leaves any
existing pending state unchanged so a failed resend does not strand the user.

`verifyEmailCode(_:email:)` should clear `pendingEmailCodeEmail` after a
successful sign-in. It can keep the pending email after a failed verification so
the user can correct the code and retry.

Add an explicit reset method:

```swift
func clearPendingEmailCode()
```

This method clears the pending email and any current auth error. The UI uses it
only for deliberate start-over actions.

### B. Make the email sheet derive its step from session state

`EmailSignInSheet` keeps local `email` and `code` fields, but removes local
`codeSent`. The sheet shows code entry when `env.session.pendingEmailCodeEmail`
is non-nil.

When the sheet appears, if there is a pending email, it seeds the local `email`
field from `env.session.pendingEmailCodeEmail`. This means reopening the sheet
returns to code entry for the same email.

The top toolbar action should be treated as a harmless close/dismiss action. It
should preserve the pending OTP state, and its label should avoid implying that
it cancels the flow. The deliberate start-over action inside the code-entry form
clears pending state and returns to the email-entry form.

Code-entry actions:

- `Verify & sign in`: verifies the typed code against the pending email.
- `Resend code`: calls `sendEmailCode(to:)` for the pending email and keeps the
  sheet on code entry.
- `Use a different email`: calls `clearPendingEmailCode()`, clears the local
  code, and returns to the email-entry form.

### C. Simplify the reminder onboarding step

Remove `Toggle("Daily reminder")` from `OnboardingReminderStep`.

The step should contain:

- title
- short explanatory copy
- wheel `DatePicker` for reminder time

In `OnboardingView.advance()`, when the current step is the reminder step and
the user taps `Continue`, set `settings.reminderEnabled = true` and call
`settings.applyReminderSetting(enabled: true)` before moving forward. If
permission is denied, keep the user on the step and surface the existing
permission-denied state so the user can skip or retry.

When the user taps `Skip for now` on the reminder step, set
`settings.reminderEnabled = false`, call `settings.applyReminderSetting(enabled:
false)`, and advance.

This keeps the wizard semantics simple:

- `Continue` means "enable reminders at this time."
- `Skip for now` means "do not enable reminders."

### D. Error handling

OTP send errors continue to use `SessionStore.errorMessage`.

OTP verify errors keep the user on code entry.

Reminder permission denial should not silently advance. The step should show the
existing denied state, while `Skip for now` remains available.

## 5. Testing

Add focused tests around `SessionStore`:

- sending a code stores the pending email
- reopening-style access reads the same pending email from the store
- failed verification keeps the pending email
- successful verification clears the pending email
- explicit clear removes the pending email

Manually verify the onboarding UI flow:

- send a code, close the sheet, reopen it, and confirm code entry is still shown
- use a different email and confirm email entry is shown
- resend from code entry and confirm it stays on code entry
- continue through the reminder step and confirm reminders are enabled
- skip the reminder step and confirm reminders remain disabled
