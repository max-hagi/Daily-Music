//
//  SessionStore.swift
//  Daily Music
//
//  Owns "who is signed in" for the whole app. RootView watches this to decide
//  between the sign-in screen and the main tabs.
//

import Foundation

@MainActor
@Observable
final class SessionStore {
    private(set) var session: AuthSession?
    private(set) var isWorking = false
    /// Surfaced to the sign-in screen so failures are never silent.
    private(set) var errorMessage: String?

    private let auth: AuthService

    init(auth: AuthService) {
        self.auth = auth
    }

    var isSignedIn: Bool { session != nil }

    /// Called once on launch to pick up an existing session.
    func restore() async {
        session = await auth.restoreSession()
    }

    func signInWithApple() async {
        await attempt { try await self.auth.signInWithApple() }
    }

    func continueAsGuest() async {
        await attempt { try await self.auth.continueAsGuest() }
    }

    private func attempt(_ work: @escaping () async throws -> AuthSession) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            session = try await work()
        } catch {
            errorMessage = Self.describe(error)
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
