//
//  StartingRead.swift
//  Daily Music
//
//  The onboarding "first read": the dominant mood/genre/decade from the taste-seed
//  picks, computed through the same TasteMirror the real Insights use. Pure +
//  Codable so it can be persisted (the "you started here" memento).
//

import Foundation

struct StartingRead: Equatable, Codable {
    var mood: String?
    var genre: String?
    var decade: String?

    var isEmpty: Bool { mood == nil && genre == nil && decade == nil }

    /// Build from rated starter songs (👍 = +1, 👎 = -1) via TasteMirror's dominant
    /// standouts (dominant works at any count — no unlock threshold needed here).
    static func from(picks: [RatedSong]) -> StartingRead {
        let mirror = TasteMirror.build(from: picks)
        return StartingRead(
            mood: mirror.mood.topStandout?.name,
            genre: mirror.genre.topStandout?.name,
            decade: mirror.decade.topStandout?.name
        )
    }
}
