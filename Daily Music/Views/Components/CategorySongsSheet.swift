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

enum CategorySongsDisclosure {
    static let previewLimit = 4

    static func startsCollapsed(songCount: Int) -> Bool {
        songCount > previewLimit
    }

    static func visibleCount(songCount: Int, isExpanded: Bool) -> Int {
        isExpanded ? songCount : min(songCount, previewLimit)
    }
}

struct CategorySongsSheet: View {
    let title: String
    let songs: [RatedSong]
    var onRatingChanged: (() -> Void)? = nil

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    // Only used for seed songs (UserDefaults path). Catalog songs read directly
    // from env.ratingsStore, which is @Observable and updates every row atomically.
    @State private var seedLocalRatings: [UUID: Int?] = [:]
    @State private var isExpanded = false

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
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            summaryCard
                            Text(isExpanded ? "All songs" : "Key songs")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 2)

                            VStack(spacing: 10) {
                                ForEach(visibleSongs, id: \.entry.id) { rated in
                                    songRow(rated)
                                }
                            }

                            if CategorySongsDisclosure.startsCollapsed(songCount: songs.count) {
                                Button {
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                        isExpanded.toggle()
                                    }
                                    Haptics.tap()
                                } label: {
                                    Label(isExpanded ? "Show fewer" : "Show all \(songs.count) songs",
                                          systemImage: isExpanded ? "chevron.up" : "music.note.list")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.primary.opacity(0.12))
                                .foregroundStyle(.primary)
                                .padding(.top, 2)
                            }
                        }
                        .padding(Theme.Spacing.lg)
                    }
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
            // Seed-song optimistic overrides seeded from initial list value.
            let seedSongs = songs.filter { $0.entry.date == .distantPast }
            seedLocalRatings = Dictionary(uniqueKeysWithValues: seedSongs.map { ($0.entry.id, $0.value) })
            isExpanded = !CategorySongsDisclosure.startsCollapsed(songCount: songs.count)
        }
    }

    private var visibleSongs: [RatedSong] {
        Array(songs.prefix(CategorySongsDisclosure.visibleCount(
            songCount: songs.count,
            isExpanded: isExpanded
        )))
    }

    private var likedCount: Int { songs.filter { currentRating(for: $0) == 1 }.count }
    private var dislikedCount: Int { songs.filter { currentRating(for: $0) == -1 }.count }

    private var summaryCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "music.note.list")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 42, height: 42)
                .glassEffect(.regular, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("\(songs.count) contributing song\(songs.count == 1 ? "" : "s")")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.primary)
                Text("\(likedCount) liked · \(dislikedCount) passed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: row

    private func songRow(_ rated: RatedSong) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            AlbumArtView(url: rated.entry.albumArtURL, cornerRadius: Theme.Radius.chip)
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
        .padding(Theme.Spacing.sm)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
    }

    private func ratingButtons(_ rated: RatedSong) -> some View {
        // Seed songs: read from local optimistic override (UserDefaults path).
        // Catalog songs: read from the shared RatingsStore so updates propagate
        // app-wide the instant they're written anywhere.
        let current = currentRating(for: rated)
        return HStack(spacing: 6) {
            thumbButton(value: 1,  symbol: "hand.thumbsup.fill",   tint: .green,
                        isActive: current == 1,  rated: rated)
            thumbButton(value: -1, symbol: "hand.thumbsdown.fill", tint: .red,
                        isActive: current == -1, rated: rated)
        }
    }

    private func currentRating(for rated: RatedSong) -> Int? {
        if rated.entry.date == .distantPast {
            seedLocalRatings[rated.entry.id] ?? rated.value
        } else {
            env.ratingsStore.rating(for: rated.entry.id) ?? rated.value
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
        Task {
            if rated.entry.date == .distantPast {
                // Onboarding seed song — persisted in UserDefaults, not Supabase.
                // Optimistic-update the local override first so the row snaps.
                seedLocalRatings[rated.entry.id] = newValue
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
                // Catalog song — delegate entirely to RatingsStore (optimistic + Supabase).
                // Every other RatingBar in the app sees the change immediately via the store.
                await env.ratingsStore.setRating(newValue, entryID: rated.entry.id)
            }
            onRatingChanged?()
        }
    }
}
