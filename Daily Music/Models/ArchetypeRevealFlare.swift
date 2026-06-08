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
            f(.euphoricDiscoKid, .mirrorSparkles, .discoSweep, .goldGlints, .rotate, .sparkle),
            f(.euphoricSynthPopKid, .waveformRibbons, .neonScan, .scanlines, .surge, .electric),
            f(.euphoricFestivalKid, .confetti, .partyBeams, .sparkleBurst, .bounce, .sparkle),
            f(.euphoricAnthemist, .arenaBursts, .arenaBeams, .pulseRings, .surge, .stageHit),
            f(.euphoricDefault, .sunGlitter, .sunburst, .warmGrain, .pulse, .triumph),
            f(.joyfulFlowerChild, .petals, .gardenGlow, .botanical, .float, .softBloom),
            f(.joyfulBubblegumPop, .popBubbles, .glossyPop, .glossyDots, .bounce, .sparkle),
            f(.joyfulIndieKid, .paperCutouts, .indiePulse, .paper, .pulse, .textureRumble),
            f(.joyfulYoungAtHeart, .motionDots, .skyTrails, .steps, .bounce, .sparkle),
            f(.joyfulDefault, .goldenBubbles, .warmGlow, .bubbles, .float, .triumph),
            f(.tenderCanyonSoul, .canyonDust, .canyonGlow, .guitarStrings, .drift, .textureRumble),
            f(.tenderRomantic, .heartGlints, .roseBloom, .rose, .pulse, .softBloom),
            f(.tenderHopelessRomantic, .heartFragments, .softBloom, .brokenHeart, .strike, .softBloom),
            f(.tenderDefault, .softHearts, .softBloom, .satin, .float, .softBloom),
            f(.sereneFreeSpirit, .leafSweep, .breeze, .breezeLines, .drift, .softBloom),
            f(.sereneMellowSoul, .hazeMotes, .sunHaze, .vinylWobble, .drift, .textureRumble),
            f(.sereneAmbientWanderer, .mist, .tealRipple, .ambientMist, .float, .softBloom),
            f(.sereneDefault, .waterRings, .waterGlow, .liquid, .pulse, .softBloom),
            f(.dreamyNeonRider, .speedLines, .electric, .neonTrail, .strike, .electric),
            f(.dreamyShoegazeKid, .feedbackWaves, .lavenderHaze, .softBlur, .drift, .textureRumble),
            f(.dreamyIndieMystic, .constellationDots, .moonlit, .starfield, .float, .sparkle),
            f(.dreamyDreamChaser, .starTrails, .dreamArc, .lavenderArc, .surge, .sparkle),
            f(.dreamyDefault, .cloudPuffs, .moonHaze, .cloud, .float, .softBloom),
            f(.nostalgicRockPilgrim, .guitarSparks, .ampGlow, .pickSparks, .strike, .stageHit),
            f(.nostalgic80sTimeTraveler, .retroGrid, .synthBars, .clockRipple, .surge, .electric),
            f(.nostalgic90sKid, .cassetteLines, .mutedBlocks, .tape, .drift, .textureRumble),
            f(.nostalgicMemoryKeeper, .photoFlashes, .sepiaFlash, .photoDust, .shimmer, .sparkle),
            f(.nostalgicDefault, .memoryFlecks, .vignette, .memoryDust, .drift, .softBloom),
            f(.melancholyDarkWaver, .moonRings, .darkWave, .darkRipple, .pulse, .shadowPulse),
            f(.melancholyGrungeKid, .grit, .grungeGlow, .paperGrain, .strike, .textureRumble),
            f(.melancholyIndieConfessor, .lyricStreaks, .micGlow, .handwritten, .drift, .shadowPulse),
            f(.melancholyIndieHeartbreaker, .fractureLines, .magentaSlice, .heartSlice, .strike, .softBloom),
            f(.melancholyDefault, .rainSpecks, .cloudMoon, .rain, .drift, .shadowPulse),
            f(.defiantPunkPurist, .jaggedBursts, .stencilFlash, .stencil, .strike, .stageHit),
            f(.defiantRockRebel, .ampSparks, .stageFlash, .flame, .strike, .stageHit),
            f(.defiantGrungeRebel, .smokePulse, .rustGlow, .rust, .surge, .textureRumble),
            f(.defiantProtestRebel, .shockwaves, .posterStripes, .poster, .surge, .stageHit),
            f(.defiantChampion, .victoryRays, .goldArena, .stompRings, .surge, .triumph),
            f(.defiantDefault, .embers, .flamePulse, .ember, .strike, .stageHit),
            f(.darkPostPunkPoet, .noirSpotlight, .noirPurple, .shadow, .drift, .shadowPulse),
            f(.darkIndustrialHeart, .steelSparks, .gearPulse, .steel, .rotate, .textureRumble),
            f(.darkGothSoul, .violetSmoke, .gothMoon, .smoke, .float, .shadowPulse),
            f(.darkNoirSoul, .noirSpotlight, .burgundyNoir, .film, .drift, .shadowPulse),
            f(.darkDarkRebel, .boltCracks, .crimsonBolt, .crackle, .strike, .electric),
            f(.darkDefault, .lowMist, .halfMoon, .mist, .drift, .shadowPulse),
            f(.balancedDefault, .mosaicTiles, .colorRibbons, .mosaic, .pulse, .sparkle)
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
