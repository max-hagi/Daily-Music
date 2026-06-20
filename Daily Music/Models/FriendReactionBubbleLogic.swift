//
//  FriendReactionBubbleLogic.swift
//  Daily Music
//
//  Pure helpers for the Today reaction bubbles: how many to show vs collapse,
//  and whether the bubbles may appear at all. Kept separate from the view so the
//  rules are unit-tested without rendering.
//

import Foundation

enum BubbleLayout {
    /// Cap the visible bubbles; the rest fold into an overflow count.
    static func split(_ reactions: [FriendReaction], maxVisible: Int)
        -> (shown: [FriendReaction], overflow: Int) {
        guard reactions.count > maxVisible else { return (reactions, 0) }
        return (Array(reactions.prefix(maxVisible)), reactions.count - maxVisible)
    }
}

enum FriendBubbleReveal {
    /// Bubbles show only on Today, only after the user engaged (listened or
    /// rated), and only when at least one friend has reacted — so they land as a
    /// payoff and never bias the user's own rating.
    static func shouldShow(isToday: Bool, hasListenedOrRated: Bool, hasReactions: Bool) -> Bool {
        isToday && hasListenedOrRated && hasReactions
    }
}
