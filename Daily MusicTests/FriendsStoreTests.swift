import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct FriendsStoreTests {
    @Test func loadPopulatesAndBadgeCounts() async {
        let store = FriendsStore(service: MockFriendService())
        await store.load()
        #expect(store.friends.count == 1)
        #expect(store.requestCount == 1)
        #expect(store.myCode.count == 6)
    }
    @Test func approveMovesRequestToFriends() async {
        let store = FriendsStore(service: MockFriendService())
        await store.load()
        let req = store.requests[0]
        await store.respond(req, accept: true)
        #expect(store.requestCount == 0)
        #expect(store.friends.count == 2)
    }
}
