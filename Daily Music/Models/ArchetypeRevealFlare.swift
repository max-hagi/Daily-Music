//
//  ArchetypeRevealFlare.swift
//  Daily Music
//
//  Data-driven visual and haptic flavor for every taste archetype reveal.
//

import Foundation

struct ArchetypeRevealFlare: Equatable {
    enum ParticleStyle: Equatable {
        case none
        case mirrorSparkles
        case waveformRibbons
        case confetti
        case arenaBursts
        case sunGlitter
        case petals
        case popBubbles
        case paperCutouts
        case motionDots
        case goldenBubbles
        case canyonDust
        case heartGlints
        case heartFragments
        case softHearts
        case leafSweep
        case hazeMotes
        case mist
        case waterRings
        case speedLines
        case feedbackWaves
        case constellationDots
        case starTrails
        case cloudPuffs
        case guitarSparks
        case retroGrid
        case cassetteLines
        case photoFlashes
        case memoryFlecks
        case moonRings
        case grit
        case lyricStreaks
        case fractureLines
        case rainSpecks
        case jaggedBursts
        case ampSparks
        case smokePulse
        case shockwaves
        case victoryRays
        case embers
        case noirSpotlight
        case steelSparks
        case violetSmoke
        case lightSlats
        case boltCracks
        case lowMist
        case mosaicTiles
    }

    enum LightStyle: Equatable {
        case none
        case discoSweep
        case neonScan
        case partyBeams
        case arenaBeams
        case sunburst
        case gardenGlow
        case glossyPop
        case indiePulse
        case skyTrails
        case warmGlow
        case canyonGlow
        case roseBloom
        case softBloom
        case breeze
        case sunHaze
        case tealRipple
        case waterGlow
        case electric
        case lavenderHaze
        case moonlit
        case dreamArc
        case moonHaze
        case ampGlow
        case synthBars
        case mutedBlocks
        case sepiaFlash
        case vignette
        case darkWave
        case grungeGlow
        case micGlow
        case magentaSlice
        case cloudMoon
        case stencilFlash
        case stageFlash
        case rustGlow
        case posterStripes
        case goldArena
        case flamePulse
        case noirPurple
        case gearPulse
        case gothMoon
        case burgundyNoir
        case crimsonBolt
        case halfMoon
        case colorRibbons
    }

    enum Texture: Equatable {
        case none
        case goldGlints
        case scanlines
        case sparkleBurst
        case pulseRings
        case warmGrain
        case botanical
        case glossyDots
        case paper
        case steps
        case bubbles
        case guitarStrings
        case rose
        case brokenHeart
        case satin
        case breezeLines
        case vinylWobble
        case ambientMist
        case liquid
        case neonTrail
        case softBlur
        case starfield
        case lavenderArc
        case cloud
        case pickSparks
        case clockRipple
        case tape
        case photoDust
        case memoryDust
        case darkRipple
        case paperGrain
        case handwritten
        case heartSlice
        case rain
        case stencil
        case flame
        case rust
        case poster
        case stompRings
        case ember
        case shadow
        case steel
        case smoke
        case film
        case crackle
        case mist
        case mosaic
    }

    enum SymbolMotion: Equatable {
        case pulse
        case bounce
        case shimmer
        case drift
        case strike
        case float
        case surge
        case rotate
    }

    enum HapticPattern: Equatable {
        case none
        case sparkle
        case softBloom
        case electric
        case stageHit
        case shadowPulse
        case triumph
        case textureRumble
    }

    let id: String
    let particleStyle: ParticleStyle
    let lightStyle: LightStyle
    let texture: Texture
    let symbolMotion: SymbolMotion
    let hapticPattern: HapticPattern

    static func flare(for profile: TasteProfile) -> ArchetypeRevealFlare {
        flares[profile.id] ?? ArchetypeRevealFlare(
            id: profile.id,
            particleStyle: .mosaicTiles,
            lightStyle: .colorRibbons,
            texture: .mosaic,
            symbolMotion: .pulse,
            hapticPattern: .sparkle
        )
    }

    private static func f(
        _ profile: TasteProfile,
        _ particle: ParticleStyle,
        _ light: LightStyle,
        _ texture: Texture,
        _ motion: SymbolMotion,
        _ haptics: HapticPattern
    ) -> ArchetypeRevealFlare {
        ArchetypeRevealFlare(
            id: profile.id,
            particleStyle: particle,
            lightStyle: light,
            texture: texture,
            symbolMotion: motion,
            hapticPattern: haptics
        )
    }

    private static let flares: [String: ArchetypeRevealFlare] = {
        let list: [ArchetypeRevealFlare] = [
            f(.partyAnimal,                 .confetti,          .partyBeams,    .sparkleBurst,  .bounce,  .sparkle),
            f(.flowerChild,                 .petals,            .gardenGlow,    .botanical,     .float,   .softBloom),
            f(.hopelessRomantic,            .heartFragments,    .softBloom,     .brokenHeart,   .strike,  .softBloom),
            f(.theHippie,                   .leafSweep,         .breeze,        .breezeLines,   .drift,   .softBloom),
            f(.theStargazer,                .constellationDots, .moonlit,       .starfield,     .float,   .sparkle),
            f(.bornInTheWrongGeneration,    .retroGrid,         .synthBars,     .clockRipple,   .surge,   .electric),
            f(.theMelancholic,              .rainSpecks,        .cloudMoon,     .rain,          .drift,   .shadowPulse),
            f(.loudAndProud,                .ampSparks,         .stageFlash,    .flame,         .strike,  .stageHit),
            f(.theOutsider,                 .lowMist,           .halfMoon,      .mist,          .drift,   .shadowPulse),
            f(.theShapeshifter,             .mosaicTiles,       .colorRibbons,  .mosaic,        .pulse,   .sparkle),
        ]
        return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }()
}

struct ArchetypeHapticSchedule: Equatable {
    struct Beat: Equatable {
        enum Kind: Equatable {
            case anticipation
            case flood
            case accent
            case lockIn
        }

        let time: Double
        let kind: Kind
    }

    let beats: [Beat]

    static func crispReward(pattern: ArchetypeRevealFlare.HapticPattern, reduceMotion: Bool) -> ArchetypeHapticSchedule {
        if reduceMotion {
            return ArchetypeHapticSchedule(beats: [Beat(time: 1.1, kind: .lockIn)])
        }

        switch pattern {
        case .none:
            return ArchetypeHapticSchedule(beats: [Beat(time: 2.8, kind: .lockIn)])
        case .softBloom:
            return ArchetypeHapticSchedule(beats: [
                Beat(time: 0.25, kind: .anticipation),
                Beat(time: 1.15, kind: .flood),
                Beat(time: 1.65, kind: .accent),
                Beat(time: 2.8, kind: .lockIn),
            ])
        case .shadowPulse:
            return ArchetypeHapticSchedule(beats: [
                Beat(time: 0.25, kind: .anticipation),
                Beat(time: 1.15, kind: .flood),
                Beat(time: 1.7, kind: .accent),
                Beat(time: 2.3, kind: .accent),
                Beat(time: 2.8, kind: .lockIn),
            ])
        default:
            return ArchetypeHapticSchedule(beats: [
                Beat(time: 0.25, kind: .anticipation),
                Beat(time: 1.15, kind: .flood),
                Beat(time: 1.45, kind: .accent),
                Beat(time: 2.05, kind: .accent),
                Beat(time: 2.8, kind: .lockIn),
            ])
        }
    }
}
