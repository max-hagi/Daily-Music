//
//  EntryDetailView.swift
//  Daily Music
//
//  The reusable presentation of a single entry — album art, preview playback,
//  the journal, favorite heart, and the streaming actions. Today shows it inline
//  as the hero; Vault and Favorites push it onto a navigation stack. One view,
//  three uses, so the experience is identical everywhere.
//

import SwiftUI

struct EntryDetailView: View {
    let entry: DailyEntry
    /// Optional caption shown above the art (Today passes the date here).
    var dateLabel: String? = nil

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let dateLabel {
                    Text(dateLabel.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }

                AlbumArtView(url: entry.albumArtURL)
                    .padding(.horizontal, 40)
                    .padding(.top, dateLabel == nil ? 8 : 0)

                header
                PreviewPlayButton(entry: entry)
                streamingActions

                Divider().padding(.vertical, 4)

                JournalText(markdown: entry.journalMarkdown)
                    .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteButton(entry: entry)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(entry.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(entry.artist)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var streamingActions: some View {
        VStack(spacing: 12) {
            AddToPlaylistButton(entry: entry)

            HStack(spacing: 12) {
                if let url = entry.appleMusicURL {
                    Link(destination: url) {
                        Label("Apple Music", systemImage: "applelogo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                if let url = entry.spotifyURL {
                    Link(destination: url) {
                        Label("Spotify", systemImage: "music.note")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview playback button

private struct PreviewPlayButton: View {
    let entry: DailyEntry
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let player = env.musicPlayer
        let isActive = player.nowPlayingEntryID == entry.id

        Button {
            Task { await player.toggle(entry) }
        } label: {
            HStack(spacing: 10) {
                if isActive && player.state == .buffering {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: player.isPlaying(entry) ? "pause.fill" : "play.fill")
                }
                Text(player.isPlaying(entry) ? "Playing preview" : "Play 30-sec preview")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
    }
}

// MARK: - Add to Daily Playlist

private struct AddToPlaylistButton: View {
    let entry: DailyEntry
    @Environment(AppEnvironment.self) private var env

    private enum Status { case idle, working, added, failed }
    @State private var status: Status = .idle

    var body: some View {
        Button {
            Task { await add() }
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .disabled(status == .working || status == .added)
        .tint(status == .added ? .green : .accentColor)
    }

    private var title: String {
        switch status {
        case .idle: "Add to my Daily Playlist"
        case .working: "Adding…"
        case .added: "Added to Daily Playlist"
        case .failed: "Couldn't add — tap to retry"
        }
    }

    private var icon: String {
        switch status {
        case .added: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle"
        default: "text.badge.plus"
        }
    }

    private func add() async {
        status = .working
        do {
            try await env.musicPlayer.addToDailyPlaylist(entry)
            status = .added
        } catch {
            status = .failed
        }
    }
}

// MARK: - Favorite heart

private struct FavoriteButton: View {
    let entry: DailyEntry
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let store = env.favoritesStore
        let isFav = store.isFavorite(entry)

        Button {
            Task { await store.toggle(entry) }
        } label: {
            Image(systemName: isFav ? "heart.fill" : "heart")
                .foregroundStyle(isFav ? .red : .secondary)
        }
        .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
    }
}
