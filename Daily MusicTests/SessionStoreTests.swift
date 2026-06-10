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

    // MARK: SignInArtCache

    @Test func signInArtCacheRoundTrips() {
        let defaults = UserDefaults(suiteName: "SignInArtCacheTests")!
        defaults.removePersistentDomain(forName: "SignInArtCacheTests")

        #expect(SignInArtCache.load(defaults: defaults).isEmpty)

        let urls = [URL(string: "https://example.com/a.jpg")!,
                    URL(string: "https://example.com/b.jpg")!]
        SignInArtCache.save(urls, defaults: defaults)
        #expect(SignInArtCache.load(defaults: defaults) == urls)

        // Saving a fresh set replaces, not appends.
        let fresh = [URL(string: "https://example.com/c.jpg")!]
        SignInArtCache.save(fresh, defaults: defaults)
        #expect(SignInArtCache.load(defaults: defaults) == fresh)

        defaults.removePersistentDomain(forName: "SignInArtCacheTests")
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
