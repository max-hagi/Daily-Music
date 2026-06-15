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
import UIKit

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

    // Corner radius scale, smallest to largest. Pick by the element's role, not
    // by eye — rows are always `row`, cards always `card` — so rounding reads
    // consistently across screens.
    enum Radius {
        static let chip: CGFloat = 8      // album-art thumbs, small chips
        static let control: CGFloat = 13  // icon-badge squares inside cards
        static let row: CGFloat = 18      // list rows, quiet rows, pills' kin
        static let card: CGFloat = 22     // standard cards
        static let hero: CGFloat = 28     // gradient hero cards
        static let small: CGFloat = 12    // legacy alias, keep until migrated
    }

    // The two shadow roles: a soft resting shadow for floating cards (more
    // blur, less opacity) and an accent glow under gradient heroes.
    enum Shadow {
        /// Soft resting shadow for floating cards. More blur, less opacity.
        static let cardRadius: CGFloat = 14
        static let cardY: CGFloat = 6
        static let cardOpacity: Double = 0.10
        /// Accent glow under gradient heroes.
        static let glowRadius: CGFloat = 18
        static let glowY: CGFloat = 10
        static let glowOpacity: Double = 0.25
    }

    enum Brand {
        /// Fallback gradient when no artwork color is available.
        /// TODO match the app icon
        static let gradient = [Color.purple, Color.indigo, Color.cyan, Color.orange]
    }

    enum Surface {
        static let card = adaptiveColor(
            light: UIColor(white: 1.0, alpha: 0.72),
            dark: UIColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 0.86)
        )
        static let cardStroke = adaptiveColor(
            light: UIColor(white: 1.0, alpha: 0.65),
            dark: UIColor(white: 1.0, alpha: 0.1)
        )
        static let subtleTrack = adaptiveColor(
            light: UIColor(white: 0.0, alpha: 0.08),
            dark: UIColor(white: 1.0, alpha: 0.14)
        )

        static let favoritesBackground = [
            adaptiveColor(
                light: UIColor(red: 0.99, green: 0.94, blue: 0.95, alpha: 1),
                dark: UIColor(red: 0.12, green: 0.05, blue: 0.08, alpha: 1)
            ),
            adaptiveColor(
                light: UIColor(red: 0.96, green: 0.93, blue: 0.99, alpha: 1),
                dark: UIColor(red: 0.08, green: 0.07, blue: 0.14, alpha: 1)
            ),
            adaptiveColor(
                light: UIColor(red: 1.0, green: 0.92, blue: 0.9, alpha: 1),
                dark: UIColor(red: 0.18, green: 0.07, blue: 0.06, alpha: 1)
            )
        ]

        static let insightsBackground = [
            adaptiveColor(
                light: UIColor(red: 0.98, green: 0.95, blue: 0.9, alpha: 1),
                dark: UIColor(red: 0.08, green: 0.07, blue: 0.05, alpha: 1)
            ),
            adaptiveColor(
                light: UIColor(red: 0.9, green: 0.98, blue: 0.98, alpha: 1),
                dark: UIColor(red: 0.04, green: 0.1, blue: 0.11, alpha: 1)
            ),
            adaptiveColor(
                light: UIColor(red: 0.99, green: 0.91, blue: 0.86, alpha: 1),
                dark: UIColor(red: 0.13, green: 0.07, blue: 0.05, alpha: 1)
            )
        ]

        /// Teal-into-sunset gradient for the Vault hero card. Index 1 doubles
        /// as the hero's glow tint.
        static let vaultHero = [
            Color(red: 0.11, green: 0.33, blue: 0.42),
            Color(red: 0.9, green: 0.38, blue: 0.26),
            Color(red: 0.98, green: 0.66, blue: 0.22)
        ]

        static let vaultBackground = [
            adaptiveColor(
                light: UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1),
                dark: UIColor(red: 0.06, green: 0.07, blue: 0.06, alpha: 1)
            ),
            adaptiveColor(
                light: UIColor(red: 0.9, green: 0.97, blue: 0.96, alpha: 1),
                dark: UIColor(red: 0.04, green: 0.11, blue: 0.11, alpha: 1)
            ),
            adaptiveColor(
                light: UIColor(red: 0.98, green: 0.9, blue: 0.86, alpha: 1),
                dark: UIColor(red: 0.13, green: 0.07, blue: 0.05, alpha: 1)
            )
        ]
    }

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
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
    /// Screen-defining hero titles (gradient hero cards).
    static func dmHero() -> Font { .system(size: 36, weight: .heavy, design: .rounded) }
    /// Big stat numbers (counts, metrics).
    static func dmStat() -> Font { .system(size: 32, weight: .heavy, design: .rounded) }
    /// Card-level titles (driver cards, tiles).
    static func dmCardTitle() -> Font { .system(size: 20, weight: .heavy, design: .rounded) }
}
