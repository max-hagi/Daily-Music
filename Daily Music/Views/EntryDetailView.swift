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
    // These four `var … = default` props are the CONFIGURATION knobs that let one
    // view serve three contexts. Today passes its own values (immersive backdrop,
    // no nav title); Vault/Favorites take the defaults. Callers only override what
    // they need.
    /// Optional caption shown above the art (Today passes the date here).
    var dateLabel: String? = nil
    var showsNavigationTitle = true
    var albumArtHorizontalPadding: CGFloat = 40
    var usesImmersiveBackdrop = false

    @Environment(AppEnvironment.self) private var env
    // Each detail view owns its own palette; @State so it survives redraws and the
    // view re-renders as the accent color resolves from the artwork.
    @State private var palette = ArtworkPalette()
    @State private var showingShare = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: usesImmersiveBackdrop ? Theme.Spacing.md : Theme.Spacing.lg) {
                    if let dateLabel, !usesImmersiveBackdrop {
                        Text(dateLabel.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }

                    AlbumArtView(url: entry.albumArtURL, cornerRadius: usesImmersiveBackdrop ? 24 : 16)
                        .padding(.horizontal, albumArtHorizontalPadding)
                        .padding(.top, usesImmersiveBackdrop ? 0 : (dateLabel == nil ? 8 : 0))

                    if usesImmersiveBackdrop {
                        todayHeader(dateLabel: dateLabel)
                    } else {
                        header
                    }
                    PreviewPlayButton(entry: entry, accent: palette.accent)
                    ReactionsBar(entry: entry, accent: palette.accent)
                    streamingActions

                    Divider().padding(.vertical, 4)

                    JournalText(markdown: entry.journalMarkdown)
                        .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            // Hide the real content (opacity 0) until the artwork has resolved, so
            // we don't flash an un-themed screen before fading in.
            .opacity(isWaitingForArtwork ? 0 : 1)

            // Overlaid loading screen, shown only during the immersive-mode wait.
            if isWaitingForArtwork {
                ArtworkLoadingScreen(entry: entry)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .background(backdrop)                          // the artwork-tinted wash (computed below)
        .scrollContentBackground(.hidden)              // let our background show through the ScrollView
        .navigationTitle(showsNavigationTitle ? entry.title : "")
        .navigationBarTitleDisplayMode(.inline)
        // In immersive mode, hide the bar backgrounds so the wash bleeds edge-to-edge.
        .toolbarBackground(usesImmersiveBackdrop ? .hidden : .automatic, for: .navigationBar, .tabBar)
        .toolbar {
            // Two trailing toolbar items: the favorite heart and the share button.
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
        // Load the palette when shown, and RELOAD if we navigate to a different
        // entry (id changes) — the `id:` is what makes that re-trigger happen.
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

    // Only the immersive (Today) presentation waits on artwork; pushed details
    // render immediately.
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

    private func todayHeader(dateLabel: String?) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let dateLabel {
                Text(dateLabel.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            header
        }
        .padding(.horizontal)
    }

    private var streamingActions: some View {
        VStack(spacing: 12) {
            AddToPlaylistButton(entry: entry, accent: palette.accent)

            HStack(spacing: 12) {
                // `Link` opens a URL externally (deep-links into the Apple Music /
                // Spotify apps, or their web pages). Only shown if the URL parsed.
                if let url = entry.appleMusicURL {
                    Link(destination: url) {
                        Label("Apple Music", systemImage: "applelogo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                if let url = entry.spotifyURL {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            SpotifyLogoIcon()
                                .frame(width: 16, height: 16)
                            Text("Spotify")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal)
    }
}

// A hand-drawn Spotify-style glyph (three stacked sound waves in a green circle),
// built from primitive shapes since we can't ship Spotify's trademarked logo asset.
private struct SpotifyLogoIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.12, green: 0.84, blue: 0.38))

            VStack(spacing: 2.2) {
                spotifyWave(width: 9.5, rotation: 7)
                spotifyWave(width: 8, rotation: 6)
                spotifyWave(width: 6.4, rotation: 5)
            }
            .foregroundStyle(.black.opacity(0.82))
        }
    }

    private func spotifyWave(width: CGFloat, rotation: Double) -> some View {
        Capsule()
            .frame(width: width, height: 1.35)
            .rotationEffect(.degrees(rotation))
            .offset(x: 0.8)
    }
}

// The full-screen "spinning disc" placeholder shown (immersive mode only) while
// the artwork downloads, so Today never appears half-themed.
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
        // The shared MusicPlayer is observed: when its state changes, this button
        // re-renders to show play/pause/spinner. `isActive` = is THIS entry loaded?
        let player = env.musicPlayer
        let isActive = player.nowPlayingEntryID == entry.id

        Button {
            Task { await player.toggle(entry) }
        } label: {
            HStack(spacing: 10) {
                // Show a spinner only while THIS entry is buffering, otherwise the
                // play/pause icon depending on whether it's currently playing.
                if isActive && player.state == .buffering {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: player.isPlaying(entry) ? "pause.fill" : "play.fill")
                }
                Text(player.isPlaying(entry) ? "Playing preview" : "Play 30-sec preview")
            }
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: accent))   // tinted by the artwork accent
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.4), value: accent)   // smoothly cross-fade the tint
    }
}

// MARK: - Add to Daily Playlist

private struct AddToPlaylistButton: View {
    let entry: DailyEntry
    var accent: Color
    @Environment(AppEnvironment.self) private var env

    // A tiny state machine: the button's label/icon/enabled-ness all derive from
    // this one @State enum. Modeling UI states as an enum (vs scattered bools)
    // keeps "impossible" combinations from happening.
    private enum Status { case idle, working, added, failed }
    @State private var status: Status = .idle

    var body: some View {
        Button {
            Task { await add() }
        } label: {
            Label(title, systemImage: icon)   // both `title` and `icon` switch on `status`
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .disabled(status == .working || status == .added)   // no re-tapping mid-add / once added
        .tint(status == .added ? .green : accent)
    }

    // Computed label text for each state.
    private var title: String {
        switch status {
        case .idle: "Add to Library"
        case .working: "Adding…"
        case .added: "Added to Library"
        case .failed: "Couldn't add — tap to retry"
        }
    }

    // Computed icon for each state (`default` covers idle + working).
    private var icon: String {
        switch status {
        case .added: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle"
        default: "text.badge.plus"
        }
    }

    // Drive the state machine through working → added/failed around the async call.
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
        // Reads the SHARED FavoritesStore — so the heart here stays in sync with
        // the same entry shown anywhere else, and the optimistic toggle updates
        // every screen at once.
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
