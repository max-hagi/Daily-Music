//
//  FriendNudgeService.swift
//  Daily Music
//
//  Sends small, fixed friend-to-friend nudges. The mock is fully deterministic
//  for tests; the live implementation invokes a Supabase Edge Function.
//

import Foundation

enum FriendNudgeResult: Equatable, Sendable {
    case sent
    case noRecipientToken
    case rateLimited(nextAllowedAt: Date?)
}

enum FriendNudgeError: LocalizedError, Sendable {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}

protocol FriendNudgeService: Sendable {
    func sendNudge(to friendID: UUID) async throws -> FriendNudgeResult
}

actor MockFriendNudgeService: FriendNudgeService {
    static let cooldown: TimeInterval = 86_400

    private var now: Date
    private var sentAt: [UUID: Date] = [:]
    private var recipientsWithoutTokens: Set<UUID>

    init(
        now: Date = Date(),
        recipientsWithoutTokens: Set<UUID> = []
    ) {
        self.now = now
        self.recipientsWithoutTokens = recipientsWithoutTokens
    }

    func setNow(_ date: Date) {
        now = date
    }

    func setRecipientWithoutToken(_ friendID: UUID, enabled: Bool) {
        if enabled {
            recipientsWithoutTokens.insert(friendID)
        } else {
            recipientsWithoutTokens.remove(friendID)
        }
    }

    func sendNudge(to friendID: UUID) async throws -> FriendNudgeResult {
        if let lastSent = sentAt[friendID],
           now.timeIntervalSince(lastSent) < Self.cooldown {
            return .rateLimited(nextAllowedAt: lastSent.addingTimeInterval(Self.cooldown))
        }

        if recipientsWithoutTokens.contains(friendID) {
            return .noRecipientToken
        }

        sentAt[friendID] = now
        return .sent
    }
}
