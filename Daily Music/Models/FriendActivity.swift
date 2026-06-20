//
//  FriendActivity.swift
//  Daily Music
//
//  Pure engine + value types for the Friends activity feed and the Today
//  reaction bubbles. Turns per-friend rating maps (from friend_ratings) into
//  loved/passed items, today's reactions, and taste-match percents. No I/O —
//  the FriendsActivityStore feeds it live data; tests feed it fixtures.
//

import Foundation

/// A friend's verdict on a song, derived from their +1 / -1 rating.
enum Verdict: Equatable {
    case loved   // rating > 0
    case passed  // rating < 0

    /// Build from a raw rating value; nil for 0 / missing.
    init?(rating: Int) {
        if rating > 0 { self = .loved }
        else if rating < 0 { self = .passed }
        else { return nil }
    }

    var emoji: String { self == .loved ? "❤️" : "👎" }

    /// Verb used in feed copy: "loved today's drop" / "passed on today's drop".
    var feedVerb: String { self == .loved ? "loved" : "passed on" }
}

/// A friend's reaction to a single song — used by the Today bubbles.
struct FriendReaction: Identifiable, Equatable {
    let friend: UserProfile
    let verdict: Verdict
    var id: UUID { friend.id }
}

/// One row in the activity feed: a friend loved/passed a specific drop.
struct FriendActivityItem: Identifiable, Equatable {
    let id: String
    let friend: UserProfile
    let verdict: Verdict
    let entry: DailyEntry
}

/// Pure builders. All inputs are plain values so every output is unit-testable.
enum FriendActivityFeed {

    /// Loved/passed items across the most recent `window` drops, newest entry
    /// first. Friends with no (or a 0) rating on an entry contribute nothing.
    static func recentDropItems(
        friends: [Friend],
        ratingsByFriend: [UUID: [UUID: Int]],
        history: [DailyEntry],
        window: Int
    ) -> [FriendActivityItem] {
        let recent = Array(history.prefix(max(0, window)))
        var items: [FriendActivityItem] = []
        for entry in recent {
            for friend in friends {
                guard let raw = ratingsByFriend[friend.profile.id]?[entry.id],
                      let verdict = Verdict(rating: raw) else { continue }
                items.append(FriendActivityItem(
                    id: "\(friend.profile.id.uuidString)-\(entry.id.uuidString)",
                    friend: friend.profile,
                    verdict: verdict,
                    entry: entry))
            }
        }
        return items.sorted { $0.entry.date > $1.entry.date }
    }

    /// Friends' verdicts on a single entry (today's drop). Empty when the id is nil.
    static func todayReactions(
        friends: [Friend],
        ratingsByFriend: [UUID: [UUID: Int]],
        todayEntryID: UUID?
    ) -> [FriendReaction] {
        guard let todayEntryID else { return [] }
        return friends.compactMap { friend in
            guard let raw = ratingsByFriend[friend.profile.id]?[todayEntryID],
                  let verdict = Verdict(rating: raw) else { return nil }
            return FriendReaction(friend: friend.profile, verdict: verdict)
        }
    }

    /// Taste-match percent per friend, reusing TasteComparison. Friends below the
    /// minimum shared-ratings threshold are omitted (no meaningful %).
    static func matchPercents(
        friends: [Friend],
        ratingsByFriend: [UUID: [UUID: Int]],
        mine: [UUID: Int],
        history: [DailyEntry]
    ) -> [UUID: Int] {
        var out: [UUID: Int] = [:]
        for friend in friends {
            let theirs = ratingsByFriend[friend.profile.id] ?? [:]
            if let pct = TasteComparison.build(mine: mine, theirs: theirs, history: history).matchPercent {
                out[friend.profile.id] = pct
            }
        }
        return out
    }
}
