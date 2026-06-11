//
//  BoardEntranceFlavor.swift
//  Daily Music
//
//  Maps an archetype's reveal LightStyle to the taste-mirror board's hero
//  bloom parameters, so the entrance inherits the archetype's personality:
//  moody archetypes breathe slow and dark, pop archetypes flash quick and
//  bright. Pure data — the board animates with these numbers.
//

import Foundation

struct BoardEntranceFlavor: Equatable {
    /// Seconds for the full swell-and-settle of the hero shadow.
    let bloomDuration: Double
    /// Peak shadow radius (rest state is 20).
    let bloomRadius: Double
    /// Peak shadow opacity (rest state is 0.35).
    let bloomOpacity: Double

    static let standard = BoardEntranceFlavor(bloomDuration: 0.9, bloomRadius: 34, bloomOpacity: 0.55)

    static func flavor(for lightStyle: ArchetypeRevealFlare.LightStyle) -> BoardEntranceFlavor {
        switch lightStyle {
        // Slow, heavy glow — moody archetypes (Outsider, Melancholic, Stargazer…).
        case .halfMoon, .cloudMoon, .moonlit, .moonHaze, .darkWave, .gothMoon,
             .noirPurple, .burgundyNoir, .vignette, .lavenderHaze:
            return BoardEntranceFlavor(bloomDuration: 1.4, bloomRadius: 30, bloomOpacity: 0.45)
        // Quick, bright pop — party/pop/electric archetypes.
        case .partyBeams, .glossyPop, .stageFlash, .discoSweep, .neonScan,
             .arenaBeams, .goldArena, .electric, .crimsonBolt, .synthBars, .stencilFlash:
            return BoardEntranceFlavor(bloomDuration: 0.6, bloomRadius: 42, bloomOpacity: 0.7)
        // Warm drift — soft archetypes (Romantic, Flower Child, Hippie…).
        case .softBloom, .gardenGlow, .warmGlow, .roseBloom, .breeze,
             .sunHaze, .sunburst, .canyonGlow:
            return BoardEntranceFlavor(bloomDuration: 1.0, bloomRadius: 38, bloomOpacity: 0.6)
        default:
            return .standard
        }
    }
}
