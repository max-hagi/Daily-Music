//
//  StarterPack.swift
//  Daily Music
//
//  A bundled, onboarding-only set of recognizable songs (reusing DailyEntry), shown
//  one at a time in the taste-seed so the user rates 👍/👎 — the same gesture as the
//  daily ritual. These ratings SEED the real taste mirror (see SeedRatings); they are
//  NOT in the Supabase catalog and never touch song_ratings. Swap freely; tags use
//  the same Mood/SongTheme vocabularies as the catalog.
//

import Foundation

enum StarterPack {
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

    /// 12 recognizable songs spanning all 9 moods, 7 genres, and eras 1976–2026.
    /// Rated one-by-one in onboarding to seed the taste mirror; swap any to taste.
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
        song("Banana Pancakes", "Jack Johnson", "1440857795",
             "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/44/06/fd/4406fdc0-aab5-e300-82ba-3e5fe81a68a7/00602537868858.rgb.jpg/600x600bb.jpg",
             genre: "Singer-Songwriter", year: 2005, mood: "Serene", energy: 2, theme: "Love & Romance"),
        song("Space Song", "Beach House", "997914096",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/09/e0/d5/09e0d559-0682-f0f0-5e0c-3cd11e3114fd/beachhouse_depressioncherry_2400_300.jpg/600x600bb.jpg",
             genre: "Alternative", year: 2015, mood: "Dreamy", energy: 2, theme: "Longing & Desire"),
        song("bad guy", "Billie Eilish", "1450695739",
             "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/1a/37/d1/1a37d1b1-8508-54f2-f541-bf4e437dda76/19UMGIM05028.rgb.jpg/600x600bb.jpg",
             genre: "Alternative", year: 2019, mood: "Dark", energy: 3, theme: "Empowerment & Self-Worth"),
        song("HUMBLE.", "Kendrick Lamar", "1440882165",
             "https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/ab/16/ef/ab16efe9-e7f1-66ec-021c-5592a23f0f9e/17UMGIM88793.rgb.jpg/600x600bb.jpg",
             genre: "Hip-Hop/Rap", year: 2017, mood: "Defiant", energy: 4, theme: "Empowerment & Self-Worth"),
        song("Good as Hell", "Lizzo", "1150159755",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/7f/d4/43/7fd443a8-861d-dd70-27a1-f23e221883dc/075679905956.jpg/600x600bb.jpg",
             genre: "Pop", year: 2016, mood: "Joyful", energy: 5, theme: "Empowerment & Self-Worth"),
        song("Skinny Love", "Bon Iver", "947059829",
             "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/21/2f/ea/212fea18-5fdc-ba4d-5dd7-1b07aaa88b67/656605211565.tif/600x600bb.jpg",
             genre: "Alternative", year: 2007, mood: "Tender", energy: 1, theme: "Heartbreak"),
        song("Vienna", "Billy Joel", "158618071",
             "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/37/68/4c/37684c52-dbdf-9bfe-0d87-07492f43dc4c/dj.gmcbwich.jpg/600x600bb.jpg",
             genre: "Rock", year: 1977, mood: "Nostalgic", energy: 2, theme: "Coming of Age"),
        song("2SIDED", "Arlo Parks", "1862571197",
             "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/86/10/2a/86102a67-2d84-24f7-dd60-4c7a6846ed05/5400863205140_cover.jpg/600x600bb.jpg",
             genre: "Alternative", year: 2026, mood: "Melancholy", energy: 2, theme: "Heartbreak"),
        song("Run Away with Me", "Carly Rae Jepsen", "1442810074",
             "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/8e/b9/9b/8eb99b2a-f730-0df5-3c2c-4175d57cd84d/15UMGIM31527.rgb.jpg/600x600bb.jpg",
             genre: "Pop", year: 2015, mood: "Euphoric", energy: 5, theme: "Love & Romance"),
    ]
}
