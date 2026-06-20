import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct FriendsActivityStoreTests {
    @Test func loadAssemblesReactionsItemsAndMatch() async throws {
        // Use one shared MockFriendService so the store sees the same Alex id
        // (and seeded ratings) the test inspects.
        let friendSvc = MockFriendService()
        let alex = try await friendSvc.friends()[0].profile

        let store = FriendsActivityStore(
            friends: friendSvc,
            entries: MockEntryService(),
            ratings: MockRatingService())

        await store.load()

        // MockEntryService entry 0 is today; MockFriendService seeds Alex's
        // rating on entry 0 as +1 → a "loved" reaction on today's drop.
        #expect(store.todayReactions.contains { $0.friend.id == alex.id && $0.verdict == .loved })
        // Recent window covers today + prior drops Alex has rated → non-empty feed.
        #expect(!store.items.isEmpty)
        // Alex and the seeded "me" share well over minShared ratings → a % exists.
        #expect(store.matchByFriend[alex.id] != nil)
    }

    @Test func loadIsResilientToEmptyFriends() async {
        // A friend service with no friends/ratings yields empty, not a crash.
        let store = FriendsActivityStore(
            friends: EmptyFriendService(),
            entries: MockEntryService(),
            ratings: MockRatingService())
        await store.load()
        #expect(store.items.isEmpty)
        #expect(store.todayReactions.isEmpty)
        #expect(store.matchByFriend.isEmpty)
    }
}

/// A FriendService with no social graph, for the empty-state path.
private actor EmptyFriendService: FriendService {
    func myCode() async throws -> String { "ABCDEF" }
    func friends() async throws -> [Friend] { [] }
    func incomingRequests() async throws -> [FriendRequest] { [] }
    func sendRequest(code: String) async throws {}
    func respond(requestID: UUID, accept: Bool) async throws {}
    func remove(friendshipID: UUID) async throws {}
    func friendRatings(friendID: UUID) async throws -> [UUID: Int] { [:] }
}
