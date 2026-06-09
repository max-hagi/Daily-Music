//
//  TasteProfile.swift
//  Daily Music
//
//  The synthesised archetype. 9 mood-anchored identities + 1 balanced fallback.
//  NOT scored — a pure mood lookup on the user's top mood. The winning modifier
//  (decade/theme/genre) surfaces as flavor text in the hero, not as a branch here.
//

import SwiftUI

struct TasteProfile: Equatable {
    let id: String          // stable snake_case identifier
    let title: String       // badge shown in the hero
    let tagline: String     // witty one-liner shown under the title
    let symbol: String      // SF Symbol name
    let colors: [Color]     // gradient [lead, tail]

    private init(_ id: String, _ title: String, _ tagline: String, _ symbol: String, _ colors: [Color]) {
        self.id = id; self.title = title; self.tagline = tagline
        self.symbol = symbol; self.colors = colors
    }

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    // ── EUPHORIC ──────────────────────────────────────────────────────────
    static let partyAnimal = TasteProfile(
        "party_animal", "Party Animal",
        "The emergency contact for fun.",
        "sparkles",
        [c(1.0, 0.42, 0.11), c(1.0, 0.24, 0.0)]
    )

    // ── JOYFUL ────────────────────────────────────────────────────────────
    static let flowerChild = TasteProfile(
        "flower_child", "Flower Child",
        "Has a pocket full of sunshine. Sharing whether you asked or not.",
        "leaf.fill",
        [c(1.0, 0.84, 0.0), c(1.0, 0.67, 0.0)]
    )

    // ── TENDER ────────────────────────────────────────────────────────────
    static let hopelessRomantic = TasteProfile(
        "hopeless_romantic", "Hopeless Romantic",
        "Every love song is their autobiography.",
        "heart.fill",
        [c(1.0, 0.39, 0.67), c(0.78, 0.08, 0.52)]
    )

    // ── SERENE ────────────────────────────────────────────────────────────
    static let theHippie = TasteProfile(
        "the_hippie", "The Hippie",
        "Peace and love, man. ☮️ Peace and love.",
        "bird.fill",
        [c(0.13, 0.70, 0.67), c(0.0, 0.50, 0.50)]
    )

    // ── DREAMY ────────────────────────────────────────────────────────────
    static let theStargazer = TasteProfile(
        "the_stargazer", "The Stargazer",
        "Body on Earth. Mind: somewhere past the third star on the right.",
        "moon.stars.fill",
        [c(0.58, 0.44, 0.86), c(0.29, 0.0, 0.51)]
    )

    // ── NOSTALGIC ─────────────────────────────────────────────────────────
    static let bornInTheWrongGeneration = TasteProfile(
        "born_in_the_wrong_generation", "Born in the Wrong Generation",
        "Would've thrived in any decade except this one.",
        "clock.arrow.circlepath",
        [c(0.83, 0.54, 0.10), c(0.55, 0.37, 0.24)]
    )

    // ── MELANCHOLY ────────────────────────────────────────────────────────
    static let theMelancholic = TasteProfile(
        "the_melancholic", "The Melancholic",
        "Won't listen to anything that doesn't mean something. Everything means something.",
        "cloud.moon.fill",
        [c(0.29, 0.44, 0.65), c(0.10, 0.14, 0.49)]
    )

    // ── DEFIANT ───────────────────────────────────────────────────────────
    static let loudAndProud = TasteProfile(
        "loud_and_proud", "Loud & Proud",
        "Not a phase. Never was.",
        "flame.fill",
        [c(0.80, 0.12, 0.12), c(0.40, 0.02, 0.02)]
    )

    // ── DARK ──────────────────────────────────────────────────────────────
    static let theOutsider = TasteProfile(
        "the_outsider", "The Outsider",
        "Sunlight? Never heard of her.",
        "circle.lefthalf.filled",
        [c(0.48, 0.31, 0.75), c(0.10, 0.04, 0.18)]
    )

    // ── BALANCED (no dominant mood) ───────────────────────────────────────
    static let theShapeshifter = TasteProfile(
        "the_shapeshifter", "The Shapeshifter",
        "Commits to nothing. Loves everything.",
        "circle.grid.2x2.fill",
        [c(0.13, 0.33, 0.96), c(0.07, 0.19, 0.48)]
    )

    /// Foreground tint for badge/icon at the top of the hero card.
    /// Romantic has a light top gradient, so badge text must be dark.
    var heroTopTint: Color {
        id == "hopeless_romantic"
            ? Color(red: 0.37, green: 0.0, blue: 0.22).opacity(0.85)
            : .white
    }

    static let allCases: [TasteProfile] = [
        partyAnimal, flowerChild, hopelessRomantic, theHippie, theStargazer,
        bornInTheWrongGeneration, theMelancholic, loudAndProud, theOutsider, theShapeshifter
    ]

    static func profile(id: String?) -> TasteProfile? {
        guard let id else { return nil }
        return allCases.first { $0.id == id }
    }

    // MARK: - resolve

    /// Resolve the archetype from the user's dominant mood. The `modifier`
    /// parameter is unused here — it surfaces as flavor text in the hero copy.
    static func resolve(mood: String?, modifier: String?) -> TasteProfile {
        switch mood {
        case "Euphoric":   return partyAnimal
        case "Joyful":     return flowerChild
        case "Tender":     return hopelessRomantic
        case "Serene":     return theHippie
        case "Dreamy":     return theStargazer
        case "Nostalgic":  return bornInTheWrongGeneration
        case "Melancholy": return theMelancholic
        case "Defiant":    return loudAndProud
        case "Dark":       return theOutsider
        default:           return theShapeshifter
        }
    }
}
