//
//  SharedStatsService.swift
//  Daily Music
//
//  Cross-user stats that power the "shared daily ritual" — e.g. how many people
//  opened today's song. This is the social-proof / belonging lever (everyone
//  hears the same song), so it reads across ALL users, which RLS would normally
//  block — the live version calls a SECURITY DEFINER Postgres function instead.
//

import Foundation

protocol SharedStatsService {
    /// Number of distinct people who opened today's song.
    func todaysListenerCount() async throws -> Int
}

// Note this is a plain `struct`, not an actor: it holds no mutable state (just
// returns a constant), so there's nothing to protect against concurrent access.
struct MockSharedStatsService: SharedStatsService {
    func todaysListenerCount() async throws -> Int {
        try? await Task.sleep(for: .milliseconds(200))
        return 8423   // a believable hardcoded number for the mock
    }
}
