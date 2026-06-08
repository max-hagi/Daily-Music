//
//  CategorySongsSheet.swift
//  Daily Music
//
//  Bottom sheet listing the rated songs that belong to one insight category.
//  Liked songs appear first, then disliked, both reverse-chronological within
//  their group. Each row has inline 👍/👎 buttons to re-rate in place.
//
//  Routing: seed songs (entry.date == .distantPast, from the onboarding
//  StarterPack) write to SeedRatings (UserDefaults); catalog songs write to
//  RatingService (Supabase). After any write, fires onRatingChanged so
//  InsightsViewModel can reload the mirror.
//

import SwiftUI

struct CategorySongsSheet: View {
    let title: String
    let songs: [RatedSong]
    var onRatingChanged: (() -> Void)? = nil

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    // Tracks optimistic overrides; keyed by entry id.
    @State private var localRatings: [UUID: Int?] = [:]

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
        .onAppear {
            localRatings = Dictionary(uniqueKeysWithValues: songs.map { ($0.entry.id, $0.value) })
        }
    }

    // MARK: row

    private func songRow(_ rated: RatedSong) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            AlbumArtView(url: rated.entry.albumArtURL, cornerRadius: 8)
                .frame(width: 44, height: 44)

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
            ratingButtons(rated)
        }
        .padding(.vertical, 4)
    }

    private func ratingButtons(_ rated: RatedSong) -> some View {
        let current = localRatings[rated.entry.id] ?? rated.value
        return HStack(spacing: 6) {
            thumbButton(value: 1,  symbol: "hand.thumbsup.fill",   tint: .green,
                        isActive: current == 1,  rated: rated)
            thumbButton(value: -1, symbol: "hand.thumbsdown.fill", tint: .red,
                        isActive: current == -1, rated: rated)
        }
    }

    private func thumbButton(value: Int, symbol: String, tint: Color,
                              isActive: Bool, rated: RatedSong) -> some View {
        Button {
            Haptics.tap()
            setRating(isActive ? nil : value, for: rated)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isActive ? .white : tint)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isActive ? .clear.tint(tint).interactive() : .clear.interactive(),
            in: .circle
        )
        .accessibilityLabel(value > 0
            ? (isActive ? "Remove like" : "Like")
            : (isActive ? "Remove dislike" : "Dislike"))
    }

    // MARK: write

    private func setRating(_ newValue: Int?, for rated: RatedSong) {
        localRatings[rated.entry.id] = newValue   // optimistic

        Task {
            if rated.entry.date == .distantPast {
                // Onboarding seed song — persisted in UserDefaults, not Supabase.
                var seeds = SeedRatings.load()
                if let newValue {
                    if let i = seeds.firstIndex(where: { $0.entry.id == rated.entry.id }) {
                        seeds[i] = RatedSong(entry: rated.entry, value: newValue)
                    } else {
                        seeds.append(RatedSong(entry: rated.entry, value: newValue))
                    }
                } else {
                    seeds.removeAll { $0.entry.id == rated.entry.id }
                }
                SeedRatings.save(seeds)
            } else {
                // Catalog song — write to Supabase song_ratings.
                try? await env.ratings.setRating(newValue, entryID: rated.entry.id)
            }
            onRatingChanged?()
        }
    }
}
