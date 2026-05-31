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
    var showsNavigationTitle = true
    var albumArtHorizontalPadding: CGFloat = 40
    var usesImmersiveBackdrop = false

    @Environment(AppEnvironment.self) private var env
    @State private var palette = ArtworkPalette()
    @State private var showingShare = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if let dateLabel {
                        Text(dateLabel.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }

                    AlbumArtView(url: entry.albumArtURL)
                        .padding(.horizontal, albumArtHorizontalPadding)
                        .padding(.top, dateLabel == nil ? 8 : 0)

                    header
                    PreviewPlayButton(entry: entry, accent: palette.accent)
                    ReactionsBar(entry: entry, accent: palette.accent)
                    streamingActions

                    Divider().padding(.vertical, 4)

                    JournalText(markdown: entry.journalMarkdown)
                        .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .opacity(isWaitingForArtwork ? 0 : 1)

            if isWaitingForArtwork {
                ArtworkLoadingScreen(entry: entry)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .background(backdrop)
        .scrollContentBackground(.hidden)
        .navigationTitle(showsNavigationTitle ? entry.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(usesImmersiveBackdrop ? .hidden : .automatic, for: .navigationBar, .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteButton(entry: entry)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
        .sheet(isPresented: $showingShare) {
            ShareCardSheet(entry: entry, artwork: palette.image, accent: palette.accent)
        }
        .task(id: entry.id) { await palette.load(from: entry.albumArtURL) }
    }

    /// Artwork-driven wash that can either stay subtle for pushed details or
    /// bleed behind the bars for Today's hero presentation.
    private var backdrop: some View {
        ZStack {
            if usesImmersiveBackdrop, let image = palette.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 48)
                    .saturation(1.25)
                    .opacity(0.46)
                    .ignoresSafeArea()
            }

            LinearGradient(
                colors: usesImmersiveBackdrop ? immersiveBackdropColors : standardBackdropColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.6), value: palette.accent)
        .animation(.easeInOut(duration: 0.6), value: palette.isLoaded)
        .animation(.easeInOut(duration: 0.35), value: palette.didFinishLoading)
    }

    private var isWaitingForArtwork: Bool {
        usesImmersiveBackdrop && !palette.didFinishLoading
    }

    private var standardBackdropColors: [Color] {
        [palette.accent.opacity(0.45), palette.accent.opacity(0)]
    }

    private var immersiveBackdropColors: [Color] {
        [
            palette.accent.opacity(0.62),
            palette.accent.opacity(0.28),
            Color(.systemBackground).opacity(0.9),
            palette.accent.opacity(0.18)
        ]
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(entry.title)
                .font(.dmTitle())
                .multilineTextAlignment(.center)
            Text(entry.artist)
                .font(.dmHeadline())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var streamingActions: some View {
        VStack(spacing: 12) {
            AddToPlaylistButton(entry: entry, accent: palette.accent)

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

private struct ArtworkLoadingScreen: View {
    let entry: DailyEntry
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.28), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 26, y: 14)

                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "opticaldisc.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.94))
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 2.8).repeatForever(autoreverses: false), value: isAnimating)

                    MusicLoadingView(title: nil, tint: .white)
                        .scaleEffect(0.72)
                        .frame(height: 36)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 42)

            VStack(spacing: Theme.Spacing.xs) {
                Text(entry.title)
                    .font(.dmTitle())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(entry.artist)
                    .font(.dmHeadline())
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.08, blue: 0.18),
                    Color(red: 0.22, green: 0.16, blue: 0.46),
                    Color(red: 0.02, green: 0.42, blue: 0.5)
                ],
                startPoint: isAnimating ? .bottomLeading : .topLeading,
                endPoint: isAnimating ? .topTrailing : .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: isAnimating)
        }
        .onAppear { isAnimating = true }
    }
}

// MARK: - Preview playback button

private struct PreviewPlayButton: View {
    let entry: DailyEntry
    var accent: Color
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
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: accent))
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.4), value: accent)
    }
}

// MARK: - Add to Daily Playlist

private struct AddToPlaylistButton: View {
    let entry: DailyEntry
    var accent: Color
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
        .tint(status == .added ? .green : accent)
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
