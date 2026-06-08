//
//  RatingsStore.swift
//  Daily Music
//
//  One reactive source of truth for 👍/👎 ratings so every RatingBar across the
//  app updates together — identical pattern to FavoritesStore. Wraps RatingService
//  (which does the actual storage) and keeps an in-memory [UUID: Int] the SwiftUI
//  views observe. Writes are optimistic: the UI flips immediately and rolls back
//  if the write fails.
//

import Foundation

@MainActor
@Observable
final class RatingsStore {
    /// All of the current user's ratings. +1 = like, -1 = dislike; absent = not rated.
    private(set) var ratings: [UUID: Int] = [:]

    private let service: RatingService

    init(service: RatingService) {
        self.service = service
    }

    // MARK: read

    func load() async {
        ratings = (try? await service.myRatings()) ?? [:]
    }

    func rating(for entryID: UUID) -> Int? {
        ratings[entryID]
    }

    // MARK: write

    /// Set (+1/-1) or clear (nil). Optimistic: UI updates first, rolls back on failure.
    func setRating(_ value: Int?, entryID: UUID) async {
        let previous = ratings[entryID]
        // Optimistic update — all observers re-render immediately.
        if let value { ratings[entryID] = value } else { ratings.removeValue(forKey: entryID) }
        do {
            try await service.setRating(value, entryID: entryID)
        } catch {
            // Roll back on failure so the UI doesn't lie.
            if let previous { ratings[entryID] = previous } else { ratings.removeValue(forKey: entryID) }
        }
    }
}
