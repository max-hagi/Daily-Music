# Onboarding OTP Recovery + Reminder Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve email OTP-pending state while the app is running and simplify onboarding reminders so Continue enables reminders and Skip leaves them off.

**Architecture:** Move the OTP-pending email into `SessionStore`, which already owns app-wide auth state and naturally survives sheet teardown without surviving app relaunch. Make `EmailSignInSheet` derive its current step from that store state. Remove the reminder toggle from the onboarding step and route the parent wizard buttons through explicit enable/skip reminder actions.

**Tech Stack:** Swift, SwiftUI, Swift Testing, Xcode project file, Supabase-backed auth through the existing `AuthService` protocol.

---

## File Structure

- Modify `Daily Music/ViewModels/SessionStore.swift`
  - Owns in-memory `pendingEmailCodeEmail`.
  - Normalizes emails before sending/verifying OTPs.
  - Clears pending state only after explicit clear, sign-out/account deletion, or successful verification.
- Modify `Daily Music/Views/EmailSignInSheet.swift`
  - Removes local `codeSent`.
  - Shows email entry or code entry based on `env.session.pendingEmailCodeEmail`.
  - Adds `Resend code`, keeps toolbar close non-destructive, and makes `Use a different email` explicit.
- Modify `Daily Music/Views/Onboarding/OnboardingReminderStep.swift`
  - Removes the reminder toggle.
  - Keeps title, explanatory copy, time picker, and a denied-permission message.
- Modify `Daily Music/Views/Onboarding/OnboardingView.swift`
  - Routes Continue on reminder step through notification permission and scheduling.
  - Routes Skip on reminder step through reminder disable/cancel.
- Create `Daily MusicTests/SessionStoreTests.swift`
  - Covers pending OTP state transitions.
- Modify `Daily Music.xcodeproj/project.pbxproj`
  - Adds `SessionStoreTests.swift` to the test group and test target sources.

---

### Task 1: Add failing SessionStore OTP tests

**Files:**
- Create: `Daily MusicTests/SessionStoreTests.swift`
- Modify: `Daily Music.xcodeproj/project.pbxproj`
- Test: `Daily MusicTests/SessionStoreTests.swift`

- [ ] **Step 1: Create the failing test file**

Create `Daily MusicTests/SessionStoreTests.swift` with:

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct SessionStoreTests {
    @Test func sendingEmailCodeStoresNormalizedPendingEmail() async {
        let auth = RecordingAuthService()
        let store = SessionStore(auth: auth)

        let sent = await store.sendEmailCode(to: "  PERSON@Example.COM  ")

        #expect(sent)
        #expect(auth.sendEmailCalls == ["person@example.com"])
        #expect(store.pendingEmailCodeEmail == "person@example.com")
        #expect(store.hasPendingEmailCode)
    }

    @Test func pendingEmailSurvivesViewTeardownBecauseStoreOwnsIt() async {
        let store = SessionStore(auth: RecordingAuthService())

        _ = await store.sendEmailCode(to: "listener@example.com")
        let reopenedSheetWouldRead = store.pendingEmailCodeEmail

        #expect(reopenedSheetWouldRead == "listener@example.com")
        #expect(store.hasPendingEmailCode)
    }

    @Test func failedResendKeepsExistingPendingEmail() async {
        let auth = RecordingAuthService()
        let store = SessionStore(auth: auth)

        _ = await store.sendEmailCode(to: "first@example.com")
        auth.sendError = AuthTestError.message("network offline")

        let sent = await store.sendEmailCode(to: "second@example.com")

        #expect(!sent)
        #expect(store.pendingEmailCodeEmail == "first@example.com")
        #expect(auth.sendEmailCalls == ["first@example.com", "second@example.com"])
    }

    @Test func failedVerificationKeepsPendingEmail() async {
        let auth = RecordingAuthService()
        let store = SessionStore(auth: auth)

        _ = await store.sendEmailCode(to: "person@example.com")
        auth.verifyError = AuthTestError.message("bad code")

        await store.verifyEmailCode("111111", email: "person@example.com")

        #expect(store.pendingEmailCodeEmail == "person@example.com")
        #expect(!store.isSignedIn)
        #expect(store.errorMessage?.contains("bad code") == true)
    }

    @Test func successfulVerificationClearsPendingEmail() async {
        let auth = RecordingAuthService()
        let store = SessionStore(auth: auth)

        _ = await store.sendEmailCode(to: "person@example.com")
        await store.verifyEmailCode("123456", email: "person@example.com")

        #expect(store.pendingEmailCodeEmail == nil)
        #expect(!store.hasPendingEmailCode)
        #expect(store.isSignedIn)
        #expect(auth.verifyEmailCalls.map(\.email) == ["person@example.com"])
    }

    @Test func explicitClearRemovesPendingEmailAndError() async {
        let auth = RecordingAuthService()
        let store = SessionStore(auth: auth)

        _ = await store.sendEmailCode(to: "person@example.com")
        auth.verifyError = AuthTestError.message("bad code")
        await store.verifyEmailCode("000000", email: "person@example.com")

        store.clearPendingEmailCode()

        #expect(store.pendingEmailCodeEmail == nil)
        #expect(!store.hasPendingEmailCode)
        #expect(store.errorMessage == nil)
    }
}

private final class RecordingAuthService: AuthService {
    var sendEmailCalls: [String] = []
    var verifyEmailCalls: [(code: String, email: String)] = []
    var sendError: Error?
    var verifyError: Error?

    private let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!

    func restoreSession() async -> AuthSession? {
        nil
    }

    func signInWithApple() async throws -> AuthSession {
        AuthSession(userID: userID, displayName: "Tester", isGuest: false)
    }

    func continueAsGuest() async throws -> AuthSession {
        AuthSession(userID: userID, displayName: "Guest", isGuest: true)
    }

    func sendEmailCode(to email: String) async throws {
        sendEmailCalls.append(email)
        if let sendError {
            throw sendError
        }
    }

    func verifyEmailCode(_ code: String, email: String) async throws -> AuthSession {
        verifyEmailCalls.append((code, email))
        if let verifyError {
            throw verifyError
        }
        return AuthSession(userID: userID, displayName: email, isGuest: false)
    }

    func signOut() async {}

    func deleteAccount() async throws {}
}

private enum AuthTestError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            message
        }
    }
}
```

- [ ] **Step 2: Add the test file to the Xcode project**

Modify `Daily Music.xcodeproj/project.pbxproj` in four places.

In the `PBXBuildFile section`, add:

```text
		C7F0B6A12E7D4C11A9E0A001 /* SessionStoreTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = C7F0B6A12E7D4C11A9E0A002 /* SessionStoreTests.swift */; };
```

In the `PBXFileReference section`, add:

```text
		C7F0B6A12E7D4C11A9E0A002 /* SessionStoreTests.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = SessionStoreTests.swift; sourceTree = "<group>"; };
```

In the `474DB509253B3672F8A852C1 /* Daily MusicTests */` group `children`, add this after `FriendsStoreTests.swift`:

```text
				C7F0B6A12E7D4C11A9E0A002 /* SessionStoreTests.swift */,
```

In the `6789B102B0603D9006D93D6A /* Sources */` build phase `files`, add this after `FriendsStoreTests.swift in Sources`:

```text
				C7F0B6A12E7D4C11A9E0A001 /* SessionStoreTests.swift in Sources */,
```

- [ ] **Step 3: Run tests and verify they fail for the right reason**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:Daily_MusicTests/SessionStoreTests
```

Expected: FAIL at compile time with errors that `SessionStore` has no member `pendingEmailCodeEmail`, no member `hasPendingEmailCode`, and no member `clearPendingEmailCode`.

- [ ] **Step 4: Commit the failing tests**

Run:

```bash
git add "Daily MusicTests/SessionStoreTests.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "test: cover pending email otp state"
```

---

### Task 2: Implement pending OTP state in SessionStore

**Files:**
- Modify: `Daily Music/ViewModels/SessionStore.swift`
- Test: `Daily MusicTests/SessionStoreTests.swift`

- [ ] **Step 1: Add pending state and normalization helpers**

In `SessionStore`, add this stored property near `errorMessage`:

```swift
    /// Email waiting for a one-time code during this app run. This intentionally
    /// lives only in memory so relaunching the app starts the email flow fresh.
    private(set) var pendingEmailCodeEmail: String?
```

Add this computed property near `isSignedIn`:

```swift
    var hasPendingEmailCode: Bool { pendingEmailCodeEmail != nil }
```

Add this helper near `describe(_:)`:

```swift
    private static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
```

- [ ] **Step 2: Update `sendEmailCode(to:)`**

Replace `sendEmailCode(to:)` with:

```swift
    /// Step 1 of email sign-in. Returns true if the code was sent, so the UI can
    /// advance to the code-entry step.
    func sendEmailCode(to email: String) async -> Bool {
        let normalizedEmail = Self.normalizedEmail(email)
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await auth.sendEmailCode(to: normalizedEmail)
            pendingEmailCodeEmail = normalizedEmail
            return true
        } catch {
            errorMessage = "Couldn't send the code: \(error.localizedDescription)"
            return false
        }
    }
```

- [ ] **Step 3: Update `verifyEmailCode(_:email:)` and add explicit clear**

Replace `verifyEmailCode(_:email:)` with:

```swift
    /// Step 2 of email sign-in — verifying signs the user in (sets `session`).
    func verifyEmailCode(_ code: String, email: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            session = try await auth.verifyEmailCode(
                code,
                email: Self.normalizedEmail(email)
            )
            pendingEmailCodeEmail = nil
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    func clearPendingEmailCode() {
        pendingEmailCodeEmail = nil
        errorMessage = nil
    }
```

- [ ] **Step 4: Clear pending OTP on sign-out and account deletion**

Replace `signOut()` with:

```swift
    func signOut() async {
        await auth.signOut()
        session = nil
        pendingEmailCodeEmail = nil
    }
```

In `deleteAccount()`, after `session = nil`, add:

```swift
            pendingEmailCodeEmail = nil
```

The success block should become:

```swift
        do {
            try await auth.deleteAccount()
            session = nil
            pendingEmailCodeEmail = nil
            return true
        } catch {
            errorMessage = "Couldn't delete your account: \(error.localizedDescription)"
            return false
        }
```

- [ ] **Step 5: Run the SessionStore tests**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:Daily_MusicTests/SessionStoreTests
```

Expected: PASS for all `SessionStoreTests`.

- [ ] **Step 6: Commit SessionStore implementation**

Run:

```bash
git add "Daily Music/ViewModels/SessionStore.swift"
git commit -m "feat: preserve pending email otp state"
```

---

### Task 3: Update EmailSignInSheet to use SessionStore state

**Files:**
- Modify: `Daily Music/Views/EmailSignInSheet.swift`
- Test: `Daily MusicTests/SessionStoreTests.swift`

- [ ] **Step 1: Replace local code-sent state with SessionStore-derived state**

Replace the body of `EmailSignInSheet` with this version:

```swift
struct EmailSignInSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""

    private var pendingEmail: String? {
        env.session.pendingEmailCodeEmail
    }

    var body: some View {
        NavigationStack {
            Form {
                if pendingEmail == nil {
                    Section {
                        TextField(text: $email, prompt: Text("you@example.com").foregroundStyle(.secondary)) {
                            Text("Email address")
                        }
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Email")
                    } footer: {
                        Text("We'll email you a 6-digit sign-in code.")
                    }

                    Section {
                        Button(action: sendCode) {
                            centeredLabel("Email me a code")
                        }
                        .disabled(trimmedEmail.isEmpty || env.session.isWorking)
                    }
                } else if let pendingEmail {
                    Section {
                        TextField("6-digit code", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    } header: {
                        Text("Enter code")
                    } footer: {
                        Text("Sent to \(pendingEmail). Check your inbox (and spam).")
                    }

                    Section {
                        Button(action: verify) {
                            centeredLabel("Verify & sign in")
                        }
                        .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || env.session.isWorking)

                        Button(action: resendCode) {
                            centeredLabel("Resend code")
                        }
                        .disabled(env.session.isWorking)

                        Button("Use a different email") {
                            env.session.clearPendingEmailCode()
                            email = ""
                            code = ""
                        }
                        .foregroundStyle(.secondary)
                        .disabled(env.session.isWorking)
                    }
                }

                if let error = env.session.errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Sign in with email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear(perform: seedEmailFromPendingCode)
        // Verifying sets the session; close the sheet the moment we're signed in.
        .onChange(of: env.session.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func centeredLabel(_ title: String) -> some View {
        HStack {
            Spacer()
            if env.session.isWorking {
                ProgressView()
            } else {
                Text(title).fontWeight(.semibold)
            }
            Spacer()
        }
    }

    private func seedEmailFromPendingCode() {
        if let pendingEmail, email.isEmpty {
            email = pendingEmail
        }
    }

    private func sendCode() {
        Task {
            _ = await env.session.sendEmailCode(to: trimmedEmail)
        }
    }

    private func resendCode() {
        guard let pendingEmail else { return }
        Task {
            _ = await env.session.sendEmailCode(to: pendingEmail)
        }
    }

    private func verify() {
        guard let pendingEmail else { return }
        Task {
            await env.session.verifyEmailCode(
                code.trimmingCharacters(in: .whitespacesAndNewlines),
                email: pendingEmail
            )
        }
    }
}
```

- [ ] **Step 2: Run the auth tests**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:Daily_MusicTests/SessionStoreTests
```

Expected: PASS. These tests prove the view is backed by durable in-memory session state.

- [ ] **Step 3: Build the app target**

Run:

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit sheet update**

Run:

```bash
git add "Daily Music/Views/EmailSignInSheet.swift"
git commit -m "feat: restore email otp entry sheet"
```

---

### Task 4: Simplify onboarding reminders

**Files:**
- Modify: `Daily Music/Views/Onboarding/OnboardingReminderStep.swift`
- Modify: `Daily Music/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Remove the reminder toggle from the step UI**

Replace `OnboardingReminderStep` with:

```swift
import SwiftUI

struct OnboardingReminderStep: View {
    @Bindable var settings: SettingsViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Never miss a day")
                .font(.system(size: 28, weight: .heavy, design: .rounded))

            Text("Pick when you want the daily nudge.")
                .foregroundStyle(.secondary)

            DatePicker("Reminder time", selection: $settings.reminderTime,
                       displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            if settings.permissionDenied {
                Text("Notifications are blocked right now. You can skip for now or enable them in Settings later.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }
}
```

- [ ] **Step 2: Route onboarding button actions through reminder enable/skip logic**

In `OnboardingView`, add this state near `isSaving`:

```swift
    @State private var isApplyingReminder = false
```

Replace the primary button action in `buttons`:

```swift
            Button { advance() } label: {
```

with:

```swift
            Button { primaryAction() } label: {
```

Replace the primary button disabled modifier:

```swift
            .disabled((step == 0 && !nameFilled) || isSaving)
```

with:

```swift
            .disabled((step == 0 && !nameFilled) || isSaving || isApplyingReminder)
```

Replace the skip button action:

```swift
                Button(step == totalSteps - 1 ? "Skip" : "Skip for now") { advance() }
```

with:

```swift
                Button(step == totalSteps - 1 ? "Skip" : "Skip for now") { skipAction() }
```

Replace the skip button disabled modifier:

```swift
                    .disabled(isSaving)
```

with:

```swift
                    .disabled(isSaving || isApplyingReminder)
```

Add these methods above `advance()`:

```swift
    private func primaryAction() {
        guard step == 1 else {
            advance()
            return
        }
        enableReminderAndAdvance()
    }

    private func skipAction() {
        guard step == 1 else {
            advance()
            return
        }
        disableReminderAndAdvance()
    }

    private func enableReminderAndAdvance() {
        guard let settings else { return }
        saveError = nil
        isApplyingReminder = true
        Task {
            settings.reminderEnabled = true
            await settings.applyReminderSetting(enabled: true)
            isApplyingReminder = false
            if !settings.permissionDenied {
                advance()
            }
        }
    }

    private func disableReminderAndAdvance() {
        guard let settings else { return }
        saveError = nil
        isApplyingReminder = true
        Task {
            settings.reminderEnabled = false
            await settings.applyReminderSetting(enabled: false)
            isApplyingReminder = false
            advance()
        }
    }
```

- [ ] **Step 3: Build the app target**

Run:

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit reminder simplification**

Run:

```bash
git add "Daily Music/Views/Onboarding/OnboardingReminderStep.swift" "Daily Music/Views/Onboarding/OnboardingView.swift"
git commit -m "feat: simplify onboarding reminders"
```

---

### Task 5: Full verification

**Files:**
- Verify: `Daily Music/ViewModels/SessionStore.swift`
- Verify: `Daily Music/Views/EmailSignInSheet.swift`
- Verify: `Daily Music/Views/Onboarding/OnboardingReminderStep.swift`
- Verify: `Daily Music/Views/Onboarding/OnboardingView.swift`
- Verify: `Daily MusicTests/SessionStoreTests.swift`

- [ ] **Step 1: Run the full test suite**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: TEST SUCCEEDED.

- [ ] **Step 2: Manually verify the OTP recovery flow**

Run the app in the simulator from Xcode or with:

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Manual checks:

- Open sign-in and tap `Continue with email`.
- Enter an email and tap `Email me a code`.
- Confirm the sheet shows `Enter code`.
- Tap `Close`.
- Tap `Continue with email` again.
- Confirm the sheet still shows `Enter code` for the same email.
- Tap `Use a different email`.
- Confirm the sheet returns to the email-entry form.
- Send another code, tap `Resend code`, and confirm the sheet stays on code entry.
- Enter a valid code and confirm the sheet dismisses after sign-in.

- [ ] **Step 3: Manually verify the reminder onboarding flow**

Manual checks:

- Sign in as a user that has not completed onboarding.
- Proceed to the reminder step.
- Confirm there is no `Daily reminder` toggle.
- Change the time and tap `Continue`.
- Grant notification permission when prompted.
- Confirm the wizard advances to the listening step.
- Restart onboarding with reminders disabled, reach the reminder step, and tap `Skip for now`.
- Confirm the wizard advances without requesting notification permission and `settings.reminderEnabled` remains false.
- If notification permission is denied, tap `Continue` and confirm the wizard stays on the reminder step with the denied-permission message and `Skip for now` remains available.

- [ ] **Step 4: Check git status**

Run:

```bash
git status --short
```

Expected: only unrelated pre-existing work remains unstaged. Do not stage or revert `Daily Music/Views/Friends/FriendsView.swift` unless the user separately asks for it.

- [ ] **Step 5: Commit final verification note only if code changed after Task 4**

If manual verification required code changes, commit those exact changed files:

```bash
git add "Daily Music/ViewModels/SessionStore.swift" "Daily Music/Views/EmailSignInSheet.swift" "Daily Music/Views/Onboarding/OnboardingReminderStep.swift" "Daily Music/Views/Onboarding/OnboardingView.swift" "Daily MusicTests/SessionStoreTests.swift" "Daily Music.xcodeproj/project.pbxproj"
git commit -m "fix: polish onboarding otp reminders"
```

If no code changed after Task 4, do not create an empty commit.
