//
//  TasteMirror.swift
//  Daily Music
//
//  The pure, deterministic engine behind Insights. Given the songs a user has
//  rated (👍/👎) and their hand-tagged attributes, it computes per-dimension
//  standouts and a synthesized archetype — transparent arithmetic, no I/O, no
//  scoring model. Fully unit-tested (TasteMirrorTests).
//

import Foundation

/// One rated song: a tagged entry plus the user's judgment (+1 👍 / -1 👎).
struct RatedSong: Equatable {
    let entry: DailyEntry
    let value: Int
}

/// Tallies for one category within a dimension (e.g. mood "Melancholy").
struct CategoryStat: Equatable, Identifiable {
    let name: String
    let likes: Int
    let dislikes: Int
    var total: Int { likes + dislikes }
    var likeRate: Double { total > 0 ? Double(likes) / Double(total) : 0 }
    var id: String { name }
}

/// A categorical dimension's full picture (mood/decade/theme/genre/language).
struct DimensionInsight: Equatable, Identifiable {
    let id: String
    let title: String
    let categories: [CategoryStat]
    let dominant: CategoryStat?
    let overIndex: CategoryStat?
    let skip: CategoryStat?
    let isUnlocked: Bool
}

/// Energy is scalar: a lean from liked songs + a 3-band like-rate breakdown.
struct EnergyInsight: Equatable {
    let likedMean: Double?
    let leanLabel: String?
    let bands: [CategoryStat]
    let isUnlocked: Bool
}

struct TasteMirror: Equatable {
    let totalRated: Int
    let overallLikeRate: Double
    let mood: DimensionInsight
    let decade: DimensionInsight
    let theme: DimensionInsight
    let genre: DimensionInsight
    let language: DimensionInsight
    let energy: EnergyInsight
    let archetype: TasteProfile?
    let isArchetypeUnlocked: Bool

    enum Thresholds {
        static let minPerCategory = 3
        static let overIndexMargin = 0.10
        static let minRatedDimension = 10
        static let minRatedArchetype = 20
    }

    static func build(from rated: [RatedSong]) -> TasteMirror {
        let total = rated.count
        let likes = rated.filter { $0.value > 0 }.count
        let overall = total > 0 ? Double(likes) / Double(total) : 0

        // --- dimensions (replaced in Task 5) ---
        let empty = DimensionInsight(id: "", title: "", categories: [],
                                     dominant: nil, overIndex: nil, skip: nil, isUnlocked: false)
        let mood = empty, decade = empty, theme = empty, genre = empty, language = empty
        // --- energy (replaced in Task 6) ---
        let energy = EnergyInsight(likedMean: nil, leanLabel: nil, bands: [], isUnlocked: false)
        // --- archetype (replaced in Task 12) ---
        let archetype: TasteProfile? = nil
        let isArchetypeUnlocked = false

        return TasteMirror(
            totalRated: total, overallLikeRate: overall,
            mood: mood, decade: decade, theme: theme, genre: genre, language: language,
            energy: energy, archetype: archetype, isArchetypeUnlocked: isArchetypeUnlocked
        )
    }
}
