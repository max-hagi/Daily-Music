//
//  ListeningView.swift
//  Daily Music
//
//  The immersive "now playing" screen: the album art floating in a bloom of its own
//  colors (ArtworkPalette), with native iOS-style playback controls: a scrubbable
//  progress slider, time labels, restart, play/pause, and favorite. Drives playback
//  through the shared MusicPlayer; calls onAdvance() when the clip ends (Today) or
//  the listener taps the bottom button (Vault/Favorites just dismiss).
//
//  When opened as today's first-listen ceremony (showsRevealIntro), the song is
//  not shown immediately: a short intro ("Your song of the day") holds the moment,
//  then the artwork and controls bloom in and playback begins. The anticipation
//  beat is what makes the daily reveal feel like an event instead of a popup —
//  tap anywhere to skip it.
//

import SwiftUI

struct ListeningView: View {
    let entry: DailyEntry
    /// Bottom-button label. Today flows into the journal ("Read today's story");
    /// Vault/Favorites just dismiss ("Done").
    var advanceLabel: String = "Read today's story"
    var advanceSystemImage: String = "arrow.down"
    /// Today auto-advances to the journal when the clip ends. Archive contexts
    /// stay put so the listener can replay or close on their own terms.
    var autoAdvanceOnFinish: Bool = true
    /// True only for today's first-listen ceremony: hold on an intro beat, then
    /// reveal the song. Manual opens (headphones button, archive) go straight in.
    var showsRevealIntro: Bool = false
    /// Fired when the bottom button is tapped (and, on Today, when the clip ends).
    /// Last so trailing-closure call sites bind to it.
    var onAdvance: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var palette = ArtworkPalette()
    @State private var animate = false
    /// Non-nil (0…1) while the user is dragging the progress bar.
    @State private var scrub: Double?
    /// nil until onAppear decides; the computed `phase` covers the first frame.
    @State private var resolvedPhase: CeremonyPhase?
    @State private var introPulse = false

    private enum CeremonyPhase { case intro, player }

    private var player: MusicPlayer { env.musicPlayer }
    private var accent: Color { palette.accent }
    private var scrubbing: Bool { scrub != nil }
    private var displayProgress: Double { scrub ?? player.progress }
    private let contentMaxWidth: CGFloat = 348

    private var phase: CeremonyPhase {
        resolvedPhase ?? (showsRevealIntro ? .intro : .player)
    }

    var body: some View {
        ZStack {
            bloom

            if phase == .intro {
                introStage
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.04)))
            } else {
                playerStage
                    .transition(reduceMotion ? .opacity : .opacity)
            }
        }
        .preferredColorScheme(.dark)
        .task(id: entry.id) { await palette.load(from: entry.albumArtURL) }
        .task {
            if phase == .player {
                await startPlaybackIfNeeded()
            } else {
                // Hold the intro beat, then reveal (a tap skips ahead).
                try? await Task.sleep(for: .seconds(1.6))
                reveal()
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { animate = true }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { introPulse = true }
        }
        .onChange(of: player.state) { _, newValue in
            guard autoAdvanceOnFinish, newValue == .finished else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.8))   // a beat, then the story
                onAdvance()
            }
        }
    }

    // MARK: ceremony

    /// The anticipation beat: today's date and a promise, no song spoiled yet.
    private var introStage: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 132, height: 132)
                    .scaleEffect(introPulse ? 1.12 : 0.96)
                    .opacity(introPulse ? 0.5 : 1)

                Image(systemName: "music.note")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .glassEffect(.regular.tint(.white.opacity(0.14)), in: .circle)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text(entry.date.formatted(.dateTime.weekday(.wide).month().day()).uppercased())
                    .font(.caption.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))

                Text("Your song of the day")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Text("Tap to reveal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { reveal() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Reveal today's song")
    }

    private func reveal() {
        guard phase == .intro else { return }
        Haptics.tap()
        withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.82)) {
            resolvedPhase = .player
        }
        Task { await startPlaybackIfNeeded() }
    }

    private func startPlaybackIfNeeded() async {
        if !player.isPlaying(entry) && player.state != .finished {
            await player.toggle(entry)
        }
    }

    // MARK: player stage

    private var playerStage: some View {
        VStack(spacing: 34) {
            Spacer(minLength: 0)
            artwork
            controlDeck
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 34)
        .padding(.bottom, 22)
    }

    // MARK: background — the song's own color, blooming
    private var bloom: some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.78), .black.opacity(0.68), accent.opacity(0.46)],
                startPoint: animate ? .topLeading : .bottomTrailing,
                endPoint: animate ? .bottomTrailing : .topLeading
            )
            // The artwork wash only joins once the song is revealed, so the intro
            // doesn't leak the album's colors ahead of the moment.
            if phase == .player, let image = palette.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 90)
                    .saturation(1.28)
                    .opacity(0.62)
                    .transition(.opacity)
            }
            LinearGradient(
                colors: [.white.opacity(0.14), .clear, .black.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.7), value: accent)
    }

    // MARK: hero art
    private var artwork: some View {
        AlbumArtView(url: entry.albumArtURL, cornerRadius: 22)
            .frame(maxWidth: contentMaxWidth)
            .padding(.horizontal, 4)
            .scaleEffect(player.state == .playing ? (animate ? 1.0 : 0.965) : 0.95)
            .shadow(color: .black.opacity(0.48), radius: 26, y: 18)
            .shadow(color: accent.opacity(0.32), radius: 36)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: player.state)
    }

    // MARK: playback controls
    private var controlDeck: some View {
        GlassEffectContainer(spacing: 22) {
            VStack(spacing: 18) {
                VStack(spacing: 5) {
                    Text(entry.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(entry.artist)
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                EqualizerBars(isPlaying: player.state == .playing)
                    .frame(height: 16)

                scrubBar

                transportRow
                advanceButton
            }
            .foregroundStyle(.white)
            .frame(maxWidth: contentMaxWidth)   // align the control column with the album art
            .padding(.horizontal, 2)
        }
    }

    // MARK: scrubbable progress
    private var scrubBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                let trackHeight: CGFloat = scrubbing ? 10 : 7
                let knobSize: CGFloat = scrubbing ? 22 : 16

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.14))
                        .frame(height: trackHeight)
                        .glassEffect(.regular.tint(.white.opacity(0.16)), in: .capsule)
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.24), lineWidth: 1)
                        }

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.92), accent.opacity(0.86)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(knobSize / 2, width * displayProgress), height: trackHeight)

                    Circle()
                        .fill(.white.opacity(0.50))
                        .frame(width: knobSize, height: knobSize)
                        .glassEffect(.regular.tint(.white.opacity(0.28)).interactive(), in: .circle)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.46), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.26), radius: 7, y: 3)
                        .offset(x: max(0, min(width - knobSize, width * displayProgress - knobSize / 2)))
                }
                .frame(height: 30)
                .contentShape(Rectangle())
                .gesture(scrubGesture(width: width))
                .animation(.spring(response: 0.28, dampingFraction: 0.74), value: scrubbing)
            }
            .frame(height: 30)
            .accessibilityElement()
            .accessibilityLabel("Playback position")
            .accessibilityValue(timeString(displayProgress * player.duration))
            .accessibilityAdjustableAction { direction in
                guard player.duration > 0 else { return }
                let step = max(1, player.duration / 10)   // ~10% per VoiceOver nudge
                let current = displayProgress * player.duration
                let target: Double
                switch direction {
                case .increment: target = min(player.duration, current + step)
                case .decrement: target = max(0, current - step)
                @unknown default: return
                }
                Task { await player.seek(to: target) }
            }

            HStack {
                Text(timeString(displayProgress * player.duration))
                Spacer()
                if isPreviewClip {
                    Text("PREVIEW")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                }
                Text("-\(timeString(max(player.duration - displayProgress * player.duration, 0)))")
            }
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    /// 30-second previews end abruptly; the label sets the expectation.
    private var isPreviewClip: Bool {
        player.duration > 0 && player.duration < 45
    }

    // MARK: transport — restart · play/pause · favorite
    private var transportRow: some View {
        HStack(spacing: 26) {
            restartButton
            playPauseButton
            favoriteButton
        }
    }

    private var playPauseButton: some View {
        Button {
            Task { await player.toggle(entry) }
        } label: {
            Group {
                if player.state == .buffering {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.4)
                } else {
                    Image(systemName: playPauseIcon)
                        .font(.system(size: 42, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(width: 88, height: 76)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .contentTransition(.symbolEffect(.replace))
        .glassEffect(.regular.tint(.white.opacity(0.14)).interactive(), in: .circle)
        .overlay {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 8, y: 4)
        .accessibilityLabel(player.state == .playing ? "Pause" : "Play")
    }

    private var restartButton: some View {
        Button {
            Haptics.select()
            Task { await player.restart(entry) }
        } label: {
            Image(systemName: "backward.end.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 54, height: 54)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(.white.opacity(0.10)).interactive(), in: .circle)
        .accessibilityLabel("Play from the start")
    }

    /// Favorite, right in the player — the impulse to keep a song peaks while
    /// it's playing, so don't make the listener leave to act on it.
    private var favoriteButton: some View {
        let isFav = env.favoritesStore.isFavorite(entry)
        return Button {
            Haptics.tap()
            Task { await env.favoritesStore.toggle(entry) }
        } label: {
            Image(systemName: isFav ? "heart.fill" : "heart")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isFav ? .red : .white.opacity(0.9))
                .frame(width: 54, height: 54)
                .contentShape(Circle())
                .symbolEffect(.bounce, value: isFav)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(.white.opacity(0.10)).interactive(), in: .circle)
        .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
    }

    private var advanceButton: some View {
        Button(action: onAdvance) {
            Label(advanceLabel, systemImage: advanceSystemImage)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(minWidth: 136)
                .padding(.vertical, 14)
                .padding(.horizontal, 22)
                .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.white.opacity(0.20)).interactive(), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.30), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        .padding(.top, 4)
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard width > 0, player.duration > 0 else { return }
                scrub = min(1, max(0, value.location.x / width))
            }
            .onEnded { value in
                guard width > 0, player.duration > 0 else { return }
                let target = min(1, max(0, value.location.x / width))
                scrub = target
                Task {
                    await player.seek(to: target * player.duration)
                    scrub = nil
                }
            }
    }

    private var playPauseIcon: String {
        switch player.state {
        case .playing:  "pause.fill"
        case .finished: "arrow.counterclockwise"
        default:        "play.fill"
        }
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds.rounded())
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}

/// Five capsules dancing while audio plays — frozen low when paused. Pure
/// decoration (hidden from VoiceOver); the play button is the source of truth.
private struct EqualizerBars: View {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let peaks: [CGFloat] = [0.55, 0.95, 0.7, 1.0, 0.6]

    var body: some View {
        HStack(spacing: 3.5) {
            ForEach(peaks.indices, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: 3.5, height: 16)
                    .scaleEffect(y: animatingScale(at: index), anchor: .bottom)
                    .animation(animation(at: index), value: isPlaying)
            }
        }
        .opacity(isPlaying ? 1 : 0.35)
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
        .accessibilityHidden(true)
    }

    private func animatingScale(at index: Int) -> CGFloat {
        guard isPlaying, !reduceMotion else { return 0.25 }
        return peaks[index]
    }

    private func animation(at index: Int) -> Animation? {
        guard isPlaying, !reduceMotion else { return .easeOut(duration: 0.25) }
        // Slightly different tempo per bar so they never sync up.
        return .easeInOut(duration: 0.42 + Double(index) * 0.07).repeatForever(autoreverses: true)
    }
}
