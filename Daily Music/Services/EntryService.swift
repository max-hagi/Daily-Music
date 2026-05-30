//
//  EntryService.swift
//  Daily Music
//
//  Reads curated daily entries. v1 ships MockEntryService with sample content;
//  later a SupabaseEntryService implements the same protocol with a query
//  against `daily_entries` where `published_at <= now()`.
//

import Foundation

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

    init() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }

        entries = [
            DailyEntry(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                date: day(0),
                title: "Nightswimming",
                artist: "R.E.M.",
                albumArtURL: URL(string: "https://placehold.co/600x600/1a1a2e/eee?text=Automatic"),
                journalMarkdown: """
                There's a particular kind of quiet that only exists at 2am, and \
                this song lives inside it. Mike Mills wrote the piano part first \
                and the whole thing was built around a single take.

                *Listen for* the oboe that drifts in near the end — it shouldn't \
                work, and that's exactly why it does.
                """,
                appleMusicID: "1440899503",
                spotifyURI: "spotify:track:4gphxUgq0JSFv2BCLhNDiE"
            ),
            DailyEntry(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                date: day(-1),
                title: "A Real Hero",
                artist: "College & Electric Youth",
                albumArtURL: URL(string: "https://placehold.co/600x600/16213e/eee?text=Drive"),
                journalMarkdown: """
                Synthwave usually points backward, all neon nostalgia. This one \
                points *forward* — it sounds like deciding to become someone braver.

                Built for late-night drives with nowhere in particular to be.
                """,
                appleMusicID: "1445016276",
                spotifyURI: "spotify:track:1WrPa4lrIddctcb0bI8HFV"
            ),
            DailyEntry(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                date: day(-2),
                title: "Pyramid Song",
                artist: "Radiohead",
                albumArtURL: URL(string: "https://placehold.co/600x600/0f3460/eee?text=Amnesiac"),
                journalMarkdown: """
                The rhythm famously refuses to sit still — people have written \
                papers arguing about its time signature. Don't count it. Float in it.

                **Why today:** some days don't resolve neatly, and that's allowed.
                """,
                appleMusicID: "1109714933",
                spotifyURI: "spotify:track:2Qwzr1AjJjPft9XYG56dn1"
            ),
        ]
    }

    func todayEntry() async throws -> DailyEntry? {
        try? await Task.sleep(for: .milliseconds(300))
        let today = Calendar.current.startOfDay(for: Date())
        return entries.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    func entry(for date: Date) async throws -> DailyEntry? {
        entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func publishedHistory() async throws -> [DailyEntry] {
        try? await Task.sleep(for: .milliseconds(300))
        let now = Date()
        return entries
            .filter { $0.date <= now }
            .sorted { $0.date > $1.date }
    }
}
