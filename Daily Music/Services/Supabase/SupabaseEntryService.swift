//
//  SupabaseEntryService.swift
//  Daily Music
//
//  The first LIVE service: reads curated entries from the `daily_entries` table.
//  Conforms to the same EntryService protocol the mock did, so swapping it in
//  (see AppEnvironment.live()) requires no view changes.
//
//  "Today's song" is the most recently published entry — robust even if a day
//  gets skipped. RLS on the table already hides rows whose published_at is in
//  the future, but we also filter here so the intent is explicit.
//

import Foundation
import Supabase

final class SupabaseEntryService: EntryService {
    private let client = Supa.client

    func todayEntry() async throws -> DailyEntry? {
        let rows: [DailyEntryRow] = try await client
            .from("daily_entries")
            .select()
            .lte("published_at", value: Self.now)
            .order("date", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first?.toEntry()
    }

    func entry(for date: Date) async throws -> DailyEntry? {
        let rows: [DailyEntryRow] = try await client
            .from("daily_entries")
            .select()
            .eq("date", value: Self.dayFormatter.string(from: date))
            .limit(1)
            .execute()
            .value
        return rows.first?.toEntry()
    }

    func publishedHistory() async throws -> [DailyEntry] {
        let rows: [DailyEntryRow] = try await client
            .from("daily_entries")
            .select()
            .lte("published_at", value: Self.now)
            .order("date", ascending: false)
            .execute()
            .value
        return rows.compactMap { $0.toEntry() }
    }

    private static var now: String { ISO8601DateFormatter().string(from: Date()) }

    /// Postgres `date` columns come back as "yyyy-MM-dd".
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
}

/// Mirrors a row of `daily_entries`. Property names match the snake_case columns
/// so no CodingKeys are needed. Dates are decoded as strings and parsed in
/// `toEntry()` to avoid JSON date-decoding pitfalls.
private struct DailyEntryRow: Decodable {
    let id: UUID
    let date: String
    let title: String
    let artist: String
    let album_art_url: String?
    let journal_md: String
    let apple_music_id: String
    let spotify_uri: String

    func toEntry() -> DailyEntry? {
        guard let day = SupabaseEntryService.dayFormatter.date(from: date) else { return nil }
        return DailyEntry(
            id: id,
            date: day,
            title: title,
            artist: artist,
            albumArtURL: album_art_url.flatMap(URL.init(string:)),
            journalMarkdown: journal_md,
            appleMusicID: apple_music_id,
            spotifyURI: spotify_uri
        )
    }
}
