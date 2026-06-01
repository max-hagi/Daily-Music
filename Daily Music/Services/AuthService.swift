//
//  AuthService.swift
//  Daily Music
//
//  Auth seam. The mock signs in with fake local users; the live service uses
//  Supabase Auth today and can later link real Sign in with Apple identities.
//

import Foundation

// A small value type describing the logged-in user. Equatable so SwiftUI can
// detect when the session changes (e.g. signed in → out) and react.
struct AuthSession: Equatable {
    let userID: UUID
    let displayName: String?
    /// True when the user tapped the DEBUG-only "skip" path rather than signing in.
    let isGuest: Bool
}

// This protocol is the "seam": it lists WHAT auth can do without saying HOW.
// Views/stores depend on this abstraction, and we plug in either MockAuthService
// (below) or SupabaseAuthService at composition time. `async` = may suspend
// (network); `throws` = may fail and the caller must handle the error with
// `try`. A method that's `async` but not `throws` (like restoreSession) just
// returns nil instead of erroring.
protocol AuthService {
    /// Returns an existing session on launch, or nil if signed out.
    func restoreSession() async -> AuthSession?
    /// Performs Sign in with Apple. Throws if cancelled or it fails.
    func signInWithApple() async throws -> AuthSession
    /// DEBUG-only path so we don't sign in on every run while developing.
    /// Backed by Supabase anonymous sign-in in the live service, so it's async.
    func continueAsGuest() async throws -> AuthSession
    /// Email magic-link, step 1: send a one-time code to the address.
    func sendEmailCode(to email: String) async throws
    /// Email magic-link, step 2: exchange the code for a real session.
    func verifyEmailCode(_ code: String, email: String) async throws -> AuthSession
    func signOut() async
}

/// In-memory stand-in. Sign-in "succeeds" instantly with a stable fake user.
// "Conforms to" AuthService — the compiler now requires every protocol method
// to be implemented here.
final class MockAuthService: AuthService {
    private let fakeUser = AuthSession(
        userID: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
        displayName: "Maxime",
        isGuest: false
    )

    func restoreSession() async -> AuthSession? {
        // Start signed out so you can exercise the sign-in screen during dev.
        nil
    }

    func signInWithApple() async throws -> AuthSession {
        // Task.sleep suspends without blocking the thread — a cheap way to fake a
        // network delay so the UI's loading state is visible during development.
        try? await Task.sleep(for: .milliseconds(400)) // mimic the auth round-trip
        return fakeUser
    }

    func continueAsGuest() async throws -> AuthSession {
        AuthSession(
            userID: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!,
            displayName: "Guest",
            isGuest: true
        )
    }

    func sendEmailCode(to email: String) async throws {
        try? await Task.sleep(for: .milliseconds(300))
    }

    func verifyEmailCode(_ code: String, email: String) async throws -> AuthSession {
        try? await Task.sleep(for: .milliseconds(300))
        return AuthSession(
            userID: UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!,
            displayName: email,
            isGuest: false
        )
    }

    func signOut() async {}
}
