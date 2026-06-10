//
//  ArchetypeAffinity.swift
//  Daily Music
//
//  Archetype Engine v2. Each archetype declares an affinity vector over
//  moods / energy bands / themes / genres; the scorer ranks all of them
//  against the user's smoothed, recency-weighted like-rates. Pure math,
//  no I/O — fully unit-tested (ArchetypeScorerTests). Replaces the
//  raw-count single-mood lookup that mirrored the curator's editorial mix
//  instead of the user's taste.
//  Spec: docs/superpowers/specs/2026-06-10-archetype-engine-design.md
//

import Foundation

/// One archetype's taste signature. Weights are hand-tuned constants —
/// the test suite doubles as the tuning harness (tweak values, not structure).
struct ArchetypeAffinity {
    let profile: TasteProfile
    let moods: [String: Double]
    let energyBands: [String: Double]
    let themes: [String: Double]
    let genres: [String: Double]

    private init(
        _ profile: TasteProfile,
        moods: [String: Double] = [:],
        energy: [String: Double] = [:],
        themes: [String: Double] = [:],
        genres: [String: Double] = [:]
    ) {
        self.profile = profile
        self.moods = moods
        self.energyBands = energy
        self.themes = themes
        self.genres = genres
    }

    /// Order matters: it is the deterministic tie-break (first-seen maximum).
    /// The Shapeshifter has no vector — it wins by absence (see scorer).
    static let all: [ArchetypeAffinity] = [
        ArchetypeAffinity(.partyAnimal,
            moods: ["Euphoric": 1.0, "Joyful": 0.3],
            energy: ["High": 0.6],
            themes: ["Freedom & Escape": 0.3]),
        ArchetypeAffinity(.flowerChild,
            moods: ["Joyful": 1.0, "Euphoric": 0.3, "Serene": 0.2],
            themes: ["Hope & Perseverance": 0.4]),
        ArchetypeAffinity(.hopelessRomantic,
            moods: ["Tender": 1.0],
            energy: ["Low": 0.2],
            themes: ["Love & Romance": 0.6, "Longing & Desire": 0.4, "Heartbreak": 0.3]),
        ArchetypeAffinity(.theHippie,
            moods: ["Serene": 1.0, "Dreamy": 0.2, "Joyful": 0.2],
            energy: ["Low": 0.4],
            themes: ["Freedom & Escape": 0.3, "Hope & Perseverance": 0.2]),
        ArchetypeAffinity(.theStargazer,
            moods: ["Dreamy": 1.0, "Serene": 0.2],
            energy: ["Low": 0.3],
            themes: ["Longing & Desire": 0.4]),
        ArchetypeAffinity(.bornInTheWrongGeneration,
            moods: ["Nostalgic": 1.0],
            themes: ["Memory & Nostalgia": 0.6, "Coming of Age": 0.2]),
        ArchetypeAffinity(.theMelancholic,
            moods: ["Melancholy": 1.0, "Tender": 0.2],
            energy: ["Low": 0.3],
            themes: ["Heartbreak": 0.4, "Loneliness": 0.4]),
        ArchetypeAffinity(.loudAndProud,
            moods: ["Defiant": 1.0, "Dark": 0.2],
            energy: ["High": 0.5],
            themes: ["Rebellion & Protest": 0.5, "Empowerment & Self-Worth": 0.3]),
        ArchetypeAffinity(.theOutsider,
            moods: ["Dark": 1.0, "Melancholy": 0.2],
            themes: ["Loneliness": 0.4]),
        ArchetypeAffinity(.thePophead,
            moods: ["Joyful": 0.4, "Euphoric": 0.4],
            energy: ["High": 0.3],
            genres: ["Pop": 0.9]),
    ]
}

/// Receipts: the top contributing categories behind the winning archetype,
/// with raw counts so the copy can cite real numbers.
struct ArchetypeEvidence: Equatable {
    struct Fact: Equatable {
        let dimensionID: String   // "mood" | "energy" | "theme" | "genre"
        let category: String      // e.g. "Melancholy", "Pop", "High"
        let likes: Int            // raw 👍 in this category
        let total: Int            // raw 👍+👎 in this category
        let hearts: Int           // favorites in this category
        let contribution: Double  // weighted contribution to the winning score
    }
    let facts: [Fact]             // descending by contribution, max 3
}

struct ScoredArchetype: Equatable {
    let profile: TasteProfile
    let score: Double
    let evidence: ArchetypeEvidence
}

enum ArchetypeScorer {
    static let halfLifeDays = 45.0     // a judgment loses half its weight in ~6 weeks
    static let favoriteBoost = 0.75    // a heart is a louder like
    static let scoreFloor = 0.02       // below this → no signature → Shapeshifter
    static let stickyMargin = 0.015    // challenger must beat incumbent by this
    static let confidencePivot = 3.0   // conf = n/(n+pivot): ~0.5 at 3 ratings, ~0.8 at 12

    private struct Tally {
        var wLike = 0.0, wDislike = 0.0      // decay-weighted
        var likes = 0, total = 0, hearts = 0 // raw, for receipts
    }

    private struct Key: Hashable {
        let dim: String
        let cat: String
    }

    /// Rank every archetype against the user's judgments. Returns nil only for
    /// empty input; otherwise the winner (or The Shapeshifter when no score
    /// clears the floor) with its evidence.
    static func score(_ rated: [RatedSong], incumbentID: String? = nil) -> ScoredArchetype? {
        guard !rated.isEmpty else { return nil }

        // Recency decays relative to the NEWEST judgment, not the wall clock:
        // deterministic in tests, and a lapsed user's history keeps its shape.
        let reference = rated.map(\.effectiveRatedAt).max() ?? Date()

        var tallies: [Key: Tally] = [:]
        var allLike = 0.0, allDislike = 0.0
        for r in rated {
            let age = max(0, reference.timeIntervalSince(r.effectiveRatedAt)) / 86_400
            let decay = pow(0.5, age / halfLifeDays)
            let like: Double, dislike: Double
            switch r.value {
            case 1...:
                like = decay * (r.isFavorite ? 1 + favoriteBoost : 1); dislike = 0
            case ..<0:
                like = 0; dislike = decay
            default:
                // Heart-only (favorited, never thumbed) is still a like signal.
                like = r.isFavorite ? decay * favoriteBoost : 0; dislike = 0
            }
            guard like > 0 || dislike > 0 else { continue }
            allLike += like; allDislike += dislike

            var keys: [Key] = []
            if let mood = r.entry.mood { keys.append(Key(dim: "mood", cat: mood)) }
            if let energy = r.entry.energy {
                keys.append(Key(dim: "energy", cat: EnergyBand.band(for: energy).rawValue))
            }
            if let theme = r.entry.theme { keys.append(Key(dim: "theme", cat: theme)) }
            if let genre = r.entry.genre { keys.append(Key(dim: "genre", cat: genre)) }
            for key in keys {
                var t = tallies[key, default: Tally()]
                t.wLike += like
                t.wDislike += dislike
                if r.value > 0 { t.likes += 1 }
                if r.value != 0 { t.total += 1 }
                if r.isFavorite { t.hearts += 1 }
                tallies[key] = t
            }
        }

        // Smoothed overall like-rate — the baseline every category is measured
        // against, removing both positivity bias and curator-exposure bias.
        let overall = (allLike + 1) / (allLike + allDislike + 2)

        var top: ScoredArchetype? = nil
        var incumbent: ScoredArchetype? = nil
        for affinity in ArchetypeAffinity.all {
            var archetypeScore = 0.0
            var facts: [ArchetypeEvidence.Fact] = []
            let tables: [(String, [String: Double])] = [
                ("mood", affinity.moods),
                ("energy", affinity.energyBands),
                ("theme", affinity.themes),
                ("genre", affinity.genres)
            ]
            for (dim, table) in tables {
                for (cat, weight) in table {
                    guard let t = tallies[Key(dim: dim, cat: cat)] else { continue }
                    let n = t.wLike + t.wDislike
                    guard n > 0 else { continue }
                    let rate = (t.wLike + 1) / (n + 2)          // Laplace-smoothed
                    let confidence = n / (n + confidencePivot)   // saturating
                    let c = weight * (rate - overall) * confidence
                    archetypeScore += c
                    if c > 0 {
                        facts.append(.init(dimensionID: dim, category: cat,
                                           likes: t.likes, total: t.total,
                                           hearts: t.hearts, contribution: c))
                    }
                }
            }
            let scored = ScoredArchetype(
                profile: affinity.profile, score: archetypeScore,
                evidence: ArchetypeEvidence(facts: Array(
                    facts.sorted { $0.contribution > $1.contribution }.prefix(3)))
            )
            if affinity.profile.id == incumbentID { incumbent = scored }
            // Strictly-greater keeps the first-seen maximum → list order breaks ties.
            if top == nil || scored.score > top!.score { top = scored }
        }

        guard let winner = top, winner.score >= scoreFloor else {
            return ScoredArchetype(profile: .theShapeshifter, score: top?.score ?? 0,
                                   evidence: ArchetypeEvidence(facts: []))
        }
        if let incumbent, incumbent.profile.id != winner.profile.id,
           incumbent.score >= scoreFloor,
           winner.score - incumbent.score < stickyMargin {
            return incumbent
        }
        return winner
    }
}
