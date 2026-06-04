//  FriendService.swift — the friending seam. All cross-user access is via RPCs
//  live; the mock keeps an in-memory graph so the UI is explorable offline.
import Foundation

protocol FriendService: Sendable {
    func myCode() async throws -> String
    func friends() async throws -> [Friend]
    func incomingRequests() async throws -> [FriendRequest]
    func sendRequest(code: String) async throws
    func respond(requestID: UUID, accept: Bool) async throws
    func remove(friendshipID: UUID) async throws
    func friendRatings(friendID: UUID) async throws -> [UUID: Int]   // Phase C
}

enum FriendError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let m) = self { return m } else { return nil } }
}

actor MockFriendService: FriendService {
    private var code = FriendCode.generate()
    private var friendList: [Friend]
    private var requests: [FriendRequest]
    private var ratingsByFriend: [UUID: [UUID: Int]] = [:]

    init() {
        let alex = UserProfile(id: UUID(), displayName: "Alex Rivera", avatarURL: nil)
        let sam  = UserProfile(id: UUID(), displayName: "Sam", avatarURL: nil)
        friendList = [Friend(friendshipID: UUID(), profile: alex)]
        requests = [FriendRequest(id: UUID(), profile: sam, createdAt: Date())]
    }

    func myCode() async throws -> String { code }
    func friends() async throws -> [Friend] { friendList }
    func incomingRequests() async throws -> [FriendRequest] { requests }

    func sendRequest(code raw: String) async throws {
        let c = FriendCode.normalize(raw)
        guard c.count == 6 else { throw FriendError.message("That code looks too short.") }
        guard c != code else { throw FriendError.message("That is your own code.") }
        // Mock: just acknowledge — no real recipient.
    }

    func respond(requestID: UUID, accept: Bool) async throws {
        guard let idx = requests.firstIndex(where: { $0.id == requestID }) else { return }
        let req = requests.remove(at: idx)
        if accept { friendList.append(Friend(friendshipID: req.id, profile: req.profile)) }
    }

    func remove(friendshipID: UUID) async throws {
        friendList.removeAll { $0.friendshipID == friendshipID }
    }

    func friendRatings(friendID: UUID) async throws -> [UUID: Int] {
        ratingsByFriend[friendID] ?? [:]
    }
}
