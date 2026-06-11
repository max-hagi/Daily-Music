//
//  AppleMusicSession.swift
//  Daily Music
//
//  Connection state machine for Apple Music. MusicKit's static APIs are
//  wrapped behind AppleMusicAuthorizing so the machine is unit-testable and
//  the simulator/mock environment can fake any state without the entitlement.
//
//  The persisted "user connected" flag means: the user explicitly tapped
//  Connect at some point. On launch, restore() silently re-derives status —
//  it never triggers the system permission prompt.
//

import Foundation
import MusicKit

enum AppleMusicAuthStatus {
    case notDetermined
    case authorized
    case denied
}

/// Seam over MusicKit's statics (MusicAuthorization / MusicSubscription).
protocol AppleMusicAuthorizing: Sendable {
    func currentStatus() -> AppleMusicAuthStatus
    func requestAuthorization() async -> AppleMusicAuthStatus
    func hasActiveSubscription() async -> Bool
    /// Emits whenever subscription state may have changed
    /// (true = can play full catalog tracks).
    func subscriptionUpdates() -> AsyncStream<Bool>
}

/// Live MusicKit-backed implementation. Compiles without the entitlement;
/// at runtime, authorization simply fails until the paid account enables it.
struct MusicKitAuthorizer: AppleMusicAuthorizing {
    func currentStatus() -> AppleMusicAuthStatus {
        map(MusicAuthorization.currentStatus)
    }

    func requestAuthorization() async -> AppleMusicAuthStatus {
        map(await MusicAuthorization.request())
    }

    func hasActiveSubscription() async -> Bool {
        (try? await MusicSubscription.current)?.canPlayCatalogContent ?? false
    }

    func subscriptionUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task {
                for await subscription in MusicSubscription.subscriptionUpdates {
                    continuation.yield(subscription.canPlayCatalogContent)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func map(_ status: MusicAuthorization.Status) -> AppleMusicAuthStatus {
        switch status {
        case .authorized:    .authorized
        case .notDetermined: .notDetermined
        default:             .denied
        }
    }
}

@MainActor
@Observable
final class AppleMusicSession: MusicServiceConnection {
    let service: StreamingService = .appleMusic
    private(set) var status: MusicConnectionStatus = .notConnected
    private(set) var isConnecting = false

    private let authorizer: AppleMusicAuthorizing
    private let defaults: UserDefaults
    private static let connectedKey = "appleMusic.userConnected"
    private var updatesTask: Task<Void, Never>?

    init(authorizer: AppleMusicAuthorizing, defaults: UserDefaults = .standard) {
        self.authorizer = authorizer
        self.defaults = defaults
    }

    /// Launch path: re-derive status ONLY if the user connected before and iOS
    /// still reports us authorized. Never prompts.
    func restore() async {
        guard defaults.bool(forKey: Self.connectedKey),
              authorizer.currentStatus() == .authorized else { return }
        await refreshCapabilities()
        watchSubscription()
    }

    func connect() async {
        isConnecting = true
        defer { isConnecting = false }
        guard await authorizer.requestAuthorization() == .authorized else {
            status = .notConnected
            defaults.set(false, forKey: Self.connectedKey)
            return
        }
        defaults.set(true, forKey: Self.connectedKey)
        await refreshCapabilities()
        watchSubscription()
    }

    /// Stops the app using Apple Music. (It can't revoke the iOS permission —
    /// only Settings can — it just clears our flag and state.)
    func disconnect() {
        defaults.set(false, forKey: Self.connectedKey)
        status = .notConnected
        updatesTask?.cancel()
        updatesTask = nil
    }

    private func refreshCapabilities() async {
        apply(subscribed: await authorizer.hasActiveSubscription())
    }

    private func apply(subscribed: Bool) {
        // Library writes, like full playback, need an active subscription.
        status = .connected(subscribed
            ? [.fullPlayback, .librarySave, .richMetadata]
            : [.richMetadata])
    }

    /// A lapsed/renewed subscription downgrades/upgrades capabilities live.
    /// The stream is created synchronously so no update emitted right after
    /// connect()/restore() returns can slip past the watcher.
    private func watchSubscription() {
        updatesTask?.cancel()
        let updates = authorizer.subscriptionUpdates()
        updatesTask = Task { [weak self] in
            for await canPlay in updates {
                guard let self, !Task.isCancelled else { return }
                self.apply(subscribed: canPlay)
            }
        }
    }
}

/// Dev/sim/test stand-in: configurable auth + subscription, drivable
/// subscription updates, and a prompt counter for the no-silent-prompt tests.
final class MockAppleMusicAuthorizer: AppleMusicAuthorizing, @unchecked Sendable {
    var status: AppleMusicAuthStatus
    var subscribed: Bool
    private(set) var requestCount = 0
    private var subscriptionContinuation: AsyncStream<Bool>.Continuation?

    init(status: AppleMusicAuthStatus = .notDetermined, subscribed: Bool = true) {
        self.status = status
        self.subscribed = subscribed
    }

    func currentStatus() -> AppleMusicAuthStatus { status }

    func requestAuthorization() async -> AppleMusicAuthStatus {
        requestCount += 1
        if status == .notDetermined { status = .authorized }
        return status
    }

    func hasActiveSubscription() async -> Bool { subscribed }

    func subscriptionUpdates() -> AsyncStream<Bool> {
        AsyncStream { self.subscriptionContinuation = $0 }
    }

    /// Test hook: simulate a subscription change notification.
    func sendSubscriptionUpdate(_ canPlay: Bool) {
        subscriptionContinuation?.yield(canPlay)
    }
}
