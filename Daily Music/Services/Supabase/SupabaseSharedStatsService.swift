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
        try await client
            .rpc("todays_listener_count")
            .execute()
            .value
    }
}
