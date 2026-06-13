//
//  CollectionCountCard.swift
//  Daily Music
//
//  The Vault's quiet hero: the personal collection count. Deliberately modest —
//  the proud showcase is the Favourites wall, not here.
//

import SwiftUI

struct CollectionCountCard: View {
    let total: Int
    let thisMonth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Your collection")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(total)")
                    .font(.dmHero())
                    .foregroundStyle(.teal)
                    .contentTransition(.numericText())
                Text("records · \(thisMonth) this month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .glassCardStyle(tint: .teal.opacity(0.08))
    }
}
