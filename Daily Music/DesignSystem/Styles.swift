//
//  Styles.swift
//  Daily Music
//
//  Reusable, app-wide component styles built on the Theme tokens: a card
//  background and a bold primary action button that can be tinted by the
//  current artwork accent.
//

import SwiftUI

// MARK: - Card

// A ViewModifier is a reusable bundle of modifiers. Instead of repeating
// `.padding(...).background(...)` on every card, we package it once here and
// apply it with the `.cardStyle()` helper below. `body(content:)` receives the
// view being modified (`content`) and returns the decorated version.
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.lg)
            .background(
                Theme.Surface.card,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.Surface.cardStroke, lineWidth: 1)
            }
    }
}

// Extending View so the modifier reads fluently as `someView.cardStyle()`.
// Returning `some View` is an "opaque type": the caller knows it's a View but not
// the exact concrete type (which would be an unreadable nested generic).
extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}

// MARK: - Primary action button

// A ButtonStyle controls how a Button LOOKS and reacts to presses, while the
// Button itself owns the tap action. `tint` has a default so most call sites can
// omit it; screens pass the artwork accent color to theme the button per-song.
struct PrimaryActionButtonStyle: ButtonStyle {
    var tint: Color = Theme.Brand.gradient[0]

    // `configuration.label` is the button's content; `configuration.isPressed`
    // is true while the finger is down — we use it to shrink the button slightly.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dmHeadline())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)          // stretch full width
            .padding(.vertical, 16)
            .background(
                tint.gradient,                    // `.gradient` auto-derives a subtle gradient from one color
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
            .shadow(color: tint.opacity(0.4), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            // `.animation(value:)` animates whenever `isPressed` changes, giving the
            // springy press feedback without us managing any state by hand.
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

// MARK: - Pressable card / row

// A subtle press response for tappable CARDS and ROWS that don't already use
// Liquid Glass `.interactive()` (which brings its own touch feedback) or a List's
// native row highlight. Scales + dims slightly while the finger is down.
struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
