//
//  ReactionsService.swift
//  Daily Music
//
//  Lightweight emoji reactions on a day's song — the low-effort end of the
//  shared-ritual lever (react in one tap, see how everyone else felt). One
//  reaction per user per entry. Counts are aggregated across all users.
//

import Foundation

// Caseless enum used as a namespace for the fixed reaction palette (same trick
// as Theme). Keeps the emoji list in one place.
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
    // `mine`: which emoji THIS user picked, keyed by entry. `tallies`: the global
    // per-emoji counts, keyed by entry. Both are dictionaries ([Key: Value]).
    private var mine: [UUID: String] = [:]
    private var tallies: [UUID: [String: Int]] = [:]

    // Subscripting a dictionary returns an Optional (nil if the key is absent),
    // which is exactly the "my reaction, if any" semantics we want.
    func myReaction(entryID: UUID) async throws -> String? { mine[entryID] }

    func counts(entryID: UUID) async throws -> [String: Int] {
        // `?? [...]` supplies seed counts the first time an entry is reacted to.
        tallies[entryID] ?? ["🔥": 128, "❤️": 86, "😌": 42, "💫": 19]
    }

    func setReaction(_ emoji: String?, entryID: UUID) async throws {
        var counts = tallies[entryID] ?? ["🔥": 128, "❤️": 86, "😌": 42, "💫": 19]
        // If the user had a previous reaction, decrement it first (one vote each).
        // `counts[previous, default: 1]` reads the current count (or 1 if missing)
        // so the `-= 1` is always well-defined.
        if let previous = mine[entryID] { counts[previous, default: 1] -= 1 }
        // `if let emoji { … } else { … }` — passing a non-nil emoji sets/switches
        // the reaction; passing nil clears it (toggling off).
        if let emoji { counts[emoji, default: 0] += 1; mine[entryID] = emoji }
        else { mine[entryID] = nil }
        tallies[entryID] = counts   // write the updated tally back
    }
}
