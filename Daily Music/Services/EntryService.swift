//
//  EntryService.swift
//  Daily Music
//
//  Reads curated daily entries. MockEntryService serves sample content; the live
//  SupabaseEntryService implements the same protocol with queries against
//  `daily_entries` where `published_at <= now()`.
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

    /// Deterministic id for the Nth mock entry (shared with MockRatingService).
    static func mockEntryID(_ i: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i))!
    }

    /// (title, artist, genre, year, mood, energy 1–5, theme)
    static let seed: [(String, String, String, Int, String, Int, String)] = [
        ("Nightswimming", "R.E.M.", "Alternative", 1992, "Melancholy", 2, "Memory & Nostalgia"),
        ("A Real Hero", "College & Electric Youth", "Synthwave", 2010, "Dreamy", 3, "Hope & Perseverance"),
        ("Pyramid Song", "Radiohead", "Alternative", 2001, "Melancholy", 2, "Loneliness"),
        ("This Must Be the Place", "Talking Heads", "Alternative", 1983, "Tender", 3, "Love & Romance"),
        ("Running Up That Hill", "Kate Bush", "Pop", 1985, "Defiant", 4, "Longing & Desire"),
        ("Atmosphere", "Joy Division", "Alternative", 1980, "Melancholy", 2, "Loneliness"),
        ("Just Like Heaven", "The Cure", "Alternative", 1987, "Euphoric", 4, "Love & Romance"),
        ("Heroes", "David Bowie", "Rock", 1977, "Defiant", 4, "Hope & Perseverance"),
        ("Enjoy the Silence", "Depeche Mode", "Synthwave", 1990, "Melancholy", 3, "Love & Romance"),
        ("Dreams", "Fleetwood Mac", "Rock", 1977, "Serene", 3, "Heartbreak"),
        ("Cherry-coloured Funk", "Cocteau Twins", "Alternative", 1990, "Dreamy", 2, "Longing & Desire"),
        ("Blue Monday", "New Order", "Synthwave", 1983, "Defiant", 5, "Loneliness"),
        ("In the Aeroplane Over the Sea", "Neutral Milk Hotel", "Alternative", 1998, "Tender", 3, "Memory & Nostalgia"),
        ("Such Great Heights", "The Postal Service", "Electronic", 2003, "Euphoric", 4, "Love & Romance"),
        ("Avril 14th", "Aphex Twin", "Electronic", 2001, "Melancholy", 1, "Loneliness"),
        ("Fade Into You", "Mazzy Star", "Alternative", 1993, "Dreamy", 2, "Longing & Desire"),
        ("Age of Consent", "New Order", "Synthwave", 1983, "Melancholy", 4, "Heartbreak"),
        ("Boys of Summer", "Don Henley", "Rock", 1984, "Nostalgic", 3, "Memory & Nostalgia"),
        ("Teardrop", "Massive Attack", "Electronic", 1998, "Melancholy", 2, "Love & Romance"),
        ("Once in a Lifetime", "Talking Heads", "Alternative", 1980, "Defiant", 4, "Coming of Age"),
        ("Space Song", "Beach House", "Alternative", 2015, "Dreamy", 2, "Longing & Desire"),
        ("Vienna", "Billy Joel", "Pop", 1977, "Tender", 2, "Coming of Age"),
        ("The Killing Moon", "Echo & the Bunnymen", "Alternative", 1984, "Melancholy", 3, "Loneliness"),
        ("Holocene", "Bon Iver", "Alternative", 2011, "Serene", 2, "Memory & Nostalgia"),
    ]

    /// Ratings aligned by index to `seed` (+1 👍 / -1 👎). Skews toward liking
    /// melancholy & 1980s songs so the mock mirror reads "Melancholy / 1980s".
    static let seedRatingValues: [Int] = [
        1, -1, 1, 1, 1, 1, -1, 1, 1, -1,
        1, -1, 1, -1, 1, 1, 1, -1, 1, -1,
        1, 1, 1, 1
    ]

    init() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }

        entries = Self.seed.enumerated().map { index, s in
            DailyEntry(
                id: Self.mockEntryID(index),
                date: day(-index),
                title: s.0, artist: s.1,
                albumArtURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/97/1a/9b/971a9bf7-b6dc-8712-ac3a-1d4351512c8b/17CRGIM03466.rgb.jpg/1200x1200bb.jpg"),
                journalMarkdown: "A note about *\(s.0)* by \(s.1).",
                appleMusicID: "1440947554",
                spotifyURI: "spotify:track:4gphxUgq0JSFv2BCLhNDiE",
                genre: s.2, year: s.3, mood: s.4, energy: s.5, theme: s.6,
                language: "English"
            )
        }
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
