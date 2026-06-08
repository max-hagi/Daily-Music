//
//  CategorySongsSheet.swift
//  Daily Music
//
//  Bottom sheet listing the rated songs that belong to one insight category.
//  Liked songs appear first, then disliked, both reverse-chronological within
//  their group. Presented from StandoutDetailView when any row is tapped.
//

import SwiftUI

struct CategorySongsSheet: View {
    let title: String
    let songs: [RatedSong]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty {
                    ContentUnavailableView(
                        "No songs yet",
                        systemImage: "music.note.list",
                        description: Text("Rate more songs in this category to see them here.")
                    )
                } else {
                    List(songs, id: \.entry.id) { rated in
                        songRow(rated)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.regularMaterial)
        .presentationCornerRadius(34)
        .presentationDragIndicator(.visible)
    }

    private func songRow(_ rated: RatedSong) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            AsyncImage(url: rated.entry.albumArtURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(rated.entry.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(rated.entry.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(rated.value > 0 ? "👍" : "👎")
                .font(.title3)
        }
        .padding(.vertical, 4)
    }
}
