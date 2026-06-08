//
//  TasteProfile.swift
//  Daily Music
//
//  The synthesised archetype. NOT scored — a lookup on the user's top mood
//  plus a single winning cross-dimension modifier (decade > theme > genre by
//  over-index margin). 46 named music-aesthetic badges covering all 9 moods.
//

import SwiftUI

struct TasteProfile: Equatable {
    let id: String          // stable snake_case identifier
    let title: String       // badge shown in the hero
    let symbol: String      // SF Symbol name
    let colors: [Color]     // gradient [lead, tail]

    private init(_ id: String, _ title: String, _ symbol: String, _ colors: [Color]) {
        self.id = id; self.title = title; self.symbol = symbol; self.colors = colors
    }

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    // ── EUPHORIC ──────────────────────────────────────────────────────────
    static let euphoricDiscoKid    = TasteProfile("euphoric_disco_kid",    "Disco Kid",      "music.quarternote.3", [c(0.98,0.72,0.12), c(0.82,0.42,0.08)])
    static let euphoricSynthPopKid = TasteProfile("euphoric_synth_pop_kid","Synth-Pop Kid",  "waveform",            [c(0.10,0.78,0.96), c(0.04,0.40,0.80)])
    static let euphoricFestivalKid = TasteProfile("euphoric_festival_kid", "Festival Kid",   "sparkles",            [c(0.96,0.28,0.62), c(0.55,0.20,0.90)])
    static let euphoricAnthemist   = TasteProfile("euphoric_anthemist",    "Anthemist",      "fist.raised.fill",    [c(0.80,0.22,0.90), c(0.45,0.10,0.68)])
    static let euphoricDefault     = TasteProfile("euphoric_default",      "Euphoric",       "sun.max.fill",        [c(1.0,0.55,0.16),  c(0.92,0.27,0.35)])

    // ── JOYFUL ────────────────────────────────────────────────────────────
    static let joyfulFlowerChild   = TasteProfile("joyful_flower_child",   "Flower Child",   "leaf.fill",           [c(0.55,0.82,0.35), c(0.22,0.58,0.18)])
    static let joyfulBubblegumPop  = TasteProfile("joyful_bubblegum_pop",  "Bubblegum Pop",  "face.smiling.fill",   [c(0.99,0.50,0.75), c(0.88,0.22,0.52)])
    static let joyfulIndieKid      = TasteProfile("joyful_indie_kid",      "Indie Kid",      "headphones",          [c(0.70,0.88,0.22), c(0.38,0.62,0.08)])
    static let joyfulYoungAtHeart  = TasteProfile("joyful_young_at_heart", "Young at Heart", "figure.walk",         [c(0.22,0.70,0.96), c(0.08,0.42,0.70)])
    static let joyfulDefault       = TasteProfile("joyful_default",        "Joy Seeker",     "face.smiling.fill",   [c(1.0,0.74,0.16),  c(0.96,0.45,0.18)])

    // ── TENDER ────────────────────────────────────────────────────────────
    static let tenderCanyonSoul        = TasteProfile("tender_canyon_soul",       "Canyon Soul",      "guitars.fill",       [c(0.88,0.55,0.28), c(0.60,0.28,0.12)])
    static let tenderRomantic          = TasteProfile("tender_romantic",          "Romantic",         "heart.fill",         [c(0.96,0.22,0.48), c(0.72,0.08,0.32)])
    static let tenderHopelessRomantic  = TasteProfile("tender_hopeless_romantic", "Hopeless Romantic","heart.circle.fill",  [c(0.80,0.38,0.80), c(0.48,0.18,0.58)])
    static let tenderDefault           = TasteProfile("tender_default",           "Tender Soul",      "heart.fill",         [c(0.96,0.34,0.50), c(0.79,0.16,0.50)])

    // ── SERENE ────────────────────────────────────────────────────────────
    static let sereneFreeSpirit      = TasteProfile("serene_free_spirit",     "Free Spirit",      "bird.fill",       [c(0.42,0.78,0.62), c(0.18,0.52,0.42)])
    static let sereneMellowSoul      = TasteProfile("serene_mellow_soul",     "Mellow Soul",      "sun.haze.fill",   [c(0.62,0.72,0.40), c(0.32,0.46,0.16)])
    static let sereneAmbientWanderer = TasteProfile("serene_ambient_wanderer","Ambient Wanderer",  "wave.3.right",    [c(0.08,0.55,0.72), c(0.04,0.30,0.48)])
    static let sereneDefault         = TasteProfile("serene_default",         "Still Waters",     "leaf.fill",       [c(0.18,0.72,0.58), c(0.05,0.45,0.50)])

    // ── DREAMY ────────────────────────────────────────────────────────────
    static let dreamyNeonRider    = TasteProfile("dreamy_neon_rider",    "Neon Rider",     "bolt.fill",        [c(0.52,0.18,0.92), c(0.08,0.52,0.90)])
    static let dreamyShoegazeKid  = TasteProfile("dreamy_shoegaze_kid",  "Shoegaze Kid",   "headphones",       [c(0.58,0.42,0.72), c(0.28,0.18,0.48)])
    static let dreamyIndieMystic  = TasteProfile("dreamy_indie_mystic",  "Indie Mystic",   "moon.stars.fill",  [c(0.22,0.32,0.80), c(0.08,0.52,0.62)])
    static let dreamyDreamChaser  = TasteProfile("dreamy_dream_chaser",  "Dream Chaser",   "sparkle",          [c(0.70,0.50,0.90), c(0.42,0.22,0.72)])
    static let dreamyDefault      = TasteProfile("dreamy_default",       "Cloud Drifter",  "moon.haze.fill",   [c(0.55,0.50,0.90), c(0.30,0.26,0.62)])

    // ── NOSTALGIC ─────────────────────────────────────────────────────────
    static let nostalgicRockPilgrim     = TasteProfile("nostalgic_rock_pilgrim",      "Rock Pilgrim",      "guitars.fill",              [c(0.70,0.46,0.18), c(0.42,0.24,0.08)])
    static let nostalgic80sTimeTraveler = TasteProfile("nostalgic_80s_time_traveler", "80s Time Traveler", "clock.arrow.circlepath",    [c(0.90,0.62,0.18), c(0.62,0.36,0.08)])
    static let nostalgic90sKid          = TasteProfile("nostalgic_90s_kid",           "90s Kid",           "cassette.fill",             [c(0.42,0.45,0.72), c(0.20,0.22,0.45)])
    static let nostalgicMemoryKeeper    = TasteProfile("nostalgic_memory_keeper",     "Memory Keeper",     "photo.on.rectangle.angled", [c(0.78,0.60,0.35), c(0.52,0.35,0.15)])
    static let nostalgicDefault         = TasteProfile("nostalgic_default",           "Sentimentalist",    "clock.arrow.circlepath",    [c(0.92,0.62,0.20), c(0.66,0.36,0.14)])

    // ── MELANCHOLY ────────────────────────────────────────────────────────
    static let melancholyDarkWaver         = TasteProfile("melancholy_dark_waver",         "Dark Waver",         "moon.stars.fill",  [c(0.42,0.31,0.93), c(0.18,0.13,0.45)])
    static let melancholyGrungeKid         = TasteProfile("melancholy_grunge_kid",         "Grunge Kid",         "guitars.fill",     [c(0.42,0.46,0.36), c(0.20,0.22,0.15)])
    static let melancholyIndieConfessor    = TasteProfile("melancholy_indie_confessor",    "Indie Confessor",    "mic.fill",         [c(0.18,0.26,0.50), c(0.08,0.12,0.28)])
    static let melancholyIndieHeartbreaker = TasteProfile("melancholy_indie_heartbreaker", "Indie Heartbreaker","heart.slash.fill",  [c(0.62,0.15,0.58), c(0.32,0.06,0.32)])
    static let melancholyDefault           = TasteProfile("melancholy_default",            "Brooder",            "cloud.moon.fill",  [c(0.34,0.40,0.62), c(0.16,0.20,0.38)])

    // ── DEFIANT ───────────────────────────────────────────────────────────
    static let defiantPunkPurist   = TasteProfile("defiant_punk_purist",   "Punk Purist",    "hand.raised.fill",[c(0.80,0.08,0.08), c(0.40,0.04,0.04)])
    static let defiantRockRebel    = TasteProfile("defiant_rock_rebel",    "Rock Rebel",     "guitars.fill",    [c(0.92,0.36,0.08), c(0.58,0.16,0.04)])
    static let defiantGrungeRebel  = TasteProfile("defiant_grunge_rebel",  "Grunge Rebel",   "flame.fill",      [c(0.62,0.22,0.12), c(0.32,0.09,0.04)])
    static let defiantProtestRebel = TasteProfile("defiant_protest_rebel", "Protest Rebel",  "megaphone.fill",  [c(0.86,0.20,0.18), c(0.50,0.10,0.10)])
    static let defiantChampion     = TasteProfile("defiant_champion",      "Champion",       "figure.stand",    [c(0.88,0.70,0.08), c(0.70,0.28,0.08)])
    static let defiantDefault      = TasteProfile("defiant_default",       "Defiant Spirit", "flame.fill",      [c(0.90,0.32,0.16), c(0.55,0.12,0.10)])

    // ── DARK ──────────────────────────────────────────────────────────────
    static let darkPostPunkPoet    = TasteProfile("dark_post_punk_poet",   "Post-Punk Poet",  "mic.fill",               [c(0.26,0.20,0.45), c(0.09,0.07,0.20)])
    static let darkIndustrialHeart = TasteProfile("dark_industrial_heart", "Industrial Heart","gearshape.fill",          [c(0.26,0.26,0.30), c(0.09,0.09,0.12)])
    static let darkGothSoul        = TasteProfile("dark_goth_soul",        "Goth Soul",       "moon.zzz.fill",           [c(0.38,0.15,0.55), c(0.14,0.05,0.26)])
    static let darkNoirSoul        = TasteProfile("dark_noir_soul",        "Noir Soul",       "smoke.fill",              [c(0.42,0.12,0.25), c(0.16,0.04,0.10)])
    static let darkDarkRebel       = TasteProfile("dark_rebel",            "Dark Rebel",      "bolt.fill",               [c(0.52,0.10,0.10), c(0.18,0.04,0.04)])
    static let darkDefault         = TasteProfile("dark_default",          "Midnight Drifter","circle.lefthalf.filled",  [c(0.30,0.28,0.40), c(0.12,0.11,0.18)])

    // ── BALANCED ──────────────────────────────────────────────────────────
    static let balancedDefault = TasteProfile("balanced_default", "Eclectic", "circle.grid.2x2.fill", [c(0.21,0.49,0.93), c(0.11,0.31,0.70)])

    // MARK: - resolve

    /// Resolve from the user's dominant mood + single winning modifier category
    /// (could be a decade like "1980s", a theme like "Heartbreak", or a genre).
    static func resolve(mood: String?, modifier: String?) -> TasteProfile {
        switch (mood, modifier) {

        // ── EUPHORIC ──────────────────────────────────────────────────────
        case ("Euphoric", let d?) where isDecade(d, atLeast: 1970) && !isDecade(d, atLeast: 1980):
            return euphoricDiscoKid
        case ("Euphoric", let d?) where isDecade(d, atLeast: 1980) && !isDecade(d, atLeast: 1990):
            return euphoricSynthPopKid
        case ("Euphoric", let d?) where isDecade(d, atLeast: 2010):
            return euphoricFestivalKid
        case ("Euphoric", "Empowerment & Self-Worth"), ("Euphoric", "Hope & Perseverance"):
            return euphoricAnthemist
        case ("Euphoric", _):
            return euphoricDefault

        // ── JOYFUL ────────────────────────────────────────────────────────
        case ("Joyful", let d?) where isDecade(d, atLeast: 1960) && !isDecade(d, atLeast: 1980):
            return joyfulFlowerChild
        case ("Joyful", let d?) where isDecade(d, atLeast: 2000) && !isDecade(d, atLeast: 2020):
            return joyfulBubblegumPop
        case ("Joyful", "Alternative"), ("Joyful", "Indie Rock"):
            return joyfulIndieKid
        case ("Joyful", "Coming of Age"):
            return joyfulYoungAtHeart
        case ("Joyful", _):
            return joyfulDefault

        // ── TENDER ────────────────────────────────────────────────────────
        case ("Tender", let d?) where isDecade(d, atLeast: 1960) && !isDecade(d, atLeast: 1980):
            return tenderCanyonSoul
        case ("Tender", "Love & Romance"), ("Tender", "Longing & Desire"):
            return tenderRomantic
        case ("Tender", "Heartbreak"):
            return tenderHopelessRomantic
        case ("Tender", _):
            return tenderDefault

        // ── SERENE ────────────────────────────────────────────────────────
        case ("Serene", "Freedom & Escape"), ("Serene", "Coming of Age"):
            return sereneFreeSpirit
        case ("Serene", let d?) where isDecade(d, atLeast: 1960) && !isDecade(d, atLeast: 1990):
            return sereneMellowSoul
        case ("Serene", let d?) where isDecade(d, atLeast: 2000):
            return sereneAmbientWanderer
        case ("Serene", _):
            return sereneDefault

        // ── DREAMY ────────────────────────────────────────────────────────
        case ("Dreamy", let d?) where isDecade(d, atLeast: 1980) && !isDecade(d, atLeast: 1990):
            return dreamyNeonRider
        case ("Dreamy", let d?) where isDecade(d, atLeast: 1990) && !isDecade(d, atLeast: 2000):
            return dreamyShoegazeKid
        case ("Dreamy", "Longing & Desire"), ("Dreamy", "Memory & Nostalgia"):
            return dreamyDreamChaser
        case ("Dreamy", "Alternative"), ("Dreamy", "Indie Rock"):
            return dreamyIndieMystic
        case ("Dreamy", _):
            return dreamyDefault

        // ── NOSTALGIC ─────────────────────────────────────────────────────
        case ("Nostalgic", let d?) where isDecade(d, atLeast: 1980) && !isDecade(d, atLeast: 1990):
            return nostalgic80sTimeTraveler
        case ("Nostalgic", let d?) where isDecade(d, atLeast: 1990) && !isDecade(d, atLeast: 2000):
            return nostalgic90sKid
        case ("Nostalgic", "Rock"):
            return nostalgicRockPilgrim
        case ("Nostalgic", "Memory & Nostalgia"):
            return nostalgicMemoryKeeper
        case ("Nostalgic", _):
            return nostalgicDefault

        // ── MELANCHOLY ────────────────────────────────────────────────────
        case ("Melancholy", let d?) where isDecade(d, atLeast: 1980) && !isDecade(d, atLeast: 1990):
            return melancholyDarkWaver
        case ("Melancholy", let d?) where isDecade(d, atLeast: 1990) && !isDecade(d, atLeast: 2000):
            return melancholyGrungeKid
        case ("Melancholy", "Heartbreak"):
            return melancholyIndieHeartbreaker
        case ("Melancholy", "Loneliness"):
            return melancholyIndieConfessor
        case ("Melancholy", _):
            return melancholyDefault

        // ── DEFIANT ───────────────────────────────────────────────────────
        case ("Defiant", "Rebellion & Protest"):
            return defiantProtestRebel
        case ("Defiant", let d?) where isDecade(d, atLeast: 1990) && !isDecade(d, atLeast: 2000):
            return defiantGrungeRebel
        case ("Defiant", let d?) where isDecade(d, atLeast: 1970) && !isDecade(d, atLeast: 1990):
            return defiantRockRebel
        case ("Defiant", "Empowerment & Self-Worth"), ("Defiant", "Hope & Perseverance"):
            return defiantChampion
        case ("Defiant", "Punk"), ("Defiant", "Punk Rock"):
            return defiantPunkPurist
        case ("Defiant", _):
            return defiantDefault

        // ── DARK ──────────────────────────────────────────────────────────
        case ("Dark", let d?) where isDecade(d, atLeast: 1980) && !isDecade(d, atLeast: 1990):
            return darkPostPunkPoet
        case ("Dark", "Industrial"):
            return darkIndustrialHeart
        case ("Dark", "Gothic"), ("Dark", "Goth"):
            return darkGothSoul
        case ("Dark", "Loneliness"), ("Dark", "Longing & Desire"):
            return darkNoirSoul
        case ("Dark", "Rebellion & Protest"):
            return darkDarkRebel
        case ("Dark", _):
            return darkDefault

        // ── BALANCED (no dominant mood) ───────────────────────────────────
        default:
            return balancedDefault
        }
    }

    // MARK: - helper

    /// True when `decade` string (e.g. "1980s") starts with a year >= `year`.
    private static func isDecade(_ decade: String, atLeast year: Int) -> Bool {
        guard decade.count >= 4, let y = Int(decade.prefix(4)) else { return false }
        return y >= year
    }
}
