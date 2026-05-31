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

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.lg)
            .background(
                .quaternary.opacity(0.5),
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}

// MARK: - Primary action button

struct PrimaryActionButtonStyle: ButtonStyle {
    var tint: Color = Theme.Brand.gradient[0]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dmHeadline())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                tint.gradient,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
            .shadow(color: tint.opacity(0.4), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}
