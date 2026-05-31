//
//  Theme.swift
//  Daily Music
//
//  The shared design language. One place for spacing, corner radii, typography,
//  and brand colors so every screen feels like the same app. Aesthetic
//  direction: bold & expressive — big rounded type, generous radii, and color
//  that comes alive from each day's album art (see ArtworkPalette).
//

import SwiftUI

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 22
        static let small: CGFloat = 12
    }

    enum Brand {
        /// Fallback gradient when no artwork color is available.
        static let gradient = [Color.purple, Color.indigo]
    }
}

extension Font {
    /// Big, friendly, expressive display type.
    static func dmDisplay() -> Font { .system(size: 34, weight: .heavy, design: .rounded) }
    static func dmTitle() -> Font { .system(size: 26, weight: .bold, design: .rounded) }
    static func dmHeadline() -> Font { .system(.headline, design: .rounded) }
    static func dmNumber() -> Font { .system(size: 34, weight: .bold, design: .rounded) }
}
