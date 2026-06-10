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
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
    }
}

struct GlassCardModifier<S: Shape>: ViewModifier {
    var tint: Color?
    var shape: S

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.tint(tint), in: shape)
            .overlay {
                shape.stroke(.white.opacity(0.22), lineWidth: 1)
            }
    }
}

struct GlassPillModifier: ViewModifier {
    var tint: Color?

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.tint(tint), in: .capsule)
            .overlay {
                Capsule().stroke(.white.opacity(0.2), lineWidth: 1)
            }
    }
}

struct GlassIconButtonModifier: ViewModifier {
    var tint: Color
    var size: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.headline.weight(.bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .glassEffect(.regular.tint(tint.opacity(0.14)).interactive(), in: .circle)
            .contentShape(Circle())
    }
}

// Extending View so the modifier reads fluently as `someView.cardStyle()`.
// Returning `some View` is an "opaque type": the caller knows it's a View but not
// the exact concrete type (which would be an unreadable nested generic).
extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }

    func glassCardStyle<S: Shape>(
        tint: Color? = nil,
        in shape: S
    ) -> some View {
        modifier(GlassCardModifier(tint: tint, shape: shape))
    }

    func glassCardStyle(tint: Color? = nil) -> some View {
        glassCardStyle(
            tint: tint,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
    }

    func glassPillStyle(tint: Color? = nil) -> some View {
        modifier(GlassPillModifier(tint: tint))
    }

    func glassIconButtonStyle(tint: Color = Theme.Brand.gradient[0], size: CGFloat = 48) -> some View {
        modifier(GlassIconButtonModifier(tint: tint, size: size))
    }
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

// MARK: - Glass card

/// The onboarding glass language: frosted card with a hairline highlight stroke
/// and a soft drop shadow, for content floating on the bloom backdrop.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
