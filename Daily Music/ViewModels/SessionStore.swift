//
//  SessionStore.swift
//  Daily Music
//
//  Owns "who is signed in" for the whole app. RootView watches this to decide
//  between the sign-in screen and the main tabs.
//

import Foundation

// A "store" is a view-model-ish object that owns shared app state. This one holds
// the auth session and exposes it observably so RootView re-renders on sign-in/out.
// It depends on the AuthService PROTOCOL, so it works with mock or live auth.
@MainActor
@Observable
final class SessionStore {
    private(set) var session: AuthSession?     // nil = signed out
    private(set) var isWorking = false         // true while a sign-in call is in flight (drives spinners)
    /// Surfaced to the sign-in screen so failures are never silent.
    private(set) var errorMessage: String?

    private let auth: AuthService

    init(auth: AuthService) {
        self.auth = auth
    }

    // Derived convenience: a computed Bool views can read directly.
    var isSignedIn: Bool { session != nil }

    /// Called once on launch to pick up an existing session.
    func restore() async {
        session = await auth.restoreSession()
    }

    // Both sign-in paths funnel through `attempt`, passing the differing call as a
    // closure. Keeps the loading/error/rollback bookkeeping in one place (DRY).
    func signInWithApple() async {
        await attempt { try await self.auth.signInWithApple() }
    }

    func continueAsGuest() async {
        await attempt { try await self.auth.continueAsGuest() }
    }

    // `work` is the operation to run. `@escaping` means the closure may outlive
    // this function call (it's awaited), so Swift needs to retain it.
    private func attempt(_ work: @escaping () async throws -> AuthSession) async {
        isWorking = true
        errorMessage = nil
        // `defer` runs its block when the function exits, NO MATTER HOW (success,
        // throw, early return). Perfect for "always turn the spinner back off".
        defer { isWorking = false }
        do {
            session = try await work()        // success → we're signed in
        } catch {
            errorMessage = Self.describe(error)   // failure → show a message instead of crashing
        }
    }

    private static func describe(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.localizedCaseInsensitiveContains("anonymous") {
            return "Sign-in isn't enabled yet: anonymous sign-ins are turned off in Supabase. Enable them in Authentication → Sign In / Providers → Anonymous."
        }
        return "Sign-in failed: \(raw)"
    }

    func signOut() async {
        await auth.signOut()
        session = nil
    }
}
