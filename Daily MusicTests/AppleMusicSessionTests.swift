import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct AppleMusicSessionTests {
    /// Isolated defaults per test so persistence can't leak between tests.
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AppleMusicSessionTests-\(UUID().uuidString)")!
    }

    @Test func startsNotConnected() {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(), defaults: freshDefaults()
        )
        #expect(session.status == .notConnected)
    }

    @Test func connectWithSubscriptionGrantsAllCapabilities() async {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(subscribed: true), defaults: freshDefaults()
        )
        await session.connect()
        #expect(session.status == .connected([.fullPlayback, .librarySave, .richMetadata]))
    }

    // Library writes, like full playback, require an active subscription —
    // authorized-but-unsubscribed users only get richer metadata.
    @Test func connectWithoutSubscriptionGrantsMetadataOnly() async {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(subscribed: false), defaults: freshDefaults()
        )
        await session.connect()
        #expect(session.status == .connected([.richMetadata]))
    }

    @Test func deniedAuthorizationLeavesNotConnected() async {
        let session = AppleMusicSession(
            authorizer: MockAppleMusicAuthorizer(status: .denied), defaults: freshDefaults()
        )
        await session.connect()
        #expect(session.status == .notConnected)
    }

    // The launch path must never show a permission prompt.
    @Test func restoreNeverPromptsWhenUserNeverConnected() async {
        let authorizer = MockAppleMusicAuthorizer()
        let session = AppleMusicSession(authorizer: authorizer, defaults: freshDefaults())
        await session.restore()
        #expect(authorizer.requestCount == 0)
        #expect(session.status == .notConnected)
    }

    @Test func restoreRederivesStatusAfterPriorConnect() async {
        let defaults = freshDefaults()
        let authorizer = MockAppleMusicAuthorizer(subscribed: true)
        let first = AppleMusicSession(authorizer: authorizer, defaults: defaults)
        await first.connect()

        // "Next launch": new session, same defaults, already-authorized system state.
        let second = AppleMusicSession(authorizer: authorizer, defaults: defaults)
        await second.restore()
        #expect(authorizer.requestCount == 1)   // only the original connect prompted
        #expect(second.status == .connected([.fullPlayback, .librarySave, .richMetadata]))
    }

    @Test func disconnectClearsStatusAndPersistedFlag() async {
        let defaults = freshDefaults()
        let authorizer = MockAppleMusicAuthorizer(subscribed: true)
        let session = AppleMusicSession(authorizer: authorizer, defaults: defaults)
        await session.connect()
        session.disconnect()
        #expect(session.status == .notConnected)

        let next = AppleMusicSession(authorizer: authorizer, defaults: defaults)
        await next.restore()
        #expect(next.status == .notConnected)
    }

    @Test func subscriptionLapseDowngradesCapabilitiesLive() async {
        let authorizer = MockAppleMusicAuthorizer(subscribed: true)
        let session = AppleMusicSession(authorizer: authorizer, defaults: freshDefaults())
        await session.connect()
        #expect(session.status.capabilities.contains(.fullPlayback))

        authorizer.sendSubscriptionUpdate(false)
        try? await Task.sleep(for: .milliseconds(100))   // let the watcher task run
        #expect(session.status == .connected([.richMetadata]))
    }
}
