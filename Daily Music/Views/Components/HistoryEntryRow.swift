//
//  HistoryEntryRow.swift
//  Daily Music
//
//  One row in the Insights history section: album art, song + artist + date,
//  and an inline RatingBar so the user can re-rate without leaving the screen.
//

import SwiftUI

struct HistoryEntryRow: View {
    let item: HistoryEntry
    var accent: Color = Theme.Brand.gradient[0]
    var onRatingChanged: (() -> Void)? = nil
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        HStack(spacing: 12) {
            AlbumArtView(url: item.entry.albumArtURL, cornerRadius: Theme.Radius.chip)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.entry.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(item.entry.artist) · \(item.entry.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            RatingBar(
                entry: item.entry,
                accent: accent,
                controlSize: 36,
                symbolSize: 14,
                spacing: 8
            )
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        .onChange(of: env.ratingsStore.rating(for: item.entry.id)) { _, _ in
            onRatingChanged?()
        }
    }
}
