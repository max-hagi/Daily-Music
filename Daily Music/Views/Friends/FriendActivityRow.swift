//
//  FriendActivityRow.swift
//  Daily Music
//
//  One row in the Friends activity feed: "{name} loved/passed on {song}" with
//  the cover and a verdict bubble, in the same visual language as the Today
//  bubbles so the two surfaces feel like one feature.
//

import SwiftUI

struct FriendActivityRow: View {
    let item: FriendActivityItem
    var onOpenEntry: (DailyEntry) -> Void = { _ in }

    var body: some View {
        Button { onOpenEntry(item.entry) } label: {
            HStack(spacing: Theme.Spacing.sm) {
                InitialsAvatar(name: item.friend.displayName, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(item.entry.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Theme.Spacing.sm)

                Text(item.verdict.emoji).font(.body)
                AlbumArtView(url: item.entry.albumArtURL, cornerRadius: Theme.Radius.chip)
                    .frame(width: 40, height: 40)
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                    .stroke(Theme.Surface.cardStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.friend.displayName ?? "A friend") \(item.verdict.feedVerb) \(item.entry.title)")
    }

    private var headline: String {
        let name = item.friend.displayName ?? "A friend"
        return "\(name) \(item.verdict.feedVerb) this"
    }
}
