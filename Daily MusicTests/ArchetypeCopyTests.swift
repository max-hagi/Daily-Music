//
//  ArchetypeCopyTests.swift
//  Daily MusicTests
//

import XCTest
@testable import Daily_Music

final class ArchetypeCopyTests: XCTestCase {

    // MARK: - Current user / modifier wins

    func test_partyAnimal_eraModifier_currentUser() {
        let wm = WinningModifier(dimensionID: "decade", categoryName: "1980s",
                                 likeRate: 0.72, total: 18, margin: 0.14)
        let copy = archetypeHeroCopy(profile: .partyAnimal, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Turns out 1980s music is basically a standing invitation and you never say no. Almost every track makes the cut.")
    }

    func test_partyAnimal_noModifier_currentUser() {
        let copy = archetypeHeroCopy(profile: .partyAnimal, winningModifier: nil, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Euphoric songs show up and you say yes. Consistently, enthusiastically, every time.")
    }

    func test_hopelessRomantic_genreModifier_currentUser() {
        let wm = WinningModifier(dimensionID: "genre", categoryName: "R&B",
                                 likeRate: 0.81, total: 12, margin: 0.23)
        let copy = archetypeHeroCopy(profile: .hopelessRomantic, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "R&B gets you every time. Your keep rate there is almost embarrassingly high.")
    }

    func test_stargazer_themeModifier_currentUser() {
        let wm = WinningModifier(dimensionID: "theme", categoryName: "Longing",
                                 likeRate: 0.75, total: 10, margin: 0.17)
        let copy = archetypeHeroCopy(profile: .theStargazer, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Songs about longing take you somewhere. You follow. You keep nearly every one.")
    }

    func test_bornWrongGen_eraModifier_currentUser() {
        let wm = WinningModifier(dimensionID: "decade", categoryName: "1970s",
                                 likeRate: 0.80, total: 14, margin: 0.22)
        let copy = archetypeHeroCopy(profile: .bornInTheWrongGeneration, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "1970s was made for you and you both know it. Your keep rate there is almost unfairly high for someone who technically wasn't there.")
    }

    func test_melancholic_eraModifier_currentUser() {
        let wm = WinningModifier(dimensionID: "decade", categoryName: "1990s",
                                 likeRate: 0.79, total: 16, margin: 0.21)
        let copy = archetypeHeroCopy(profile: .theMelancholic, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "There's a weight to 1990s music that you understand on a level most people don't even look for. You keep nearly all of it.")
    }

    // MARK: - Mood fallbacks (no modifier / wrong dimension)

    func test_stargazer_genreModifier_fallsBackToMood() {
        let wm = WinningModifier(dimensionID: "genre", categoryName: "Ambient",
                                 likeRate: 0.75, total: 10, margin: 0.17)
        let copy = archetypeHeroCopy(profile: .theStargazer, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Dreamy songs take you somewhere. You keep nearly all of them. It's less a habit than a timezone.")
    }

    func test_melancholic_themeModifier_fallsBackToMood() {
        let wm = WinningModifier(dimensionID: "theme", categoryName: "Loss",
                                 likeRate: 0.79, total: 14, margin: 0.21)
        let copy = archetypeHeroCopy(profile: .theMelancholic, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Melancholy songs make up more of your keeps than almost any other mood. Not because you're not paying attention. Because you are.")
    }

    // MARK: - Mood-only archetypes (modifier ignored)

    func test_flowerChild_ignoresModifier() {
        let wm = WinningModifier(dimensionID: "decade", categoryName: "1990s",
                                 likeRate: 0.7, total: 10, margin: 0.12)
        let copy = archetypeHeroCopy(profile: .flowerChild, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "Joyful songs make up more of your keeps than almost any other mood. Guilty pleasure? Never met her.")
    }

    func test_loudAndProud_ignoresModifier() {
        let wm = WinningModifier(dimensionID: "genre", categoryName: "Metal",
                                 likeRate: 0.85, total: 10, margin: 0.27)
        let copy = archetypeHeroCopy(profile: .loudAndProud, winningModifier: wm, isCurrentUser: true)
        XCTAssertEqual(copy,
            "You keep defiant songs more than almost any other mood. Your eardrums will heal.")
    }

    func test_outsider_ignoresModifier() {
        let copy = archetypeHeroCopy(profile: .theOutsider, winningModifier: nil, isCurrentUser: true)
        XCTAssertEqual(copy,
            "You keep dark songs more than almost any other mood. You smile, sometimes.")
    }

    func test_shapeshifter_noModifier() {
        let copy = archetypeHeroCopy(profile: .theShapeshifter, winningModifier: nil, isCurrentUser: true)
        XCTAssertEqual(copy,
            "You don't have one defining taste. You have all of them. Your keep rate spreads pretty evenly across every mood, and that says a lot about you. A lot of good things.")
    }

    // MARK: - Friend mirror (isCurrentUser: false)

    func test_partyAnimal_eraModifier_friend() {
        let wm = WinningModifier(dimensionID: "decade", categoryName: "1980s",
                                 likeRate: 0.72, total: 18, margin: 0.14)
        let copy = archetypeHeroCopy(profile: .partyAnimal, winningModifier: wm, isCurrentUser: false)
        XCTAssertEqual(copy,
            "Turns out 1980s music is basically a standing invitation and they never say no. Almost every track makes the cut.")
    }

    func test_hippie_friend() {
        let copy = archetypeHeroCopy(profile: .theHippie, winningModifier: nil, isCurrentUser: false)
        XCTAssertEqual(copy,
            "They keep serene songs more than almost any other mood. Everything else is just noise.")
    }

    func test_hopelessRomantic_genreModifier_friend() {
        let wm = WinningModifier(dimensionID: "genre", categoryName: "Soul",
                                 likeRate: 0.78, total: 11, margin: 0.2)
        let copy = archetypeHeroCopy(profile: .hopelessRomantic, winningModifier: wm, isCurrentUser: false)
        XCTAssertEqual(copy,
            "Soul gets them every time. Their keep rate there is almost embarrassingly high.")
    }

    func test_outsider_friend() {
        let copy = archetypeHeroCopy(profile: .theOutsider, winningModifier: nil, isCurrentUser: false)
        XCTAssertEqual(copy,
            "They keep dark songs more than almost any other mood. They smile, sometimes.")
    }

    // MARK: - No em-dashes in any output

    func test_noEmDashesInAnyOutput() {
        let modifiers: [WinningModifier?] = [
            nil,
            WinningModifier(dimensionID: "decade", categoryName: "1980s", likeRate: 0.72, total: 10, margin: 0.14),
            WinningModifier(dimensionID: "theme",  categoryName: "Love",  likeRate: 0.75, total: 10, margin: 0.17),
            WinningModifier(dimensionID: "genre",  categoryName: "Rock",  likeRate: 0.80, total: 10, margin: 0.22),
        ]
        for profile in TasteProfile.allCases {
            for modifier in modifiers {
                let copy = archetypeHeroCopy(profile: profile, winningModifier: modifier, isCurrentUser: true)
                XCTAssertFalse(copy.contains("\u{2014}"),
                    "Em-dash found in \(profile.id) copy: \(copy)")
            }
        }
    }

    // MARK: - Engine v2 cast

    func test_cast_retitlesKeepFrozenIDs() {
        XCTAssertEqual(TasteProfile.theHippie.id, "the_hippie")
        XCTAssertEqual(TasteProfile.theHippie.title, "Golden Hour")
        XCTAssertEqual(TasteProfile.theHippie.tagline, "Life at 0.75× speed. On purpose.")
        XCTAssertEqual(TasteProfile.theMelancholic.id, "the_melancholic")
        XCTAssertEqual(TasteProfile.theMelancholic.title, "The Poet")
    }

    func test_pophead_existsAndIsRegistered() {
        XCTAssertEqual(TasteProfile.thePophead.id, "the_pophead")
        XCTAssertEqual(TasteProfile.thePophead.title, "The Pophead")
        XCTAssertTrue(TasteProfile.allCases.contains(TasteProfile.thePophead))
        XCTAssertEqual(TasteProfile.profile(id: "the_pophead")?.title, "The Pophead")
    }
}
