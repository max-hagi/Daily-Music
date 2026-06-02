//
//  TasteProfile.swift
//  Daily Music
//
//  The synthesized archetype. NOT scored — a lookup on the user's top standouts
//  (mood, with an optional decade/theme modifier), resolved in priority order
//  with a mood-only fallback. Titles are IDENTIFIERS for now (rename freely).
//

import SwiftUI

struct TasteProfile: Equatable {
    let id: String          // stable identifier; survives renaming `title`
    let title: String       // shown in the hero — currently == id
    let symbol: String
    let colors: [Color]

    private init(_ id: String, _ symbol: String, _ colors: [Color]) {
        self.id = id; self.title = id; self.symbol = symbol; self.colors = colors
    }

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    static let melancholy1980s   = TasteProfile("MELANCHOLY_1980S", "moon.stars.fill", [c(0.42,0.31,0.93), c(0.18,0.13,0.45)])
    static let melancholyDefault = TasteProfile("MELANCHOLY_DEFAULT", "cloud.moon.fill", [c(0.34,0.40,0.62), c(0.16,0.20,0.38)])
    static let defiantProtest    = TasteProfile("DEFIANT_PROTEST", "megaphone.fill", [c(0.86,0.20,0.18), c(0.50,0.10,0.10)])
    static let defiantDefault    = TasteProfile("DEFIANT_DEFAULT", "flame.fill", [c(0.90,0.32,0.16), c(0.55,0.12,0.10)])
    static let euphoric2010s     = TasteProfile("EUPHORIC_2010S", "sparkles", [c(0.96,0.28,0.62), c(0.55,0.20,0.90)])
    static let euphoricDefault   = TasteProfile("EUPHORIC_DEFAULT", "sun.max.fill", [c(1.0,0.55,0.16), c(0.92,0.27,0.35)])
    static let sereneDefault     = TasteProfile("SERENE_DEFAULT", "leaf.fill", [c(0.18,0.72,0.58), c(0.05,0.45,0.50)])
    static let dreamyDefault     = TasteProfile("DREAMY_DEFAULT", "moon.haze.fill", [c(0.55,0.50,0.90), c(0.30,0.26,0.62)])
    static let nostalgicDefault  = TasteProfile("NOSTALGIC_DEFAULT", "clock.arrow.circlepath", [c(0.92,0.62,0.20), c(0.66,0.36,0.14)])
    static let tenderDefault     = TasteProfile("TENDER_DEFAULT", "heart.fill", [c(0.96,0.34,0.50), c(0.79,0.16,0.50)])
    static let joyfulDefault     = TasteProfile("JOYFUL_DEFAULT", "face.smiling.fill", [c(1.0,0.74,0.16), c(0.96,0.45,0.18)])
    static let darkDefault       = TasteProfile("DARK_DEFAULT", "circle.lefthalf.filled", [c(0.30,0.28,0.40), c(0.12,0.11,0.18)])
    static let balancedDefault   = TasteProfile("BALANCED_DEFAULT", "circle.grid.2x2.fill", [c(0.21,0.49,0.93), c(0.11,0.31,0.70)])

    /// Resolve from the user's top standouts. `decade` like "1980s".
    static func resolve(mood: String?, decade: String?, theme: String?) -> TasteProfile {
        if mood == "Melancholy", decade == "1980s" { return melancholy1980s }
        if mood == "Euphoric", let y = decadeYear(decade), y >= 2010 { return euphoric2010s }
        if mood == "Defiant", theme == "Rebellion & Protest" { return defiantProtest }

        switch mood {
        case "Melancholy": return melancholyDefault
        case "Defiant":    return defiantDefault
        case "Euphoric":   return euphoricDefault
        case "Serene":     return sereneDefault
        case "Dreamy":     return dreamyDefault
        case "Nostalgic":  return nostalgicDefault
        case "Tender":     return tenderDefault
        case "Joyful":     return joyfulDefault
        case "Dark":       return darkDefault
        default:           return balancedDefault
        }
    }

    private static func decadeYear(_ decade: String?) -> Int? {
        guard let decade, decade.count >= 4 else { return nil }
        return Int(decade.prefix(4))
    }
}
