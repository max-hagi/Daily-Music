//
//  MonthShelvesView.swift
//  Daily Music
//
//  The Crate browse (Vault redesign): a vertical scroll of month "shelves". Each
//  month is a shop-style divider header + a horizontally scrollable row of that
//  month's sleeves (newest-first). Vertical scroll travels back through time;
//  horizontal scroll digs a month — so going far back is a fling, not a marathon.
//  State is encoded entirely by each sleeve's treatment (SleeveView).
//

import SwiftUI

struct MonthShelvesView: View {
    let entries: [DailyEntry]            // newest first
    let missingVariant: MissingSleeveVariant
    let secondhandVariant: SecondhandVariant
    let status: (DailyEntry) -> ListenStatus
    let onSelect: (DailyEntry) -> Void
    let namespace: Namespace.ID

    @Environment(AppEnvironment.self) private var env

    private var sections: [CrateLayout.MonthSection] {
        CrateLayout.monthSections(for: entries)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl, pinnedViews: []) {
            ForEach(sections) { section in
                shelf(section)
            }
        }
    }

    private func shelf(_ section: CrateLayout.MonthSection) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Rectangle()
                    .fill(.secondary.opacity(0.25))
                    .frame(height: 1)
            }
            .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    ForEach(section.entries) { entry in
                        sleeve(entry)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func sleeve(_ entry: DailyEntry) -> some View {
        Button { onSelect(entry) } label: {
            VStack(spacing: 6) {
                SleeveView(entry: entry,
                           status: status(entry),
                           size: 132,
                           missingVariant: missingVariant,
                           secondhandVariant: secondhandVariant)
                Text(entry.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 132)
            }
        }
        .buttonStyle(PressableCardButtonStyle())
        .matchedTransitionSource(id: entry.id, in: namespace)
        .contextMenu {
            Button { onSelect(entry) } label: {
                Label("Open Entry", systemImage: "arrow.up.forward.app")
            }
            let isFavorite = env.favoritesStore.isFavorite(entry)
            Button(role: isFavorite ? .destructive : nil) {
                Task { await env.favoritesStore.toggle(entry) }
            } label: {
                Label(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                      systemImage: isFavorite ? "heart.slash.fill" : "heart.fill")
            }
        }
    }
}

extension View {
    /// Snap-to-sleeve paging when enabled; a plain scroll otherwise. Retained for
    /// the debug variant gallery's `CrateFeel` preview (production uses shelves).
    @ViewBuilder
    func crateSnapPaging(_ enabled: Bool) -> some View {
        if enabled { scrollTargetBehavior(.viewAligned) }
        else { self }
    }
}
