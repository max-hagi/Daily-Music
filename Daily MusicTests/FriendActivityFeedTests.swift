import Testing
import Foundation
@testable import Daily_Music

struct FriendActivityFeedTests {
    // Two friends, three entries (e0 newest … e2 oldest).
    private func fixture() -> (friends: [Friend], history: [DailyEntry], byFriend: [UUID: [UUID: Int]]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func entry(_ i: Int) -> DailyEntry {
            DailyEntry(
                id: MockEntryService.mockEntryID(i),
                date: cal.date(byAdding: .day, value: -i, to: today)!,
                title: "Song \(i)", artist: "Artist \(i)",
                albumArtURL: nil, journalMarkdown: "", appleMusicID: "", spotifyURI: ""
                // genre…language default to nil
            )
        }
        let alex = Friend(friendshipID: UUID(), profile: UserProfile(id: UUID(), displayName: "Alex", avatarURL: nil))
        let sam  = Friend(friendshipID: UUID(), profile: UserProfile(id: UUID(), displayName: "Sam", avatarURL: nil))
        let history = [entry(0), entry(1), entry(2)]
        let byFriend: [UUID: [UUID: Int]] = [
            alex.profile.id: [MockEntryService.mockEntryID(0): 1,  MockEntryService.mockEntryID(2): -1],
            sam.profile.id:  [MockEntryService.mockEntryID(0): -1]
        ]
        return ([alex, sam], history, byFriend)
    }

    @Test func recentDropItemsBuildsLovedAndPassed() {
        let f = fixture()
        let items = FriendActivityFeed.recentDropItems(
            friends: f.friends, ratingsByFriend: f.byFriend, history: f.history, window: 5)
        // Alex: loved e0, passed e2. Sam: passed e0. → 3 items, newest entry first.
        #expect(items.count == 3)
        #expect(items.first?.entry.id == MockEntryService.mockEntryID(0))
        #expect(items.allSatisfy { $0.entry.date >= items.last!.entry.date })
        let alexLoved = items.first { $0.friend.displayName == "Alex" && $0.entry.id == MockEntryService.mockEntryID(0) }
        #expect(alexLoved?.verdict == .loved)
    }

    @Test func windowLimitsHowFarBack() {
        let f = fixture()
        let items = FriendActivityFeed.recentDropItems(
            friends: f.friends, ratingsByFriend: f.byFriend, history: f.history, window: 1)
        // Only e0 is in-window → Alex loved + Sam passed = 2 items.
        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.entry.id == MockEntryService.mockEntryID(0) })
    }

    @Test func todayReactionsFilterToTheGivenEntry() {
        let f = fixture()
        let reactions = FriendActivityFeed.todayReactions(
            friends: f.friends, ratingsByFriend: f.byFriend, todayEntryID: MockEntryService.mockEntryID(0))
        #expect(reactions.count == 2)
        #expect(reactions.first { $0.friend.displayName == "Alex" }?.verdict == .loved)
        #expect(reactions.first { $0.friend.displayName == "Sam" }?.verdict == .passed)
    }

    @Test func todayReactionsEmptyWhenNoTodayEntry() {
        let f = fixture()
        #expect(FriendActivityFeed.todayReactions(
            friends: f.friends, ratingsByFriend: f.byFriend, todayEntryID: nil).isEmpty)
    }

    @Test func matchPercentsOmitFriendsBelowThreshold() {
        let f = fixture()
        // mine agrees with Alex on e0 (both like) but only 2 co-rated < minShared(3) → nil/omitted.
        let mine: [UUID: Int] = [MockEntryService.mockEntryID(0): 1, MockEntryService.mockEntryID(2): 1]
        let pcts = FriendActivityFeed.matchPercents(
            friends: f.friends, ratingsByFriend: f.byFriend, mine: mine, history: f.history)
        // Alex co-rated 2 (e0,e2) < 3 → omitted; Sam co-rated 1 → omitted.
        #expect(pcts.isEmpty)
    }
}
