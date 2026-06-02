//
//  RatingService.swift
//  Daily Music
//
//  The 👍/👎 taste-judgment seam — the primary signal behind Insights. Three
//  states: like (+1), dislike (-1), none (no row). Mirrors ReactionsService. The
//  mock seeds ratings (aligned to MockEntryService) so Insights is explorable
//  without a backend.
//

import Foundation

protocol RatingService {
    /// The current user's rating for this entry: +1, -1, or nil (none).
    func myRating(entryID: UUID) async throws -> Int?
    /// Set (+1/-1) or clear (nil) the current user's rating.
    func setRating(_ value: Int?, entryID: UUID) async throws
    /// All of the current user's ratings, keyed by entry id.
    func myRatings() async throws -> [UUID: Int]
}

actor MockRatingService: RatingService {
    private var mine: [UUID: Int]

    init() {
        var seed: [UUID: Int] = [:]
        for (index, value) in MockEntryService.seedRatingValues.enumerated() {
            seed[MockEntryService.mockEntryID(index)] = value
        }
        mine = seed
    }

    func myRating(entryID: UUID) async throws -> Int? { mine[entryID] }
    func setRating(_ value: Int?, entryID: UUID) async throws { mine[entryID] = value }
    func myRatings() async throws -> [UUID: Int] { mine }
}
