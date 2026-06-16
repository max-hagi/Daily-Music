//
//  BadgeService.swift
//  Daily Music
//
//  The seam. Today badges are purely derived on-device (DerivedBadgeService); the
//  protocol exists so a Supabase- or friend-profile-backed source can slot in
//  later (spec Approach C) without the view model or views changing.
//

import Foundation

protocol BadgeService {
    func badges() async -> [EarnedBadge]
}

/// Computes badges from an on-device snapshot. Holds the inputs captured by the
/// view model; the heavy lifting is in the pure BadgeDeriver.
struct DerivedBadgeService: BadgeService {
    let inputs: BadgeInputs
    private let deriver = BadgeDeriver()

    func badges() async -> [EarnedBadge] {
        deriver.deriveAll(from: inputs)
    }
}
