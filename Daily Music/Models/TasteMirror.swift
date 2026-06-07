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
struct RatedSong: Equatable, Codable {
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
        static let minRatedArchetype = 10   // a profile is established by the ~10-song onboarding taste-seed, then evolves
    }

    static func build(from rated: [RatedSong]) -> TasteMirror {
        let total = rated.count
        let likes = rated.filter { $0.value > 0 }.count
        let overall = total > 0 ? Double(likes) / Double(total) : 0

        // --- dimensions ---
        let mood = dimension(id: "mood", title: "Mood", from: rated, overall: overall, totalRated: total) { $0.mood }
        let decade = dimension(id: "decade", title: "Decade", from: rated, overall: overall, totalRated: total) { $0.decade }
        let theme = dimension(id: "theme", title: "Theme", from: rated, overall: overall, totalRated: total) { $0.theme }
        let genre = dimension(id: "genre", title: "Genre", from: rated, overall: overall, totalRated: total) { $0.genre }
        let language = dimension(id: "language", title: "Language", from: rated, overall: overall, totalRated: total) { $0.language }
        // --- energy ---
        let energy = energyInsight(from: rated, overall: overall, totalRated: total)
        // --- archetype ---
        let isArchetypeUnlocked = total >= Thresholds.minRatedArchetype
        let archetype: TasteProfile? = isArchetypeUnlocked
            ? TasteProfile.resolve(mood: mood.topStandout?.name,
                                   decade: decade.topStandout?.name,
                                   theme: theme.topStandout?.name)
            : nil

        return TasteMirror(
            totalRated: total, overallLikeRate: overall,
            mood: mood, decade: decade, theme: theme, genre: genre, language: language,
            energy: energy, archetype: archetype, isArchetypeUnlocked: isArchetypeUnlocked
        )
    }
}

extension TasteMirror {
    /// Build one categorical dimension. `key` returns the category for a song, or
    /// nil to exclude it (untagged → never guessed).
    static func dimension(
        id: String, title: String,
        from rated: [RatedSong], overall: Double, totalRated: Int,
        key: (DailyEntry) -> String?
    ) -> DimensionInsight {
        var likes: [String: Int] = [:]
        var dislikes: [String: Int] = [:]
        for r in rated {
            guard let name = key(r.entry), !name.isEmpty else { continue }
            if r.value > 0 { likes[name, default: 0] += 1 } else { dislikes[name, default: 0] += 1 }
        }
        let names = Set(likes.keys).union(dislikes.keys)
        let cats = names
            .map { CategoryStat(name: $0, likes: likes[$0] ?? 0, dislikes: dislikes[$0] ?? 0) }
            .sorted { ($0.likes, $0.total, $1.name) > ($1.likes, $1.total, $0.name) }

        let eligible = cats.filter { $0.total >= Thresholds.minPerCategory }
        let dominant = cats.first { $0.likes > 0 }
        let overIndex = eligible
            .filter { $0.likeRate >= overall + Thresholds.overIndexMargin }
            .max { ($0.likeRate, Double($0.total)) < ($1.likeRate, Double($1.total)) }
        let skip = eligible
            .filter { $0.likeRate < overall }
            .min { ($0.likeRate, -Double($0.total)) < ($1.likeRate, -Double($1.total)) }
        let unlocked = totalRated >= Thresholds.minRatedDimension && eligible.count >= 2

        return DimensionInsight(id: id, title: title, categories: cats,
                                dominant: dominant, overIndex: overIndex, skip: skip,
                                isUnlocked: unlocked)
    }

    static func energyInsight(from rated: [RatedSong], overall: Double, totalRated: Int) -> EnergyInsight {
        let likedEnergies = rated.filter { $0.value > 0 }.compactMap { $0.entry.energy }
        let mean = likedEnergies.isEmpty ? nil
            : Double(likedEnergies.reduce(0, +)) / Double(likedEnergies.count)
        let lean: String? = mean.map {
            switch $0 {
            case ...2.0: "Intimate"
            case 3.5...: "Explosive"
            default:     "Balanced"
            }
        }
        let banded = dimension(id: "energy", title: "Energy", from: rated,
                               overall: overall, totalRated: totalRated) { entry in
            entry.energy.map { EnergyBand.band(for: $0).rawValue }
        }
        return EnergyInsight(likedMean: mean, leanLabel: lean,
                             bands: banded.categories, isUnlocked: banded.isUnlocked)
    }
}

extension DimensionInsight {
    /// The headline category: a genuine over-index if present, else the most-liked.
    var topStandout: CategoryStat? { overIndex ?? dominant }
}
