//  FriendsStore.swift — owns the friends list + incoming requests for the app.
import Foundation

@MainActor
@Observable
final class FriendsStore {
    private(set) var friends: [Friend] = []
    private(set) var requests: [FriendRequest] = []
    private(set) var myCode: String = ""
    private(set) var errorMessage: String?

    private let service: FriendService
    init(service: FriendService) { self.service = service }

    var requestCount: Int { requests.count }

    func load() async {
        myCode = (try? await service.myCode()) ?? myCode
        friends = (try? await service.friends()) ?? friends
        requests = (try? await service.incomingRequests()) ?? requests
    }

    /// Returns true on success; sets errorMessage on failure.
    func send(code: String) async -> Bool {
        errorMessage = nil
        do { try await service.sendRequest(code: code); await load(); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }

    func respond(_ request: FriendRequest, accept: Bool) async {
        try? await service.respond(requestID: request.id, accept: accept)
        await load()
    }

    func remove(_ friend: Friend) async {
        try? await service.remove(friendshipID: friend.friendshipID)
        await load()
    }
}
