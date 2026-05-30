//
//  AuthService.swift
//  Daily Music
//
//  Auth seam. v1 ships MockAuthService; later we add a SupabaseAuthService that
//  implements the same protocol using Supabase Auth + Sign in with Apple.
//

import Foundation

struct AuthSession: Equatable {
    let userID: UUID
    let displayName: String?
    /// True when the user tapped the DEBUG-only "skip" path rather than signing in.
    let isGuest: Bool
}

protocol AuthService {
    /// Returns an existing session on launch, or nil if signed out.
    func restoreSession() async -> AuthSession?
    /// Performs Sign in with Apple. Throws if cancelled or it fails.
    func signInWithApple() async throws -> AuthSession
    /// DEBUG-only path so we don't sign in on every run while developing.
    func continueAsGuest() -> AuthSession
    func signOut() async
}

/// In-memory stand-in. Sign-in "succeeds" instantly with a stable fake user.
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
        try? await Task.sleep(for: .milliseconds(400)) // mimic the auth round-trip
        return fakeUser
    }

    func continueAsGuest() -> AuthSession {
        AuthSession(
            userID: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!,
            displayName: "Guest",
            isGuest: true
        )
    }

    func signOut() async {}
}
