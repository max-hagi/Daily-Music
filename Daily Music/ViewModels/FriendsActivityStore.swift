//
//  FriendsActivityStore.swift
//  Daily Music
//
//  Assembles the Friends activity feed and the Today reaction bubbles from live
//  data: each friend's ratings (friend_ratings RPC), the published entry
//  history, and the user's own ratings. Pure assembly lives in
//  FriendActivityFeed; this store just fetches and caches the derived outputs so
//  the Friends tab and Today both read one consistent source. Best-effort: any
//  failed fetch degrades to empty rather than erroring.
//

import Foundation

@MainActor
@Observable
final class FriendsActivityStore {
    /// Loved/passed on recent drops, newest first — drives the activity feed.
    private(set) var items: [FriendActivityItem] = []
    /// Friends' verdicts on today's drop — drives the Today bubbles.
    private(set) var todayReactions: [FriendReaction] = []
    /// Taste-match percent per friend id — drives the friends-list bars.
    private(set) var matchByFriend: [UUID: Int] = [:]

    /// How many recent drops the feed looks back over.
    private let window = 5

    private let friends: FriendService
    private let entries: EntryService
    private let ratings: RatingService

    init(friends: FriendService, entries: EntryService, ratings: RatingService) {
        self.friends = friends
        self.entries = entries
        self.ratings = ratings
    }

    func load() async {
        let roster = (try? await friends.friends()) ?? []
        let history = (try? await entries.publishedHistory()) ?? []
        let mine = (try? await ratings.myRatings()) ?? [:]

        var byFriend: [UUID: [UUID: Int]] = [:]
        for friend in roster {
            byFriend[friend.profile.id] = (try? await friends.friendRatings(friendID: friend.profile.id)) ?? [:]
        }

        let todayEntryID = history.first { Calendar.current.isDateInToday($0.date) }?.id

        items = FriendActivityFeed.recentDropItems(
            friends: roster, ratingsByFriend: byFriend, history: history, window: window)
        todayReactions = FriendActivityFeed.todayReactions(
            friends: roster, ratingsByFriend: byFriend, todayEntryID: todayEntryID)
        matchByFriend = FriendActivityFeed.matchPercents(
            friends: roster, ratingsByFriend: byFriend, mine: mine, history: history)
    }
}
