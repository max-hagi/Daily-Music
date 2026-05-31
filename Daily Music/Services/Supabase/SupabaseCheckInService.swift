//
//  SupabaseCheckInService.swift
//  Daily Music
//
//  Live check-ins backed by the `check_ins` table (one row per user per day).
//  RLS scopes everything to the signed-in user. recordToday upserts so opening
//  the app twice in a day is harmless.
//

import Foundation
import Supabase

final class SupabaseCheckInService: CheckInService {
    private let client = Supa.client

    func recordToday() async throws {
        let userID = try await client.auth.session.user.id
        let today = Self.dayFormatter.string(from: Date())
        try await client
            .from("check_ins")
            .upsert(CheckInRow(user_id: userID, date: today), onConflict: "user_id,date")
            .execute()
    }

    func checkInDates() async throws -> Set<Date> {
        let rows: [CheckInRow] = try await client
            .from("check_ins")
            .select("user_id,date")
            .execute()
            .value
        return Set(rows.compactMap { Self.dayFormatter.date(from: $0.date) })
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
}

private struct CheckInRow: Codable {
    let user_id: UUID
    let date: String
}
