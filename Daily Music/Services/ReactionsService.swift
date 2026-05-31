//
//  ReactionsService.swift
//  Daily Music
//
//  Lightweight emoji reactions on a day's song — the low-effort end of the
//  shared-ritual lever (react in one tap, see how everyone else felt). One
//  reaction per user per entry. Counts are aggregated across all users.
//

import Foundation

enum Reaction {
    /// The fixed palette of reactions offered on each song.
    static let all = ["🔥", "❤️", "😌", "💫"]
}

protocol ReactionsService {
    /// The current user's reaction to this entry, if any.
    func myReaction(entryID: UUID) async throws -> String?
    /// Set (or clear, when nil) the current user's reaction.
    func setReaction(_ emoji: String?, entryID: UUID) async throws
    /// Aggregate counts per emoji across all users.
    func counts(entryID: UUID) async throws -> [String: Int]
}

actor MockReactionsService: ReactionsService {
    private var mine: [UUID: String] = [:]
    private var tallies: [UUID: [String: Int]] = [:]

    func myReaction(entryID: UUID) async throws -> String? { mine[entryID] }

    func counts(entryID: UUID) async throws -> [String: Int] {
        tallies[entryID] ?? ["🔥": 128, "❤️": 86, "😌": 42, "💫": 19]
    }

    func setReaction(_ emoji: String?, entryID: UUID) async throws {
        var counts = tallies[entryID] ?? ["🔥": 128, "❤️": 86, "😌": 42, "💫": 19]
        if let previous = mine[entryID] { counts[previous, default: 1] -= 1 }
        if let emoji { counts[emoji, default: 0] += 1; mine[entryID] = emoji }
        else { mine[entryID] = nil }
        tallies[entryID] = counts
    }
}
