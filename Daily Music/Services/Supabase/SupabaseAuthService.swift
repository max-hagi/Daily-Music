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
        // `client.auth.session` throws if there's no persisted session. `try?`
        // turns that into nil → guard bails → we report "signed out". The SDK
        // persists the session to the keychain, so a returning user is restored.
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
        // Creates a real auth.users row with a JWT — that's what favourites/check-ins
        // RLS policies key off (auth.uid() = user_id).
        let session = try await client.auth.signInAnonymously()
        return Self.map(session.user)
    }

    func sendEmailCode(to email: String) async throws {
        // Sends the email; with a 6-digit token in the template the user types it
        // back (no deep-link needed). `shouldCreateUser: true` lets first-time
        // email users sign up, while existing emails sign back into the existing
        // Supabase auth user rather than creating a duplicate account.
        try await client.auth.signInWithOTP(email: normalizedEmail(email), shouldCreateUser: true)
    }

    func verifyEmailCode(_ code: String, email: String) async throws -> AuthSession {
        let response = try await client.auth.verifyOTP(email: normalizedEmail(email), token: code, type: .email)
        guard let session = response.session else {
            throw NSError(domain: "Auth", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "That code didn't work. Try again."])
        }
        return Self.map(session.user)
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    func deleteAccount() async throws {
        // The client only holds the ANON key, which (correctly) can't delete an
        // auth.users row. So we call the `delete-account` Edge Function: it runs
        // server-side with the service-role key, removes the user's rows
        // (reactions, check_ins, favourites, profiles) and then the auth user.
        // The current JWT is attached automatically, so the function knows who
        // the caller is — no user id is sent from the client.
        try await client.functions.invoke("delete-account")
        // Clear the now-orphaned local session/keychain so the app returns to
        // the signed-out state. `try?`: the user is already gone server-side.
        try? await client.auth.signOut()
    }

    private func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Translate the SDK's `User` into OUR small AuthSession value. `Self` refers to
    // the type (SupabaseAuthService); `static` because it needs no instance state.
    // Keeping this mapping here means the rest of the app never sees Supabase types.
    private static func map(_ user: User) -> AuthSession {
        AuthSession(
            userID: user.id,
            displayName: user.email,
            isGuest: user.isAnonymous
        )
    }
}
