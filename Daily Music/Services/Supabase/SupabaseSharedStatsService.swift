//
//  SupabaseSharedStatsService.swift
//  Daily Music
//
//  Calls the `todays_listener_count` Postgres function (SECURITY DEFINER, so it
//  can count across every user's check_ins despite RLS). See the SQL in the
//  setup notes.
//

import Foundation
import Supabase

final class SupabaseSharedStatsService: SharedStatsService {
    private let client = Supa.client

    func todaysListenerCount() async throws -> Int {
        // Another SECURITY DEFINER function call (no params). It counts distinct
        // users across the whole check_ins table — something RLS would otherwise
        // forbid. `.value` decodes the function's scalar result straight into Int.
        try await client
            .rpc("todays_listener_count")
            .execute()
            .value
    }
}
