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
    /// Number of distinct people who checked in on a given (past) day — the
    /// honest version of the archive "N listened" badge.
    func listenerCount(on date: Date) async throws -> Int
}

// Note this is a plain `struct`, not an actor: it holds no mutable state (just
// returns a constant), so there's nothing to protect against concurrent access.
struct MockSharedStatsService: SharedStatsService {
    func todaysListenerCount() async throws -> Int {
        try? await Task.sleep(for: .milliseconds(200))
        return 8423   // a believable hardcoded number for the mock
    }

    func listenerCount(on date: Date) async throws -> Int {
        try? await Task.sleep(for: .milliseconds(150))
        // Deterministic per-day sample number so the mock UI looks alive.
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return 1_900 + (day * 173 % 6_400)
    }
}
