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

/// One judged song: a tagged entry plus the user's judgment.
/// value: +1 👍 / -1 👎 / 0 = no thumb (heart-only — feeds the scorer, not the tiles).
struct RatedSong: Equatable, Codable {
    let entry: DailyEntry
    let value: Int
    var isFavorite: Bool = false
    var ratedAt: Date? = nil

    /// When the judgment happened. Catalog songs are rated on their drop day,
    /// so `entry.date` is the natural fallback; seeds carry an explicit stamp.
    var effectiveRatedAt: Date { ratedAt ?? entry.date }

    init(entry: DailyEntry, value: Int, isFavorite: Bool = false, ratedAt: Date? = nil) {
        self.entry = entry
        self.value = value
        self.isFavorite = isFavorite
        self.ratedAt = ratedAt
    }

    // Pre-v2 persisted seed JSON lacks the new keys — decode them as optional
    // so an upgrade never wipes the onboarding seed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entry = try c.decode(DailyEntry.self, forKey: .entry)
        value = try c.decode(Int.self, forKey: .value)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        ratedAt = try c.decodeIfPresent(Date.self, forKey: .ratedAt)
    }
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

/// The single cross-dimension modifier that most over-indexes vs the user's average.
/// Captures enough context to produce dynamic hero copy.
struct WinningModifier: Equatable {
    let dimensionID: String    // "decade" | "theme" | "genre" | "language"
    let categoryName: String   // e.g. "1980s", "Heartbreak", "Rock"
    let likeRate: Double       // like-rate within this category
    let total: Int             // total ratings in this category
    let margin: Double         // likeRate − overallLikeRate
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
    let ratedSongs: [RatedSong]
    let winningModifier: WinningModifier?
    /// Receipts behind the winning archetype (nil while locked).
    let evidence: ArchetypeEvidence?

    enum Thresholds {
        static let minPerCategory = 3
        static let overIndexMargin = 0.10
        static let minRatedDimension = 10
        static let minRatedArchetype = 10
    }

    static func build(from rated: [RatedSong], incumbentID: String? = nil) -> TasteMirror {
        // Heart-only songs (value 0) feed the archetype scorer but not the
        // tiles — totalRated, dimensions, and drill-downs keep their meaning.
        let thumbed = rated.filter { $0.value != 0 }
        let total = thumbed.count
        let likes = thumbed.filter { $0.value > 0 }.count
        let overall = total > 0 ? Double(likes) / Double(total) : 0

        // --- dimensions ---
        let mood = dimension(id: "mood", title: "Mood", from: thumbed, overall: overall, totalRated: total) { $0.mood }
        let decade = dimension(id: "decade", title: "Decade", from: thumbed, overall: overall, totalRated: total) { $0.decade }
        let theme = dimension(id: "theme", title: "Theme", from: thumbed, overall: overall, totalRated: total) { $0.theme }
        let genre = dimension(id: "genre", title: "Genre", from: thumbed, overall: overall, totalRated: total) { $0.genre }
        let language = dimension(id: "language", title: "Language", from: thumbed, overall: overall, totalRated: total) { $0.language }
        // --- energy ---
        let energy = energyInsight(from: thumbed, overall: overall, totalRated: total)
        // --- modifier selector ---
        var best: WinningModifier? = nil
        for (dimID, dim) in [("decade", decade), ("theme", theme), ("genre", genre), ("language", language)] {
            guard let oi = dim.overIndex else { continue }
            let margin = oi.likeRate - overall
            if best == nil || margin > best!.margin {
                best = WinningModifier(dimensionID: dimID, categoryName: oi.name,
                                       likeRate: oi.likeRate, total: oi.total, margin: margin)
            }
        }
        let winningModifier = best

        // --- archetype: v2 affinity scorer (hearts included via `rated`) ---
        let isArchetypeUnlocked = total >= Thresholds.minRatedArchetype
        let scored = isArchetypeUnlocked
            ? ArchetypeScorer.score(rated, incumbentID: incumbentID)
            : nil

        return TasteMirror(
            totalRated: total, overallLikeRate: overall,
            mood: mood, decade: decade, theme: theme, genre: genre, language: language,
            energy: energy, archetype: scored?.profile, isArchetypeUnlocked: isArchetypeUnlocked,
            ratedSongs: thumbed, winningModifier: winningModifier,
            evidence: scored?.evidence
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
            if r.value > 0 { likes[name, default: 0] += 1 }
            else if r.value < 0 { dislikes[name, default: 0] += 1 }
        }
        let names = Set(likes.keys).union(dislikes.keys)
        let cats = names
            .map { CategoryStat(name: $0, likes: likes[$0] ?? 0, dislikes: dislikes[$0] ?? 0) }
            .sorted { ($0.likes - $0.dislikes, $0.likes, $1.name) > ($1.likes - $1.dislikes, $1.likes, $0.name) }

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

extension TasteMirror {
    // MARK: drill-down queries

    /// All rated songs that belong to `category` in the given dimension, liked first
    /// then reverse-chronological.
    func songs(inDimension dimension: DimensionInsight, category: String) -> [RatedSong] {
        songs(forDimensionID: dimension.id, category: category)
    }

    /// Same as `songs(inDimension:category:)` but identified by raw dimension string ID
    /// (needed for energy, whose insight type is `EnergyInsight`, not `DimensionInsight`).
    func songs(forDimensionID dimensionID: String, category: String) -> [RatedSong] {
        func tag(_ entry: DailyEntry) -> String? {
            switch dimensionID {
            case "mood":     return entry.mood
            case "decade":   return entry.decade
            case "theme":    return entry.theme
            case "genre":    return entry.genre
            case "language": return entry.language
            case "energy":   return entry.energy.map { EnergyBand.band(for: $0).rawValue }
            default:         return nil
            }
        }
        return ratedSongs
            .filter { tag($0.entry) == category }
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.entry.date > $1.entry.date
            }
    }
}
