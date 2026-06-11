//
//  HeroCard.swift
//  Daily Music
//
//  The gradient-stage hero scaffold: icon badge top-left, eyebrow top-right,
//  big rounded title, subtitle, and an optional trailing content slot below.
//  One component so every screen-opening hero shares the same size hierarchy —
//  reserve it for screens where the hero IS the content.
//

import SwiftUI

struct HeroCard<Content: View>: View {
    let icon: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
                Spacer()
                Text(eyebrow)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.72))
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(.dmHero())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(Theme.Spacing.lg)
        .background(
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
        )
        .heroGlow(gradient[gradient.count > 1 ? 1 : 0])
    }
}
