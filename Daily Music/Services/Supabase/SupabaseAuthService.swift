//
//  SupabaseAuthService.swift
//  Daily Music
//
//  Live auth backed by Supabase. For now the working path is ANONYMOUS sign-in:
//  it creates a real row in auth.users with a JWT, which is what the favourites
//  table's Row-Level Security (auth.uid() = user_id) needs. Later, real Sign in
//  with Apple (which needs the paid-account entitlement) can be linked to the
//  same anonymous user so nothing is lost.
//
//  Requires "Allow anonymous sign-ins" to be enabled in the Supabase dashboard:
//    Authentication → Sign In / Providers → Anonymous Sign-ins → ON
//

import Foundation
import Supabase

final class SupabaseAuthService: AuthService {
    private let client = Supa.client

    func restoreSession() async -> AuthSession? {
        guard let session = try? await client.auth.session else { return nil }
        return Self.map(session.user)
    }

    func signInWithApple() async throws -> AuthSession {
        // TODO: swap in the real ASAuthorization Sign in with Apple flow once the
        // Apple Developer entitlement is available; the anonymous user can then be
        // linked to the Apple identity so nothing is lost. Until then, this uses an
        // anonymous Supabase session so the primary button has a working path.
        let session = try await client.auth.signInAnonymously()
        return Self.map(session.user)
    }

    func continueAsGuest() async throws -> AuthSession {
        let session = try await client.auth.signInAnonymously()
        return Self.map(session.user)
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    private static func map(_ user: User) -> AuthSession {
        AuthSession(
            userID: user.id,
            displayName: user.email,
            isGuest: user.isAnonymous
        )
    }
}
