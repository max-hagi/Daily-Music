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
        // This chain is Supabase's fluent query builder — it reads top-to-bottom
        // as one SQL query and only hits the network at `.execute()`:
        //   .from(table) → .select(all columns) → .lte(col, value): WHERE col <= value
        //   → .order(...) → .limit(1).
        // The `let rows: [DailyEntryRow] = … .value` line is the magic: because we
        // ANNOTATE the type, `.value` decodes the JSON response straight into our
        // Decodable struct array (Codable doing the work). "Today" = latest
        // published row, which survives skipped days better than matching today's date.
        let rows: [DailyEntryRow] = try await client
            .from("daily_entries")
            .select()
            .lte("published_at", value: Self.now)
            .order("date", ascending: false)
            .limit(1)
            .execute()
            .value
        // `.first?` is nil for an empty array → maps to the "no song yet" empty state.
        return rows.first?.toEntry()
    }

    func entry(for date: Date) async throws -> DailyEntry? {
        let rows: [DailyEntryRow] = try await client
            .from("daily_entries")
            .select()
            .eq("date", value: Self.dayFormatter.string(from: date))   // WHERE date = 'yyyy-MM-dd'
            .limit(1)
            .execute()
            .value
        return rows.first?.toEntry()
    }

    func publishedHistory() async throws -> [DailyEntry] {
        let rows: [DailyEntryRow] = try await client
            .from("daily_entries")
            .select()
            .lte("published_at", value: Self.now)   // exclude future-dated rows (RLS also enforces this)
            .order("date", ascending: false)        // newest first
            .execute()
            .value
        // compactMap drops any row whose date string failed to parse (toEntry → nil).
        return rows.compactMap { $0.toEntry() }
    }

    // Current time as an ISO-8601 string, the format Postgres timestamptz expects.
    // A computed property so it's "now" each call.
    private static var now: String { ISO8601DateFormatter().string(from: Date()) }

    /// Postgres `date` columns come back as "yyyy-MM-dd".
    // This `= { … }()` is an immediately-invoked closure: the braces hold setup
    // code and the trailing `()` runs it, returning the configured formatter. It's
    // the standard way to build-and-configure an object in a single `let`.
    // DateFormatters are expensive to create, so we make ONE and reuse it (static).
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
// This is the "data transfer object" pattern: a private struct shaped EXACTLY
// like the DB row (snake_case names so Codable auto-maps each column), kept
// separate from the app's clean `DailyEntry` model. Only `Decodable` (read-only)
// since we never write entries from the app. Optionals (`String?`) decode as nil
// when the column is null/absent — that's why adding `genre` didn't break old rows.
private struct DailyEntryRow: Decodable {
    let id: UUID
    let date: String
    let title: String
    let artist: String
    let album_art_url: String?
    let journal_md: String
    let apple_music_id: String
    let spotify_uri: String
    let genre: String?

    // Convert the raw row into the app's model. Returns optional because a row
    // with an unparseable date is treated as invalid (guard → nil).
    func toEntry() -> DailyEntry? {
        guard let day = SupabaseEntryService.dayFormatter.date(from: date) else { return nil }
        return DailyEntry(
            id: id,
            date: day,
            title: title,
            artist: artist,
            // flatMap: if album_art_url is non-nil, try URL(string:) on it (which
            // itself returns an optional); nil stays nil. Avoids nested optionals.
            albumArtURL: album_art_url.flatMap(URL.init(string:)),
            journalMarkdown: journal_md,
            appleMusicID: apple_music_id,
            spotifyURI: spotify_uri,
            genre: genre
        )
    }
}
