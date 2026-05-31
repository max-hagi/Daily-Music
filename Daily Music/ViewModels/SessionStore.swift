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
        isWorking = true
        defer { isWorking = false }
        session = try? await auth.signInWithApple()
    }

    func continueAsGuest() async {
        isWorking = true
        defer { isWorking = false }
        session = try? await auth.continueAsGuest()
    }

    func signOut() async {
        await auth.signOut()
        session = nil
    }
}
