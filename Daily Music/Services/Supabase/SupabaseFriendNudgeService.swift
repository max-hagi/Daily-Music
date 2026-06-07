//
//  SupabaseFriendNudgeService.swift
//  Daily Music
//
//  Live friend nudges via the send-friend-nudge Edge Function. The function is
//  the source of truth for friendship verification and the 24h cooldown; this
//  client only maps its JSON response onto FriendNudgeResult.
//

import Foundation
import Supabase

actor SupabaseFriendNudgeService: FriendNudgeService {
    func sendNudge(to friendID: UUID) async throws -> FriendNudgeResult {
        let client = await MainActor.run { Supa.client }
        let response: FriendNudgeResponse
        do {
            response = try await client.functions.invoke(
                "send-friend-nudge",
                options: FunctionInvokeOptions(body: FriendNudgeRequest(recipient_id: friendID))
            )
        } catch let error as FunctionsError {
            throw Self.nudgeError(from: error)
        }

        guard let status = response.status else {
            throw FriendNudgeError.message(response.error ?? "The nudge response was not recognized.")
        }

        switch status {
        case "sent":
            return .sent
        case "no_tokens":
            return .noRecipientToken
        case "rate_limited":
            return .rateLimited(nextAllowedAt: Self.parseTimestamp(response.next_allowed_at))
        case "failed":
            throw FriendNudgeError.message(response.error ?? "The nudge could not be sent.")
        default:
            throw FriendNudgeError.message("The nudge response was not recognized.")
        }
    }

    nonisolated private static func nudgeError(from error: FunctionsError) -> FriendNudgeError {
        switch error {
        case .httpError(_, let data):
            if let response = try? JSONDecoder().decode(FriendNudgeResponse.self, from: data),
               let message = response.error {
                return .message(message)
            }
            return .message(error.localizedDescription)
        case .relayError:
            return .message(error.localizedDescription)
        }
    }

    // The Edge Function returns next_allowed_at as an ISO8601 string with
    // fractional seconds (JS toISOString()). We decode it as a String and parse
    // it here so we never depend on the Functions client's JSON date strategy.
    nonisolated private static func parseTimestamp(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

nonisolated private struct FriendNudgeRequest: Encodable {
    let recipient_id: UUID
}

nonisolated private struct FriendNudgeResponse: Decodable {
    let status: String?
    let next_allowed_at: String?
    let error: String?
}
