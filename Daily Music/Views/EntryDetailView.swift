//
//  EntryDetailView.swift
//  Daily Music
//
//  The reusable presentation of a single entry. Today uses the immersive two-zone
//  layout: a full-screen "song" zone (art, title, a compact action cluster,
//  reactions, and one "Open in" button) and a distinct reading-mode "story" zone
//  (the journal) that snaps in on scroll. Vault/Favorites use the standard pushed
//  layout with the same controls. No in-app player — listening is via "Open in".
//

import SwiftUI

struct EntryDetailView: View {
    let entry: DailyEntry
    /// Optional caption shown above the art in standard details / in the Today header.
    var dateLabel: String? = nil
    /// Optional personalized line shown above the art on Today (the shrunk greeting).
    var preArtworkMessage: String? = nil
    var showsNavigationTitle = true
    var albumArtHorizontalPadding: CGFloat = 40
    var usesImmersiveBackdrop = false
    /// False when a parent screen owns the top trailing toolbar item.
    var showsShareToolbarButton = true
    /// True for archival Vault details: reactions show historical counts, read-only.
    var reactionsAreReadOnly = false
    /// Daily taste signals only mutate for today's song; past entries keep the same controls read-only.
    var allowsDailyInteraction = true

    @Environment(AppEnvironment.self) var env
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var palette = ArtworkPalette()
    @State private var showingShare = false
    @State var showingInfo = false
    @State var showingReactions = false
    @State var selectedReactionEmoji: String?
    @State var didDismissAnonymousRatingNudge = false
    // 1 → fully visible on the song zone; fades to 0 as the journal scrolls up.
    @State var journalDockFade: CGFloat = 1
    // One-time tip explaining that 👍/👎 shapes Insights (Today only).
    @AppStorage("hasSeenRatingNudgeLiquidGlass") var hasSeenRatingNudge = false

    var body: some View {
        ZStack {
            Group {
                if usesImmersiveBackdrop {
                    immersiveLayout
                } else {
                    standardLayout
                }
            }
            // Hide content until the artwork resolves (immersive only) so we don't
            // flash an un-themed screen before fading in.
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
        .toolbarBackground(usesImmersiveBackdrop ? .hidden : .automatic, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbar {
            if showsShareToolbarButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingShare = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            ShareCardSheet(entry: entry, artwork: palette.image, accent: palette.accent)
        }
        .sheet(isPresented: $showingInfo) {
            SongInfoSheet(entry: entry)
        }
        .task(id: entry.id) { await palette.load(from: entry.albumArtURL) }
        .task(id: reactionStateLoadID) { await loadSelectedReaction() }
    }

    // MARK: - Standard layout (Vault / Favorites, pushed)

    private var standardLayout: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if let dateLabel {
                    Text(dateLabel.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                AlbumArtView(url: entry.albumArtURL, cornerRadius: Theme.Radius.row)
                    .padding(.horizontal, albumArtHorizontalPadding)
                header
                actionCluster
                OpenInSection(entry: entry, accent: palette.accent)
                Divider().padding(.vertical, 4).padding(.horizontal)
                JournalText(markdown: entry.journalMarkdown)
                    .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
    }

    private var reactionStateLoadID: String {
        "\(entry.id.uuidString)-\(env.session.session?.userID.uuidString ?? "signed-out")-\(reactionsAreReadOnly)"
    }

    private func loadSelectedReaction() async {
        guard allowsEntryReaction, env.session.session?.isGuest != true else {
            selectedReactionEmoji = nil
            return
        }

        selectedReactionEmoji = try? await env.reactions.myReaction(entryID: entry.id)
    }

    // MARK: - Backdrop + headers (shared)

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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: palette.accent)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: palette.isLoaded)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: palette.didFinishLoading)
    }

    private var isWaitingForArtwork: Bool {
        usesImmersiveBackdrop && !palette.didFinishLoading
    }

    var allowsEntryReaction: Bool {
        allowsDailyInteraction && Calendar.current.isDateInToday(entry.date) && !reactionsAreReadOnly
    }

    /// Ratings (👍/👎) are interactive on ANY entry — including past Vault/Favorites
    /// songs — so people build their taste from the back-catalog (those ratings feed
    /// the taste mirror). Reactions stay release-day-only via `allowsEntryReaction`.
    var allowsRating: Bool { allowsDailyInteraction }

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

    private func centeredEntryIdentity(dateLabel: String?) -> some View {
        VStack(spacing: 5) {
            if let dateLabel {
                Text(dateLabel.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            Text(entry.title)
                .font(.dmTitle())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text(entry.artist)
                .font(.dmHeadline())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.lg)
    }

    func entryIdentityWithInlineControls(dateLabel: String?) -> some View {
        VStack(spacing: 5) {
            if let dateLabel {
                Text(dateLabel.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            ZStack(alignment: .top) {
                VStack(spacing: 4) {
                    Text(entry.title)
                        .font(.dmTitle())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(entry.artist)
                        .font(.dmHeadline())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }
                .padding(.horizontal, 78)

                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    compactHeartButton
                        .frame(width: 82, alignment: .leading)

                    Spacer(minLength: 0)

                    compactInfoButton
                        .frame(width: 82, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.md)
    }

    private func todayHeaderWithActions(dateLabel: String?) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let dateLabel {
                Text(dateLabel.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.dmTitle())
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(entry.artist)
                        .font(.dmHeadline())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Theme.Spacing.sm)
                compactActions
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }
}

// The full-screen "spinning disc" placeholder shown (immersive mode only) while
// the artwork downloads, so Today never appears half-themed.
private struct ArtworkLoadingScreen: View {
    let entry: DailyEntry
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                    .fill(.white.opacity(0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
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
        .onAppear { isAnimating = !reduceMotion }
    }
}
