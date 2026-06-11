//
//  DriverHighlights.swift
//  Daily Music
//
//  Maps archetype evidence onto the taste-mirror board: which dimensions drove
//  the displayed archetype, at what rank. Evidence only explains the LIVE
//  winning archetype — when the displayed (weekly-stable) archetype lags it,
//  highlights are suppressed rather than explaining something the user can't see.
//

import Foundation

/// One dimension's claim to having shaped the archetype.
struct DriverHighlight: Equatable {
    /// 1-based position among the evidence facts (1 = biggest contribution).
    let rank: Int
    let fact: ArchetypeEvidence.Fact
}

enum DriverHighlights {
    /// Facts arrive sorted descending by contribution; the first fact per
    /// dimension keeps the slot, ranked by overall position.
    static func compute(
        evidence: ArchetypeEvidence?,
        displayedArchetypeID: String?,
        liveArchetypeID: String?
    ) -> [String: DriverHighlight] {
        guard let evidence,
              let displayedArchetypeID,
              displayedArchetypeID == liveArchetypeID else { return [:] }
        var out: [String: DriverHighlight] = [:]
        for (index, fact) in evidence.facts.enumerated() where out[fact.dimensionID] == nil {
            out[fact.dimensionID] = DriverHighlight(rank: index + 1, fact: fact)
        }
        return out
    }
}
