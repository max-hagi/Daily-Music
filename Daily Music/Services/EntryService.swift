//
//  EntryService.swift
//  Daily Music
//
//  Reads curated daily entries. v1 ships MockEntryService with sample content;
//  later a SupabaseEntryService implements the same protocol with a query
//  against `daily_entries` where `published_at <= now()`.
//

import Foundation

// The content-reading seam. Three queries the UI needs; the live version runs
// these against Supabase, the mock serves the array below.
protocol EntryService {
    /// Today's curated entry, or nil if none is published yet (→ empty state).
    func todayEntry() async throws -> DailyEntry?
    /// The entry for a specific day (used by the Vault detail), or nil.
    func entry(for date: Date) async throws -> DailyEntry?
    /// All entries whose day has arrived, newest first (Vault + Favorites).
    func publishedHistory() async throws -> [DailyEntry]
}

/// Sample content so the whole app is explorable without a backend.
final class MockEntryService: EntryService {
    private let entries: [DailyEntry]

    // `init` builds three sample days relative to today so the content always
    // looks "current" no matter when you run it.
    init() {
        let cal = Calendar.current
        // startOfDay normalizes to midnight so day comparisons ignore the clock time.
        let today = cal.startOfDay(for: Date())
        // A local helper function: today + offset days. The `!` force-unwraps because
        // date arithmetic here can't realistically fail.
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }

        entries = [
            DailyEntry(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                date: day(0),
                title: "Nightswimming",
                artist: "R.E.M.",
                albumArtURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/97/1a/9b/971a9bf7-b6dc-8712-ac3a-1d4351512c8b/17CRGIM03466.rgb.jpg/1200x1200bb.jpg"),
                // `"""` is a multi-line string literal. A trailing `\` joins the
                // next source line WITHOUT inserting a newline — so these wrap
                // nicely in code but render as one flowing paragraph. The text is
                // Markdown (note *italics* / **bold**), rendered later by JournalText.
                journalMarkdown: """
                There's a particular kind of quiet that only exists at 2am, and \
                this song lives inside it. Mike Mills wrote the piano part first \
                and the whole thing was built around a single take.

                *Listen for* the oboe that drifts in near the end — it shouldn't \
                work, and that's exactly why it does.
                """,
                appleMusicID: "1440947554",
                spotifyURI: "spotify:track:4gphxUgq0JSFv2BCLhNDiE",
                genre: "Alternative"
            ),
            DailyEntry(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                date: day(-1),
                title: "A Real Hero",
                artist: "College & Electric Youth",
                albumArtURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/2e/cb/c7/2ecbc706-6356-baf8-dc15-102d255b8f3c/859707985680_cover.jpg/1200x1200bb.jpg"),
                journalMarkdown: """
                Synthwave usually points backward, all neon nostalgia. This one \
                points *forward* — it sounds like deciding to become someone braver.

                Built for late-night drives with nowhere in particular to be.
                """,
                appleMusicID: "515382567",
                spotifyURI: "spotify:track:1WrPa4lrIddctcb0bI8HFV",
                genre: "Synthwave"
            ),
            DailyEntry(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                date: day(-2),
                title: "Pyramid Song",
                artist: "Radiohead",
                albumArtURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/43/d8/ec/43d8ec17-0e96-dba9-21d9-4cdf9d98f2bf/634904078362.png/1200x1200bb.jpg"),
                journalMarkdown: """
                The rhythm famously refuses to sit still — people have written \
                papers arguing about its time signature. Don't count it. Float in it.

                **Why today:** some days don't resolve neatly, and that's allowed.
                """,
                appleMusicID: "1097864572",
                spotifyURI: "spotify:track:2Qwzr1AjJjPft9XYG56dn1",
                genre: "Alternative"
            ),
        ]
    }

    func todayEntry() async throws -> DailyEntry? {
        try? await Task.sleep(for: .milliseconds(300))   // fake network latency
        let today = Calendar.current.startOfDay(for: Date())
        // `.first { … }` returns the first element matching the closure, or nil.
        // `$0` is each entry; isDate(_:inSameDayAs:) ignores time-of-day.
        return entries.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    func entry(for date: Date) async throws -> DailyEntry? {
        entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func publishedHistory() async throws -> [DailyEntry] {
        try? await Task.sleep(for: .milliseconds(300))
        let now = Date()
        return entries
            .filter { $0.date <= now }    // only days that have actually arrived
            .sorted { $0.date > $1.date } // `>` → newest first
    }
}
