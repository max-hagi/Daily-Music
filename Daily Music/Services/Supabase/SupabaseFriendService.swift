//  SupabaseFriendService.swift — live friending via SECURITY DEFINER RPCs.
import Foundation
import Supabase

final class SupabaseFriendService: FriendService {
    private let client = Supa.client

    func myCode() async throws -> String {
        try await client.rpc("claim_friend_code").execute().value
    }

    func friends() async throws -> [Friend] {
        let rows: [FriendRow] = try await client.rpc("my_friends").execute().value
        return rows.map {
            Friend(friendshipID: $0.friendship_id,
                   profile: UserProfile(id: $0.user_id, displayName: $0.display_name, avatarURL: $0.avatar_url))
        }
    }

    func incomingRequests() async throws -> [FriendRequest] {
        let rows: [RequestRow] = try await client.rpc("incoming_requests").execute().value
        return rows.map {
            FriendRequest(id: $0.request_id,
                          profile: UserProfile(id: $0.user_id, displayName: $0.display_name, avatarURL: $0.avatar_url),
                          createdAt: $0.created_at)
        }
    }

    func sendRequest(code: String) async throws {
        // The RPC raises a friendly Postgres error on bad code / dupes; surface it.
        _ = try await client.rpc("send_friend_request", params: ["p_code": FriendCode.normalize(code)]).execute()
    }

    func respond(requestID: UUID, accept: Bool) async throws {
        try await client.rpc("respond_to_request",
                             params: RespondParams(p_id: requestID, p_accept: accept)).execute()
    }

    func remove(friendshipID: UUID) async throws {
        try await client.rpc("remove_friend", params: ["p_id": friendshipID]).execute()
    }

    func friendRatings(friendID: UUID) async throws -> [UUID: Int] {
        let rows: [FriendRatingRow] = try await client
            .rpc("friend_ratings", params: ["p_friend_id": friendID]).execute().value
        return Dictionary(rows.map { ($0.entry_id, Int($0.value)) }, uniquingKeysWith: { a, _ in a })
    }
}

private struct FriendRow: Decodable {
    let friendship_id: UUID; let user_id: UUID; let display_name: String?; let avatar_url: String?
}
private struct RequestRow: Decodable {
    let request_id: UUID; let user_id: UUID; let display_name: String?; let avatar_url: String?; let created_at: Date
}
private struct RespondParams: Encodable { let p_id: UUID; let p_accept: Bool }
private struct FriendRatingRow: Decodable { let entry_id: UUID; let value: Int16 }
