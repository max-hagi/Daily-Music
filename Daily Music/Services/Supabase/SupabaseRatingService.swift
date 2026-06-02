//
//  SupabaseRatingService.swift
//  Daily Music
//
//  Live 👍/👎 ratings against `song_ratings`. Owner-scoped via RLS. value: +1
//  like, -1 dislike; clearing deletes the row.
//

import Foundation
import Supabase

final class SupabaseRatingService: RatingService {
    private let client = Supa.client

    func myRating(entryID: UUID) async throws -> Int? {
        let userID = try await client.auth.session.user.id
        let rows: [RatingRow] = try await client
            .from("song_ratings").select("value")
            .eq("user_id", value: userID).eq("entry_id", value: entryID)
            .limit(1).execute().value
        return rows.first.map { Int($0.value) }
    }

    func setRating(_ value: Int?, entryID: UUID) async throws {
        let userID = try await client.auth.session.user.id
        if let value {
            try await client.from("song_ratings")
                .upsert(RatingInsert(user_id: userID, entry_id: entryID, value: Int16(value)),
                        onConflict: "user_id,entry_id")
                .execute()
        } else {
            try await client.from("song_ratings").delete()
                .eq("user_id", value: userID).eq("entry_id", value: entryID)
                .execute()
        }
    }

    func myRatings() async throws -> [UUID: Int] {
        let userID = try await client.auth.session.user.id
        let rows: [RatingRow] = try await client
            .from("song_ratings").select("entry_id,value")
            .eq("user_id", value: userID).execute().value
        return Dictionary(rows.compactMap { r in r.entry_id.map { ($0, Int(r.value)) } },
                          uniquingKeysWith: { a, _ in a })
    }
}

private struct RatingRow: Decodable { let entry_id: UUID?; let value: Int16 }
private struct RatingInsert: Encodable { let user_id: UUID; let entry_id: UUID; let value: Int16 }
