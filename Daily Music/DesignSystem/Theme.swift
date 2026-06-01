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

// A caseless `enum` used purely as a NAMESPACE. It has no cases, so you can never
// create a `Theme` value — it just groups related constants under dotted names
// like `Theme.Spacing.md`. (An enum is preferred over a struct here precisely
// because it can't be instantiated by accident.) Everything is `static`, so it's
// shared app-wide with no instance needed. CGFloat is the floating-point type
// SwiftUI/UIKit use for sizes and offsets.
enum Theme {
    // A spacing scale (t-shirt sizes). Using these instead of magic numbers keeps
    // padding/margins consistent and easy to retune in one place.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // Corner radii for rounded rectangles (cards vs. small chips).
    enum Radius {
        static let card: CGFloat = 22
        static let small: CGFloat = 12
    }

    enum Brand {
        /// Fallback gradient when no artwork color is available.
        static let gradient = [Color.purple, Color.indigo, Color.cyan, Color.orange]
    }
}

// Extending Font (a type from the SDK we don't own) with our own helpers. After
// this, any view can write `.font(.dmTitle())`. `design: .rounded` selects the
// SF Rounded typeface for that friendly look; `.system(.headline, …)` keeps the
// DYNAMIC TYPE size (scales with the user's accessibility text-size setting),
// whereas the fixed `size:` variants don't scale.
extension Font {
    /// Big, friendly, expressive display type.
    static func dmDisplay() -> Font { .system(size: 34, weight: .heavy, design: .rounded) }
    static func dmTitle() -> Font { .system(size: 26, weight: .bold, design: .rounded) }
    static func dmHeadline() -> Font { .system(.headline, design: .rounded) }
    static func dmNumber() -> Font { .system(size: 34, weight: .bold, design: .rounded) }
}
