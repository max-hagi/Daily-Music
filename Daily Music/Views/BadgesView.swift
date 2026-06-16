//
//  BadgesView.swift
//  Daily Music
//
//  The full badge grid: a tiered section (with progress) and a moments section
//  (earned tiles + "?" mysteries for the unearned). Tinted to the active accent.
//

import SwiftUI

struct BadgesView: View {
    let badges: [EarnedBadge]
    let accent: Color

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    private var tiered: [EarnedBadge] { badges.filter { $0.tier != nil } }
    private var moments: [EarnedBadge] { badges.filter { $0.tier == nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                section(title: "Tiered", items: tiered) { BadgeTile(badge: $0, accent: accent) }
                section(title: "Moments", items: moments) { MomentTile(badge: $0, accent: accent) }
            }
            .padding()
        }
        .navigationTitle("Badges")
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    @ViewBuilder
    private func section(title: String, items: [EarnedBadge],
                         @ViewBuilder tile: @escaping (EarnedBadge) -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { tile($0) }
            }
        }
    }
}

private struct BadgeDisc: View {
    let symbol: String
    let tint: Color
    var dimmed: Bool = false

    var body: some View {
        Text(symbol)
            .font(.system(size: 26))
            .frame(width: 58, height: 58)
            .background(
                RadialGradient(colors: [tint.opacity(0.55), tint.opacity(0.12)],
                               center: .topLeading, startRadius: 2, endRadius: 56),
                in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
            .opacity(dimmed ? 0.45 : 1)
            .saturation(dimmed ? 0 : 1)
    }
}

private struct BadgeTile: View {
    let badge: EarnedBadge
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            BadgeDisc(symbol: badge.definition.symbol, tint: badge.definition.tint,
                      dimmed: !badge.isEarned)
            Text(badge.definition.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let tier = badge.tier {
                if tier.isMaxed {
                    Text("MAX").font(.caption2.weight(.heavy)).foregroundStyle(accent)
                } else {
                    ProgressView(value: tier.progressToNext)
                        .tint(accent)
                    Text("\(badge.value) · next \(tier.nextThreshold ?? 0)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

private struct MomentTile: View {
    let badge: EarnedBadge
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            if badge.isEarned {
                BadgeDisc(symbol: badge.definition.symbol, tint: badge.definition.tint)
                Text(badge.definition.title)
                    .font(.caption.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(badge.definition.subtitle)
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).lineLimit(2)
            } else {
                BadgeDisc(symbol: "?", tint: .gray, dimmed: true)
                Text("Mystery").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text("Locked moment").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        BadgesView(badges: BadgeCatalog.all.map { def in
            let tier: TierProgress? = {
                if case .tiered(let t) = def.kind { return BadgeMath.tierProgress(value: 7, thresholds: t) }
                return nil
            }()
            return EarnedBadge(definition: def, value: 7,
                               isEarned: (tier?.isEarned ?? false) || def.id == "firstPress",
                               tier: tier)
        }, accent: .purple)
    }
}
