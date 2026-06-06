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
    private let client = Supa.client
    private var currentToken: String?

    func registerDeviceToken(_ token: Data) async throws {
        let value = token.apnsHexString
        currentToken = value
        try await client.rpc(
            "register_push_token",
            params: RegisterPushTokenParams(
                p_token: value,
                p_platform: "ios",
                p_environment: Self.apnsEnvironment
            )
        )
        .execute()
    }

    func unregisterCurrentDevice() async throws {
        guard let currentToken else { return }
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

private struct RegisterPushTokenParams: Encodable, Sendable {
    let p_token: String
    let p_platform: String
    let p_environment: String
}
