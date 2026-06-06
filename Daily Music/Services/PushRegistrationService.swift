//
//  PushRegistrationService.swift
//  Daily Music
//
//  Registers APNs device tokens with Supabase. This is separate from
//  NotificationService, which only owns local daily reminders.
//

import Foundation
import Supabase

protocol PushRegistrationService: Sendable {
    func registerDeviceToken(_ token: Data) async throws
    func unregisterCurrentDevice() async throws
}

extension Data {
    nonisolated var apnsHexString: String {
        map { String(format: "%02.2hhx", $0) }.joined()
    }
}

actor MockPushRegistrationService: PushRegistrationService {
    private(set) var registeredToken: String?

    func registerDeviceToken(_ token: Data) async throws {
        registeredToken = token.apnsHexString
    }

    func unregisterCurrentDevice() async throws {
        registeredToken = nil
    }
}

actor SupabasePushRegistrationService: PushRegistrationService {
    private var currentToken: String?

    func registerDeviceToken(_ token: Data) async throws {
        let value = token.apnsHexString
        currentToken = value
        let client = await MainActor.run { Supa.client }
        try await client.rpc(
            "register_push_token",
            params: [
                "p_token": value,
                "p_platform": "ios",
                "p_environment": Self.apnsEnvironment
            ]
        )
        .execute()
    }

    func unregisterCurrentDevice() async throws {
        guard let currentToken else { return }
        let client = await MainActor.run { Supa.client }
        try await client.rpc("unregister_push_token", params: ["p_token": currentToken]).execute()
        self.currentToken = nil
    }

    private static var apnsEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}
