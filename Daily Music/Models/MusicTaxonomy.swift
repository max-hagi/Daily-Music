//
//  MusicTaxonomy.swift
//  Daily Music
//
//  Single source of truth for the fixed Mood/Theme vocabularies. The raw String
//  value is EXACTLY what gets stored on `daily_entries.mood` / `.theme`, so
//  tagging, validation, and chart labels never drift apart.
//

import SwiftUI

/// Emotional tone (valence/flavor). Energy carries intensity separately.
enum Mood: String, CaseIterable {
    case euphoric   = "Euphoric"
    case joyful     = "Joyful"
    case tender     = "Tender"
    case serene     = "Serene"
    case dreamy     = "Dreamy"
    case nostalgic  = "Nostalgic"
    case melancholy = "Melancholy"
    case defiant    = "Defiant"
    case dark       = "Dark"

    var symbol: String {
        switch self {
        case .euphoric:   "sparkles"
        case .joyful:     "sun.max.fill"
        case .tender:     "heart.fill"
        case .serene:     "leaf.fill"
        case .dreamy:     "moon.haze.fill"
        case .nostalgic:  "clock.arrow.circlepath"
        case .melancholy: "cloud.moon.fill"
        case .defiant:    "flame.fill"
        case .dark:       "circle.lefthalf.filled"
        }
    }
}

/// What a song is about (subject matter), distinct from how it feels.
/// Named SongTheme to avoid collision with the design-system `Theme` namespace.
enum SongTheme: String, CaseIterable {
    case love        = "Love & Romance"
    case heartbreak  = "Heartbreak"
    case longing     = "Longing & Desire"
    case loneliness  = "Loneliness"
    case memory      = "Memory & Nostalgia"
    case freedom     = "Freedom & Escape"
    case empowerment = "Empowerment & Self-Worth"
    case rebellion   = "Rebellion & Protest"
    case comingOfAge = "Coming of Age"
    case hope        = "Hope & Perseverance"

    var symbol: String {
        switch self {
        case .love:        "heart.circle.fill"
        case .heartbreak:  "heart.slash.fill"
        case .longing:     "sparkle.magnifyingglass"
        case .loneliness:  "person.fill"
        case .memory:      "photo.on.rectangle.angled"
        case .freedom:     "bird.fill"
        case .empowerment: "figure.stand"
        case .rebellion:   "megaphone.fill"
        case .comingOfAge: "graduationcap.fill"
        case .hope:        "sunrise.fill"
        }
    }
}

/// Energy band labels for the 1–5 scale.
enum EnergyBand: String {
    case low  = "Low"
    case mid  = "Medium"
    case high = "High"

    static func band(for energy: Int) -> EnergyBand {
        switch energy {
        case ...2: .low
        case 3:    .mid
        default:   .high
        }
    }
}
