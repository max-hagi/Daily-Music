//
//  VariantConfig.swift
//  Daily Music
//
//  The four "taste call" choices from the Collection Redesign (spec §11), held in
//  one place so a single debug control can flip them. The DEFAULTS are the locked
//  picks that ship; the in-app picker lives in VariantGalleryView (#if DEBUG only),
//  so release builds are pinned to these defaults and never expose a way to change
//  them. "One compile, four decisions."
//

import Foundation
import Observation

/// Shared bits every taste-call enum exposes so one generic picker can render them.
protocol VariantOption: CaseIterable, Identifiable, Hashable {
    var label: String { get }
}

/// §11.1 — how a permanently-missed day looks in the crate.
enum MissingSleeveVariant: String, VariantOption {
    case dusty   // real art, heavily aged under a dust haze (default — a reward to look at, and rescuable)
    case blank   // empty sleeve, faint outline
    case ghost   // the real art at very low opacity
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dusty: "Dusty"
        case .blank: "Blank"
        case .ghost: "Ghost"
        }
    }
}

/// §11.2 — how a caught-up-later record reads as "you got it, just later".
enum SecondhandVariant: String, VariantOption {
    case wornCornerStamp   // folded corner + "2nd" stamp (default)
    case mutingOnly        // desaturate/dim, nothing else
    case edgeLabel         // a small spine label
    var id: String { rawValue }
    var label: String {
        switch self {
        case .wornCornerStamp: "Worn + stamp"
        case .mutingOnly:      "Muting only"
        case .edgeLabel:       "Edge label"
        }
    }
}

/// §11.3 — how the crate dig feels.
enum CrateFeel: String, VariantOption {
    case flatScroll    // plain horizontal scroll
    case centerTilt    // 3D tilt as sleeves pass centre (default)
    case snapPaging    // snap-to-sleeve paging
    var id: String { rawValue }
    var label: String {
        switch self {
        case .flatScroll:  "Flat scroll"
        case .centerTilt:  "Center-tilt"
        case .snapPaging:  "Snap paging"
        }
    }
}

/// §11.4 — timing/easing of the Today→Vault collection moment.
enum MomentTiming: String, VariantOption {
    case snappy
    case weighty
    case playful   // default (locked pick)
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

@Observable
final class VariantConfig {
    var missingSleeve: MissingSleeveVariant
    var secondhand: SecondhandVariant
    var crateFeel: CrateFeel
    var momentTiming: MomentTiming

    /// Defaults are the locked picks (spec §11 defaults, with the user's one
    /// change: collection moment = playful). Keep these in sync with the
    /// `defaultsMatchLockedPicks` test, which guards the product decision.
    init(missingSleeve: MissingSleeveVariant = .dusty,
         secondhand: SecondhandVariant = .wornCornerStamp,
         crateFeel: CrateFeel = .centerTilt,
         momentTiming: MomentTiming = .playful) {
        self.missingSleeve = missingSleeve
        self.secondhand = secondhand
        self.crateFeel = crateFeel
        self.momentTiming = momentTiming
    }
}
