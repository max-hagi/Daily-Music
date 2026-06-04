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

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var palette = ArtworkPalette()
    @State private var showingShare = false
    @State private var showingInfo = false
    @State private var showingReactions = false
    @State private var didDismissAnonymousRatingNudge = false
    /// All-users favourite total for this entry (nil until loaded).
    @State private var favouriteCount: Int?
    // One-time tip explaining that 👍/👎 shapes Insights (Today only).
    @AppStorage("hasSeenRatingNudgeLiquidGlass") private var hasSeenRatingNudge = false

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
        .task(id: entry.id) { await loadFavouriteCount() }
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
                AlbumArtView(url: entry.albumArtURL, cornerRadius: 16)
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

    // MARK: - Immersive layout (Today) — two zones with snap

    private var immersiveLayout: some View {
        ScrollView {
            VStack(spacing: 0) {
                songZone
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical)   // ≈ one viewport → snap target
                journalZone
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private var songZone: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let preArtworkMessage {
                Text(preArtworkMessage)
                    .font(.caption.weight(.semibold))   // shrunk greeting
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, Theme.Spacing.sm)
            }
            AlbumArtView(url: entry.albumArtURL, cornerRadius: 24)
                .padding(.horizontal, albumArtHorizontalPadding)
            todayHeaderWithActions(dateLabel: dateLabel)
            ratingExperience
            openInSectionWithRatingNudge
            Spacer(minLength: 0)
            Label("the story", systemImage: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.bottom, Theme.Spacing.xs)
        }
        // Clamp accessibility text sizes so the one-screen song zone stays intact;
        // the journal (reading) text below is left fully scalable.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private var ratingExperience: some View {
        VStack(spacing: 0) {
            primaryRatingControl
        }
        .frame(maxWidth: 380)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var openInSectionWithRatingNudge: some View {
        ZStack {
            OpenInSection(entry: entry, accent: palette.accent)
                .opacity(shouldShowRatingNudge ? 0.22 : 1)
                .allowsHitTesting(!shouldShowRatingNudge)

            if shouldShowRatingNudge {
                ratingNudge
                    .padding(.horizontal)
                    .zIndex(1)
            }
        }
        .padding(.top, Theme.Spacing.lg)
        .animation(ratingNudgeAnimation, value: shouldShowRatingNudge)
    }

    private var shouldShowRatingNudge: Bool {
        isAnonymousUser ? !didDismissAnonymousRatingNudge : !hasSeenRatingNudge
    }

    private var isAnonymousUser: Bool {
        env.session.session?.isGuest == true
    }

    private var ratingNudgeAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78)
    }

    private func dismissRatingNudge() {
        withAnimation(ratingNudgeAnimation) {
            if isAnonymousUser {
                didDismissAnonymousRatingNudge = true
            } else {
                hasSeenRatingNudge = true
            }
        }
    }

    /// One-time tip paired with the rating control so the thumbs read as an Insights input.
    private var ratingNudge: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .glassEffect(.regular, in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tune your Insights")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.primary)
                Text("Use 👍 or 👎 to shape your taste stats.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Spacing.xs)

            Button {
                dismissRatingNudge()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .background(.regularMaterial, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss tip")
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.94)).combined(with: .move(edge: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .move(edge: .bottom))
            )
        )
        .accessibilityElement(children: .combine)
    }

    private var journalZone: some View {
        let shouldReduceMotion = reduceMotion

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            Text(entry.title).font(.dmTitle())
            JournalText(markdown: entry.journalMarkdown)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, 60)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))   // opaque reading surface rises over the art
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .scrollTransition { content, phase in
            content
                .opacity(shouldReduceMotion || phase.isIdentity ? 1 : 0)
                .offset(y: shouldReduceMotion ? 0 : (phase.isIdentity ? 0 : 40))
        }
    }

    // MARK: - Favourite count (social proof)

    @ViewBuilder private var favouriteCountLabel: some View {
        if let favouriteCount {
            Text(Self.compactCount(favouriteCount))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())   // animate the number ticking
                .accessibilityLabel("\(favouriteCount) people favourited this song")
        }
    }

    private func loadFavouriteCount() async {
        favouriteCount = try? await env.favorites.count(entryID: entry.id)
    }

    /// Toggle the heart, nudging the visible count instantly, then reconciling with
    /// the server total so it stays honest.
    private func toggleFavourite() {
        let willFavorite = !env.favoritesStore.isFavorite(entry)
        if let c = favouriteCount {
            favouriteCount = max(0, c + (willFavorite ? 1 : -1))
        }
        Task {
            await env.favoritesStore.toggle(entry)
            await loadFavouriteCount()
        }
    }

    /// 1204 → "1.2k"; smaller numbers stay exact.
    private static func compactCount(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    // MARK: - Action cluster (favorite + rating + info)

    private var actionCluster: some View {
        HStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 5) {
                heartButton
                favouriteCountLabel
            }
            reactionButton(controlSize: 52, symbolSize: 20)
            Spacer(minLength: Theme.Spacing.sm)
            RatingBar(entry: entry, accent: palette.accent)
            Spacer(minLength: Theme.Spacing.sm)
            infoButton
        }
        .padding(.horizontal)
    }

    private var primaryRatingControl: some View {
        RatingBar(
            entry: entry,
            accent: palette.accent,
            controlSize: 72,
            symbolSize: 28,
            spacing: Theme.Spacing.md
        )
    }

    private var compactActions: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                compactHeartButton
                favouriteCountLabel
            }
            reactionButton(controlSize: 46, symbolSize: 18)
            compactInfoButton
        }
    }

    private var heartButton: some View {
        let store = env.favoritesStore
        let isFav = store.isFavorite(entry)
        return Button {
            toggleFavourite()
        } label: {
            Image(systemName: isFav ? "heart.fill" : "heart")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isFav ? .red : palette.accent)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
    }

    private var infoButton: some View {
        Button { showingInfo = true } label: {
            Image(systemName: "info")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(palette.accent)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Song info")
    }

    private func reactionButton(controlSize: CGFloat, symbolSize: CGFloat) -> some View {
        Button {
            showingReactions = true
        } label: {
            Image(systemName: "face.smiling")
                .font(.system(size: symbolSize, weight: .bold))
                .foregroundStyle(palette.accent)
                .frame(width: controlSize, height: controlSize)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("React")
        .popover(isPresented: $showingReactions, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            reactionsPopover
        }
    }

    private var reactionsPopover: some View {
        ReactionsBar(
            entry: entry,
            accent: palette.accent,
            isReadOnly: reactionsAreReadOnly,
            onSelection: { showingReactions = false }
        )
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.regularMaterial, in: Capsule())
        .presentationCompactAdaptation(.popover)
    }

    private var compactHeartButton: some View {
        let store = env.favoritesStore
        let isFav = store.isFavorite(entry)
        return Button {
            toggleFavourite()
        } label: {
            Image(systemName: isFav ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isFav ? .red : palette.accent)
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
    }

    private var compactInfoButton: some View {
        Button { showingInfo = true } label: {
            Image(systemName: "info")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.accent)
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Song info")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .onAppear { isAnimating = !reduceMotion }
    }
}
