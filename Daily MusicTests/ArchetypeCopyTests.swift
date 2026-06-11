//
//  ArchetypeCopyTests.swift
//  Daily MusicTests
//

import XCTest
import Testing
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
            "They keep serene songs more than almost any other mood. Golden-hour pace, every day of the week.")
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

    // MARK: - Receipts

    private func fact(_ dim: String, _ cat: String, likes: Int, total: Int, hearts: Int) -> ArchetypeEvidence.Fact {
        ArchetypeEvidence.Fact(dimensionID: dim, category: cat,
                               likes: likes, total: total, hearts: hearts, contribution: 1)
    }

    func test_receipts_moodFact_withHearts() {
        let e = ArchetypeEvidence(facts: [fact("mood", "Melancholy", likes: 6, total: 7, hearts: 3)])
        XCTAssertEqual(archetypeReceiptsCopy(evidence: e, isCurrentUser: true),
                       "You liked 6 of your 7 Melancholy drops — and hearted 3 of them.")
    }

    func test_receipts_genreFact_thirdPerson_noHearts() {
        let e = ArchetypeEvidence(facts: [fact("genre", "Pop", likes: 9, total: 11, hearts: 0)])
        XCTAssertEqual(archetypeReceiptsCopy(evidence: e, isCurrentUser: false),
                       "They liked 9 of their 11 Pop tracks.")
    }

    func test_receipts_themeFact_lowercasesCategory() {
        let e = ArchetypeEvidence(facts: [fact("theme", "Heartbreak", likes: 5, total: 6, hearts: 0)])
        XCTAssertEqual(archetypeReceiptsCopy(evidence: e, isCurrentUser: true),
                       "You liked 5 of your 6 songs about heartbreak.")
    }

    func test_receipts_emptyEvidence_returnsNil() {
        XCTAssertNil(archetypeReceiptsCopy(evidence: ArchetypeEvidence(facts: []), isCurrentUser: true))
    }

    // MARK: - Voiced copy covers the new cast

    func test_pophead_hasDedicatedVoice() {
        let pop = archetypeHeroCopy(profile: .thePophead, winningModifier: nil, isCurrentUser: true)
        let fallback = archetypeHeroCopy(profile: .theShapeshifter, winningModifier: nil, isCurrentUser: true)
        XCTAssertNotEqual(pop, fallback)
        XCTAssertFalse(pop.isEmpty)
    }

    func test_everyArchetypeHasNonEmptyHeroCopy() {
        for profile in TasteProfile.allCases {
            XCTAssertFalse(archetypeHeroCopy(profile: profile, winningModifier: nil,
                                             isCurrentUser: true).isEmpty, profile.id)
        }
    }
}

// MARK: - Driver receipt copy

struct DriverReceiptCopyTests {

    private func fact(dim: String = "mood", cat: String = "Dark",
                      likes: Int, total: Int, hearts: Int) -> ArchetypeEvidence.Fact {
        .init(dimensionID: dim, category: cat, likes: likes, total: total,
              hearts: hearts, contribution: 0.2)
    }

    @Test func thumbedCounts() {
        #expect(driverReceiptCopy(fact: fact(likes: 8, total: 10, hearts: 0), isCurrentUser: true)
                == "You liked 8 of 10 Dark picks")
    }

    @Test func heartsSuffix() {
        #expect(driverReceiptCopy(fact: fact(likes: 8, total: 10, hearts: 3), isCurrentUser: true)
                == "You liked 8 of 10 Dark picks — 3 hearted")
    }

    @Test func heartOnly() {
        #expect(driverReceiptCopy(fact: fact(likes: 0, total: 0, hearts: 3), isCurrentUser: true)
                == "3 hearts on Dark picks")
    }

    @Test func singleHeartOnly() {
        #expect(driverReceiptCopy(fact: fact(likes: 0, total: 0, hearts: 1), isCurrentUser: true)
                == "1 heart on Dark picks")
    }

    @Test func degenerateFallback() {
        #expect(driverReceiptCopy(fact: fact(likes: 0, total: 0, hearts: 0), isCurrentUser: true)
                == "Dark picks shaped this")
    }

    @Test func friendVariant() {
        #expect(driverReceiptCopy(fact: fact(likes: 8, total: 10, hearts: 0), isCurrentUser: false)
                == "They liked 8 of 10 Dark picks")
    }

    @Test func themePhrasing() {
        #expect(driverReceiptCopy(fact: fact(dim: "theme", cat: "Loneliness", likes: 5, total: 6, hearts: 0), isCurrentUser: true)
                == "You liked 5 of 6 songs about loneliness")
    }

    @Test func energyPhrasing() {
        #expect(driverReceiptCopy(fact: fact(dim: "energy", cat: "High", likes: 5, total: 6, hearts: 0), isCurrentUser: true)
                == "You liked 5 of 6 High energy picks")
    }
}
