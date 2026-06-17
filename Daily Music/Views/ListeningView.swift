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
    /// Today drives the interactive enter/exit transition through this 0…1 value
    /// (0 = absent, 1 = fully presented). Vault/Favorites present in a fullScreenCover
    /// and pass nil — the drag then animates an internal value and dismisses on commit.
    var presentation: Binding<Double>? = nil
    /// Fired when the bottom button is tapped (and, on Today, when the clip ends).
    /// Last so trailing-closure call sites bind to it.
    var onAdvance: () -> Void
    /// Today-only: fired ONCE when the listener crosses the collect threshold
    /// (≥25s of playback, or the clip finishing). Vault/Favorites pass nil — their
    /// collection semantics (open = caught up) are unchanged.
    var onReachedListenThreshold: (() -> Void)? = nil

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var palette = ArtworkPalette()
    @State private var animate = false
    /// Non-nil (0…1) while the user is dragging the progress bar.
    @State private var scrub: Double?
    /// nil until onAppear decides; the computed `phase` covers the first frame.
    @State private var resolvedPhase: CeremonyPhase?
    @State private var introPulse = false
    @State private var tracker = ListenTracker()
    @State private var didReachThreshold = false
    @State private var showingCollected = false
    /// Drives the gentle bob on the resting "swipe up to close" cue.
    @State private var swipeHintBob = false
    /// 0…1 arming progress while the user is swiping up to dismiss.
    @State private var dismissArm: Double = 0
    /// Captured container height so the dismiss drag scales to the screen.
    @State private var viewHeight: CGFloat = 1

    private enum CeremonyPhase { case intro, player }

    private var player: MusicPlayer { env.musicPlayer }
    private var accent: Color { palette.accent }
    private var scrubbing: Bool { scrub != nil }
    private var displayProgress: Double { scrub ?? player.progress }
    private let contentMaxWidth: CGFloat = 348

    /// How far the foreground rubber-bands up during the dismiss pull. The bloom
    /// never moves — only this lightweight layer does — so the blur stays cheap.
    private static let foregroundTravel: CGFloat = 64

    /// TodayView owns the opaque slide via `presentation` (0 = off-screen above,
    /// 1 = covering). Vault/Favorites present in a fullScreenCover and pass nil —
    /// there the commit just calls `onAdvance()` and the cover dismisses itself.
    private func slidePlayerAway(_ completion: @escaping () -> Void) {
        guard let presentation else { completion(); return }
        if reduceMotion {
            presentation.wrappedValue = 0
            completion()
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                presentation.wrappedValue = 0
            } completion: {
                completion()
            }
        }
    }

    private var phase: CeremonyPhase {
        resolvedPhase ?? (showsRevealIntro ? .intro : .player)
    }

    var body: some View {
        ZStack {
            bloom

            Group {
                if phase == .intro {
                    introStage
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.04)))
                } else {
                    playerStage
                        .transition(reduceMotion ? .opacity : .opacity)
                }
            }
            // The foreground rubber-bands up a little as the dismiss arms; the bloom
            // stays put so the heavy blur never repositions under the finger.
            .offset(y: reduceMotion ? 0 : -dismissArm * Self.foregroundTravel)
            .scaleEffect(reduceMotion ? 1 : 1 - 0.03 * dismissArm)

            // Bottom arming affordance: the resting "swipe up" cue cross-fades into
            // the ring as the pull progresses.
            if phase == .player {
                VStack {
                    Spacer()
                    dismissAffordance
                        .padding(.bottom, 24)
                }
                .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        // Swipe UP to send the player back to Today: it slid down from above to cover
        // Today, so the natural inverse is pushing it back up. Simultaneous so it
        // never blocks the transport/scrub.
        .contentShape(Rectangle())
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, newValue in viewHeight = newValue }
            }
        }
        .simultaneousGesture(dismissGesture)
        .task(id: entry.id) { await palette.load(from: entry.albumArtURL) }
        // Separate task from the palette load above: ticks the listen accumulator
        // while the player is open, so Today can collect the record once the
        // listener has genuinely heard ~25s (or the clip ends). No-op elsewhere.
        .task(id: entry.id) {
            guard onReachedListenThreshold != nil else { return }
            while !Task.isCancelled {
                tracker.sample(isPlaying: player.state == .playing)
                if !didReachThreshold,
                   tracker.hasReachedThreshold(finished: player.state == .finished) {
                    didReachThreshold = true
                    Haptics.success()
                    onReachedListenThreshold?()
                    if !reduceMotion {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showingCollected = true }
                    } else {
                        showingCollected = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
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
        .padding(.top, 18)
        .padding(.bottom, 22)
    }

    /// The resting "swipe up to close" cue (a bobbing up-chevron) cross-fading into
    /// the arming ring as the user pulls up. Decorative — hidden from VoiceOver (the
    /// labeled advance button is the accessible exit).
    private var dismissAffordance: some View {
        ZStack {
            VStack(spacing: 1) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .bold))
                Text("Swipe up to close")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.55))
            .offset(y: swipeHintBob ? -4 : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                value: swipeHintBob
            )
            .opacity(max(0, 1 - dismissArm * 1.5))
            .accessibilityHidden(true)
            .onAppear { swipeHintBob = true }

            PullArmingRing(
                progress: dismissArm,
                armed: dismissArm >= 1,
                label: dismissArm >= 1 ? "Release to close" : "Keep pulling…",
                tint: .white,
                pointsUp: true
            )
        }
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
        AlbumArtView(url: entry.albumArtURL, cornerRadius: Theme.Radius.card)
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

                if showingCollected {
                    Label("Collected — mint", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.white.opacity(0.18), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Collected as a mint record")
                }
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
                .contentShape(.rect(cornerRadius: Theme.Radius.row))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.white.opacity(0.20)).interactive(), in: .rect(cornerRadius: Theme.Radius.row))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .stroke(.white.opacity(0.30), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        .padding(.top, 4)
    }

    /// An upward swipe dismisses the player back to Today — the inverse of the
    /// pull-down that opened it (the player slides back up off-screen). The arming
    /// ring fills as you pull; release commits when full (or on a fast flick),
    /// otherwise it snaps back. Vertical-up only so a horizontal scrub can't trip it.
    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard isUpwardDrag(value) else { return }
                let up = max(0, -Double(value.translation.height))
                let arm = TransitionMath.armProgress(forDrag: up, height: viewHeight)
                if arm >= 1 && dismissArm < 1 { Haptics.tap() }   // detent when the ring fills
                dismissArm = arm
            }
            .onEnded { value in
                guard isUpwardDrag(value) else { settleDismiss(); return }
                let up = max(0, -Double(value.translation.height))
                let arm = TransitionMath.armProgress(forDrag: up, height: viewHeight)
                let outcome = TransitionResolver.resolve(
                    armProgress: arm, velocity: -Double(value.velocity.height))
                switch outcome {
                case .commit:
                    Haptics.tap()
                    slidePlayerAway { onAdvance() }
                case .cancel:
                    settleDismiss()
                }
            }
    }

    /// Spring the foreground rubber-band back to rest (cancelled dismiss).
    private func settleDismiss() {
        if reduceMotion {
            dismissArm = 0
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { dismissArm = 0 }
        }
    }

    /// True for a clearly-upward drag (so horizontal scrubs and downward flicks pass through).
    private func isUpwardDrag(_ value: DragGesture.Value) -> Bool {
        value.translation.height < 0 && abs(value.translation.width) < abs(value.translation.height)
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
