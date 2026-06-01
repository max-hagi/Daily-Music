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
        // upsert = insert-or-update. `onConflict: "user_id,date"` names the unique
        // constraint: if a row for this user+day already exists, do nothing harmful
        // instead of erroring. That's what makes opening the app twice a no-op.
        try await client
            .from("check_ins")
            .upsert(CheckInRow(user_id: userID, date: today), onConflict: "user_id,date")
            .execute()
    }

    func checkInDates() async throws -> Set<Date> {
        let rows: [CheckInRow] = try await client
            .from("check_ins")
            .select("user_id,date")   // RLS scopes this to the current user
            .execute()
            .value
        // Parse each "yyyy-MM-dd" back into a Date; compactMap drops any that fail.
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

// Codable (= Decodable + Encodable) here because this one struct is used for BOTH
// the upsert body (encode) and the select result (decode).
private struct CheckInRow: Codable {
    let user_id: UUID
    let date: String
}
