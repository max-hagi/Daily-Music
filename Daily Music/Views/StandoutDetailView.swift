//
//  StandoutDetailView.swift
//  Daily Music
//
//  The "tap into a standout" detail sheet. Editorial, not a chart: the standout
//  category is a big color statement up top, then the other categories are clean
//  rows whose background is softly tinted by like-rate (a wash, never a bar).
//

import SwiftUI

/// One category row inside a dimension detail (e.g. a single mood).
struct StandoutRow: Identifiable, Equatable {
    let id: String
    let name: String
    let symbol: String?
    let likes: Int
    let total: Int
    let songs: [RatedSong]                              // ← new
    var likeRate: Double { total > 0 ? Double(likes) / Double(total) : 0 }
}

/// Everything the detail sheet needs for one tapped standout. Identifiable so it
/// can drive `.sheet(item:)`.
struct StandoutDetail: Identifiable, Equatable {
    let id: String            // dimension title, e.g. "Mood"
    let title: String
    let accent: Color
    let featuredName: String
    let featuredSymbol: String
    let featuredLine: String
    let featuredSongs: [RatedSong]                      // ← new
    let rows: [StandoutRow]   // the OTHER categories (featured excluded)
    let standoutID: String?   // the over-index row, badged
    let skipID: String?       // the "you pass on these" row
}

/// Drives the per-category song list sheet from StandoutDetailView.
struct CategoryDrill: Identifiable {
    let id: String          // namespaced: "featured:<name>" or "row:<name>" to avoid collision
    let name: String
    let songs: [RatedSong]
}

struct StandoutDetailView: View {
    let detail: StandoutDetail
    @Environment(\.dismiss) private var dismiss
    @State private var drill: CategoryDrill?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Button {
                    drill = CategoryDrill(id: "featured:\(detail.featuredName)",
                                         name: detail.featuredName,
                                         songs: detail.featuredSongs)
                } label: {
                    featured
                }
                .buttonStyle(.plain)
                if !detail.rows.isEmpty {
                    Text("The rest of your \(detail.title.lowercased())")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    VStack(spacing: 10) {
                        ForEach(detail.rows) { row in
                            Button {
                                drill = CategoryDrill(id: "row:\(row.id)",
                                                     name: row.name,
                                                     songs: row.songs)
                            } label: {
                                rowView(row)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .presentationDetents([.large])
        .presentationBackground(.regularMaterial)
        .presentationCornerRadius(34)
        .presentationDragIndicator(.visible)
        .sheet(item: $drill) { d in
            CategorySongsSheet(title: d.name, songs: d.songs)
        }
    }

    // MARK: featured statement

    private var featured: some View {
        ZStack(alignment: .bottomTrailing) {
            // Large faint glyph behind the text for depth.
            Image(systemName: detail.featuredSymbol)
                .font(.system(size: 150, weight: .bold))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 26, y: 18)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(detail.title.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.8))
                Image(systemName: detail.featuredSymbol)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
                Text(detail.featuredName)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail.featuredLine)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.lg)
        .background(
            LinearGradient(colors: [detail.accent, detail.accent.opacity(0.72)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: detail.accent.opacity(0.3), radius: 16, y: 8)
    }

    // MARK: ranked rows (wash, not a bar)

    private func rowView(_ row: StandoutRow) -> some View {
        let isStandout = row.id == detail.standoutID
        let isSkip = row.id == detail.skipID
        return HStack(spacing: Theme.Spacing.md) {
            if let s = row.symbol {
                Image(systemName: s)
                    .font(.subheadline)
                    .foregroundStyle(detail.accent)
                    .frame(width: 22)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name).font(.subheadline.weight(.semibold))
                if isStandout {
                    Text("stands out").font(.caption2.weight(.bold)).foregroundStyle(detail.accent)
                } else if isSkip {
                    Text("you pass on these").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(row.likes) of \(row.total)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(Int(row.likeRate * 100))%")
                .font(.subheadline.weight(.heavy))
                .monospacedDigit()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 14)
        .background(
            // Tint scales with like-rate: a soft wash, never a bar/axis.
            detail.accent.opacity(0.06 + 0.20 * row.likeRate),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isStandout ? detail.accent.opacity(0.6) : .clear, lineWidth: 1.5)
        }
    }
}
