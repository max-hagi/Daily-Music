//
//  BadgeCelebrationCard.swift
//  Daily Music
//
//  Lightweight earn moment: a card that slides up when a badge is newly earned.
//  Tap or "Nice" to dismiss (which marks it seen). One card at a time — if several
//  were earned at once, it shows the first and the rest stay flagged for next open.
//

import SwiftUI

struct BadgeCelebrationCard: View {
    let badge: EarnedBadge
    let accent: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(badge.definition.symbol)
                .font(.system(size: 44))
                .frame(width: 84, height: 84)
                .background(
                    RadialGradient(colors: [badge.definition.tint.opacity(0.6), badge.definition.tint.opacity(0.15)],
                                   center: .topLeading, startRadius: 2, endRadius: 80),
                    in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))

            VStack(spacing: 4) {
                Text("Badge earned")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
                Text(badge.definition.title)
                    .font(.title3.weight(.heavy))
                Text(tierLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Nice") { onDismiss() }
                .buttonStyle(PrimaryActionButtonStyle(tint: accent))
        }
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .padding(Theme.Spacing.lg)
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
    }

    private var tierLine: String {
        if let tier = badge.tier {
            return "Tier \(tier.unlockedTier) · \(badge.value)"
        }
        return badge.definition.subtitle
    }
}
