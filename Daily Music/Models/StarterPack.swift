//
//  StarterPack.swift
//  Daily Music
//
//  A bundled, onboarding-only set of recognizable songs (reusing DailyEntry).
//  Used by the taste-seed "this or that" rounds. NOT in the Supabase catalog and
//  never written to song_ratings — purely to compute an onboarding first-read.
//  Swap freely; tags use the same Mood/SongTheme vocabularies as the catalog.
//

import Foundation

enum StarterPack {
    /// One starter song. `date` is irrelevant here (.distantPast); the read uses tags.
    private static func song(
        _ title: String, _ artist: String, _ appleMusicID: String, _ art: String,
        genre: String, year: Int, mood: String, energy: Int, theme: String
    ) -> DailyEntry {
        DailyEntry(
            id: UUID(), date: .distantPast, title: title, artist: artist,
            albumArtURL: URL(string: art), journalMarkdown: "",
            appleMusicID: appleMusicID, spotifyURI: "",
            genre: genre, year: year, mood: mood, energy: energy,
            theme: theme, language: "English"
        )
    }

    // Indices: 0 Dancing Queen · 1 Teen Spirit · 2 Hurt · 3 Levitating · 4 Space Song
    // 5 bad guy · 6 Vienna · 7 Feels Like Summer · 8 Seven Nation Army · 9 Night We Met
    // 10 Good as Hell · 11 Landslide · 12 HUMBLE. · 13 Skinny Love
    static let songs: [DailyEntry] = [
        song("Dancing Queen", "ABBA", "1422648513",
             "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/60/f8/a6/60f8a6bc-e875-238d-f2f8-f34a6034e6d2/14UMGIM07615.rgb.jpg/600x600bb.jpg",
             genre: "Pop", year: 1976, mood: "Euphoric", energy: 4, theme: "Freedom & Escape"),
        song("Smells Like Teen Spirit", "Nirvana", "1440783625",
             "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/95/fd/b9/95fdb9b2-6d2b-92a6-97f2-51c1a6d77f1a/00602527874609.rgb.jpg/600x600bb.jpg",
             genre: "Rock", year: 1991, mood: "Defiant", energy: 5, theme: "Rebellion & Protest"),
        song("Hurt", "Johnny Cash", "1452875626",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/9f/b0/3c/9fb03c5a-28f5-9609-a5fa-8471b6b32fc1/00602498613351.rgb.jpg/600x600bb.jpg",
             genre: "Country", year: 2002, mood: "Melancholy", energy: 2, theme: "Memory & Nostalgia"),
        song("Levitating", "Dua Lipa", "1538003843",
             "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6c/11/d6/6c11d681-aa3a-d59e-4c2e-f77e181026ab/190295092665.jpg/600x600bb.jpg",
             genre: "Pop", year: 2020, mood: "Euphoric", energy: 4, theme: "Love & Romance"),
        song("Space Song", "Beach House", "997914096",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/09/e0/d5/09e0d559-0682-f0f0-5e0c-3cd11e3114fd/beachhouse_depressioncherry_2400_300.jpg/600x600bb.jpg",
             genre: "Alternative", year: 2015, mood: "Dreamy", energy: 2, theme: "Longing & Desire"),
        song("bad guy", "Billie Eilish", "1450695739",
             "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/1a/37/d1/1a37d1b1-8508-54f2-f541-bf4e437dda76/19UMGIM05028.rgb.jpg/600x600bb.jpg",
             genre: "Alternative", year: 2019, mood: "Dark", energy: 3, theme: "Empowerment & Self-Worth"),
        song("Vienna", "Billy Joel", "158618071",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/37/68/4c/37684c52-dbdf-9bfe-0d87-07492f43dc4c/dj.gmcbwich.jpg/600x600bb.jpg",
             genre: "Rock", year: 1977, mood: "Nostalgic", energy: 2, theme: "Coming of Age"),
        song("Feels Like Summer", "Childish Gambino", "1410354351",
             "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/e5/bc/65/e5bc6574-1f2a-24a7-6fe0-d17fd32b9869/886447214268.jpg/600x600bb.jpg",
             genre: "R&B/Soul", year: 2018, mood: "Dreamy", energy: 2, theme: "Hope & Perseverance"),
        song("Seven Nation Army", "The White Stripes", "1533513537",
             "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/07/25/09/0725098a-09f4-f240-e551-94384a590371/886448799009.jpg/600x600bb.jpg",
             genre: "Rock", year: 2003, mood: "Defiant", energy: 5, theme: "Rebellion & Protest"),
        song("The Night We Met", "Lord Huron", "1806531961",
             "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/55/41/4a/55414a18-861a-79d1-e575-5bf8cf205dbe/886445056839_Cover.jpg/600x600bb.jpg",
             genre: "Alternative", year: 2015, mood: "Melancholy", energy: 2, theme: "Heartbreak"),
        song("Good as Hell", "Lizzo", "1150159755",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/7f/d4/43/7fd443a8-861d-dd70-27a1-f23e221883dc/075679905956.jpg/600x600bb.jpg",
             genre: "Pop", year: 2016, mood: "Joyful", energy: 5, theme: "Empowerment & Self-Worth"),
        song("Landslide", "Fleetwood Mac", "1308648844",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/64/cc/0b/64cc0b3b-92fb-66cf-1240-e2afba504e4b/603497863105.jpg/600x600bb.jpg",
             genre: "Rock", year: 1975, mood: "Tender", energy: 2, theme: "Memory & Nostalgia"),
        song("HUMBLE.", "Kendrick Lamar", "1440882165",
             "https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/ab/16/ef/ab16efe9-e7f1-66ec-021c-5592a23f0f9e/17UMGIM88793.rgb.jpg/600x600bb.jpg",
             genre: "Hip-Hop/Rap", year: 2017, mood: "Defiant", energy: 4, theme: "Empowerment & Self-Worth"),
        song("Skinny Love", "Bon Iver", "947059829",
             "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/21/2f/ea/212fea18-5fdc-ba4d-5dd7-1b07aaa88b67/656605211565.tif/600x600bb.jpg",
             genre: "Alternative", year: 2007, mood: "Tender", energy: 1, theme: "Heartbreak"),
    ]

    /// 7 contrast pairs — each song (indices 0–13) appears exactly once.
    private static let pairIndices: [(Int, Int)] = [
        (0, 2),    // Dancing Queen (Euphoric) vs Hurt (Melancholy)
        (1, 13),   // Smells Like Teen Spirit (Defiant) vs Skinny Love (Tender)
        (10, 9),   // Good as Hell (Joyful) vs The Night We Met (Melancholy)
        (8, 4),    // Seven Nation Army (Defiant) vs Space Song (Dreamy)
        (3, 11),   // Levitating (Euphoric) vs Landslide (Tender)
        (12, 6),   // HUMBLE. (Defiant) vs Vienna (Nostalgic)
        (5, 7),    // bad guy (Dark) vs Feels Like Summer (Dreamy)
    ]

    /// The rounds as concrete song pairs.
    static func rounds() -> [(DailyEntry, DailyEntry)] {
        pairIndices.map { (songs[$0.0], songs[$0.1]) }
    }
}
