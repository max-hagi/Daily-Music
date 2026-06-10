//
//  ArchetypeCopy.swift
//  Daily Music
//
//  Pure function returning the "why you're you" hero copy for each archetype.
//  Extracted from TasteMirrorBoard for testability.
//

import Foundation

func archetypeHeroCopy(
    profile: TasteProfile,
    winningModifier: WinningModifier?,
    isCurrentUser: Bool
) -> String {
    let you   = isCurrentUser ? "you"    : "they"
    let them  = isCurrentUser ? "you"    : "them"
    let your  = isCurrentUser ? "your"   : "their"
    let You   = isCurrentUser ? "You"    : "They"
    let Your  = isCurrentUser ? "Your"   : "Their"
    let youve = isCurrentUser ? "you've" : "they've"
    let youre = isCurrentUser ? "you're" : "they're"

    switch profile.id {
    case "party_animal":
        if let wm = winningModifier, wm.dimensionID == "decade" {
            return "Turns out \(wm.categoryName) music is basically a standing invitation and \(you) never say no. Almost every track makes the cut."
        }
        return "Euphoric songs show up and \(you) say yes. Consistently, enthusiastically, every time."

    case "flower_child":
        return "Joyful songs make up more of \(your) keeps than almost any other mood. Guilty pleasure? Never met her."

    case "hopeless_romantic":
        if let wm = winningModifier, wm.dimensionID == "genre" {
            return "\(wm.categoryName) gets \(them) every time. \(Your) keep rate there is almost embarrassingly high."
        }
        return "A tender song comes on and \(you) say yes. More often than not. More often than almost anything."

    case "the_hippie":
        return "\(You) keep serene songs more than almost any other mood. Golden-hour pace, every day of the week."

    case "the_stargazer":
        if let wm = winningModifier, wm.dimensionID == "theme" {
            return "Songs about \(wm.categoryName.lowercased()) take \(them) somewhere. \(You) follow. \(You) keep nearly every one."
        }
        return "Dreamy songs take \(them) somewhere. \(You) keep nearly all of them. It's less a habit than a timezone."

    case "born_in_the_wrong_generation":
        if let wm = winningModifier, wm.dimensionID == "decade" {
            return "\(wm.categoryName) was made for \(you) and \(you) both know it. \(Your) keep rate there is almost unfairly high for someone who technically wasn't there."
        }
        return "Nostalgic songs make up more of \(your) keeps than almost any other mood. Homesick for somewhere \(youve) never been."

    case "the_melancholic":
        if let wm = winningModifier, wm.dimensionID == "decade" {
            return "There's a weight to \(wm.categoryName) music that \(you) understand on a level most people don't even look for. \(You) keep nearly all of it."
        }
        return "Melancholy songs make up more of \(your) keeps than almost any other mood. Not because \(youre) not paying attention. Because \(you) are."

    case "loud_and_proud":
        return "\(You) keep defiant songs more than almost any other mood. \(Your) eardrums will heal."

    case "the_outsider":
        return "\(You) keep dark songs more than almost any other mood. \(You) smile, sometimes."

    case "the_pophead":
        if let wm = winningModifier, wm.dimensionID == "decade" {
            return "\(wm.categoryName) pop owns \(your) keep rate. The charts and \(you) have an understanding."
        }
        return "Pop songs barely have to ask. \(Your) keep rate there clears everything else. The charts and \(you) have an understanding."

    default: // the_shapeshifter + any future archetypes
        return "\(You) don't have one defining taste. \(You) have all of them. \(Your) keep rate spreads pretty evenly across every mood, and that says a lot about \(you). A lot of good things."
    }
}

/// Receipts: the evidence line under the archetype claim — real numbers from
/// the scorer, so the identity reads as earned, not oracular. nil when there
/// is no positive evidence (e.g. The Shapeshifter), letting callers fall back.
func archetypeReceiptsCopy(evidence: ArchetypeEvidence, isCurrentUser: Bool) -> String? {
    guard let fact = evidence.facts.first, fact.total > 0, fact.likes > 0 else { return nil }
    let You  = isCurrentUser ? "You"  : "They"
    let your = isCurrentUser ? "your" : "their"

    let noun: String
    switch fact.dimensionID {
    case "mood":   noun = "\(fact.category) drops"
    case "theme":  noun = "songs about \(fact.category.lowercased())"
    case "genre":  noun = "\(fact.category) tracks"
    case "energy": noun = "\(fact.category.lowercased())-energy picks"
    default:       noun = "\(fact.category) songs"
    }

    var line = "\(You) liked \(fact.likes) of \(your) \(fact.total) \(noun)"
    if fact.hearts > 0 {
        line += " — and hearted \(fact.hearts) of them"
    }
    return line + "."
}
