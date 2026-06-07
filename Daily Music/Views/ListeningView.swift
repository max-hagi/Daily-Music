//
//  ListeningView.swift
//  Daily Music
//
//  The immersive "now playing" screen: the album art floating in a bloom of its own
//  colors (ArtworkPalette), with native iOS-style playback controls: a scrubbable
//  progress slider, time labels, and play/pause. Drives playback through the shared
//  MusicPlayer; calls onAdvance() when the clip ends (Today) or the listener taps
//  the bottom button (Vault/Favorites just dismiss).
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
    /// Fired when the bottom button is tapped (and, on Today, when the clip ends).
    /// Last so trailing-closure call sites bind to it.
    var onAdvance: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var palette = ArtworkPalette()
    @State private var animate = false
    /// Non-nil (0…1) while the user is dragging the progress bar.
    @State private var scrub: Double?

    private var player: MusicPlayer { env.musicPlayer }
    private var accent: Color { palette.accent }
    private var scrubbing: Bool { scrub != nil }
    private var displayProgress: Double { scrub ?? player.progress }

    var body: some View {
        ZStack {
            bloom
            VStack(spacing: 34) {
                Spacer(minLength: 0)
                artwork
                controlDeck
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 44)
            .padding(.bottom, 28)
        }
        .preferredColorScheme(.dark)
        .task(id: entry.id) { await palette.load(from: entry.albumArtURL) }
        .task {
            if !player.isPlaying(entry) && player.state != .finished {
                await player.toggle(entry)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { animate = true }
        }
        .onChange(of: player.state) { _, newValue in
            guard autoAdvanceOnFinish, newValue == .finished else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.8))   // a beat, then the story
                onAdvance()
            }
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
            if let image = palette.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 90)
                    .saturation(1.28)
                    .opacity(0.62)
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
            .frame(maxWidth: 312)
            .padding(.horizontal, 18)
            .scaleEffect(player.state == .playing ? (animate ? 1.0 : 0.965) : 0.95)
            .shadow(color: .black.opacity(0.48), radius: 26, y: 18)
            .shadow(color: accent.opacity(0.32), radius: 36)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: player.state)
    }

    // MARK: playback controls
    private var controlDeck: some View {
        GlassEffectContainer(spacing: 22) {
            VStack(spacing: 22) {
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

                scrubBar

                playPauseButton
                advanceButton
            }
            .foregroundStyle(.white)
            .frame(maxWidth: 312)   // align the control column with the album art
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
                        .fill(.white.opacity(0.92))
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

            HStack {
                Text(timeString(displayProgress * player.duration))
                Spacer()
                Text("-\(timeString(max(player.duration - displayProgress * player.duration, 0)))")
            }
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var playPauseButton: some View {
        Button {
            Task { await player.toggle(entry) }
        } label: {
            Image(systemName: playPauseIcon)
                .font(.system(size: 42, weight: .semibold))
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

    private var advanceButton: some View {
        Button(action: onAdvance) {
            Label(advanceLabel, systemImage: advanceSystemImage)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(minWidth: 136)
                .padding(.vertical, 14)
                .padding(.horizontal, 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.white.opacity(0.24)).interactive(), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.32), lineWidth: 1)
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
