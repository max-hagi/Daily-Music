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
        return "\(You) keep serene songs more than almost any other mood. Everything else is just noise."

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

    default: // the_shapeshifter + any future archetypes
        return "\(You) don't have one defining taste. \(You) have all of them. \(Your) keep rate spreads pretty evenly across every mood, and that says a lot about \(you). A lot of good things."
    }
}
