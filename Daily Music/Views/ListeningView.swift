//
//  ListeningView.swift
//  Daily Music
//
//  The immersive "now playing" screen: the album art floating in a bloom of its own
//  colors (ArtworkPalette), with a Liquid-Glass control deck — a scrubbable progress
//  bar, time labels, and a glass play/pause. Drives playback through the shared
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
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                artwork
                Spacer(minLength: 0)
                controlDeck
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
                colors: [accent.opacity(0.65), .black.opacity(0.92), accent.opacity(0.30)],
                startPoint: animate ? .topLeading : .bottomTrailing,
                endPoint: animate ? .bottomTrailing : .topLeading
            )
            if let image = palette.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 90)
                    .saturation(1.35)
                    .opacity(0.5)
            }
            Color.black.opacity(0.22)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.7), value: accent)
    }

    // MARK: hero art
    private var artwork: some View {
        AlbumArtView(url: entry.albumArtURL, cornerRadius: 30)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .scaleEffect(player.state == .playing ? (animate ? 1.0 : 0.965) : 0.95)
            .shadow(color: .black.opacity(0.55), radius: 38, y: 24)
            .shadow(color: accent.opacity(0.45), radius: 55)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: player.state)
    }

    // MARK: glass control deck
    private var controlDeck: some View {
        VStack(spacing: Theme.Spacing.md) {
            VStack(spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(entry.artist)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            scrubBar
            playPauseButton
            advanceButton
        }
        .foregroundStyle(.white)
        .padding(Theme.Spacing.lg)
        .glassEffect(.regular, in: .rect(cornerRadius: 32))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
    }

    // MARK: scrubbable progress
    private var scrubBar: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                let w = geo.size.width
                let trackHeight: CGFloat = scrubbing ? 9 : 5
                let knob: CGFloat = scrubbing ? 20 : 13
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2)).frame(height: trackHeight)
                    Capsule().fill(accent).frame(width: max(0, w * displayProgress), height: trackHeight)
                    Circle()
                        .fill(.white)
                        .frame(width: knob, height: knob)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                        .offset(x: max(0, min(w - knob, w * displayProgress - knob / 2)))
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in scrub = min(1, max(0, v.location.x / w)) }
                        .onEnded { v in
                            let f = min(1, max(0, v.location.x / w))
                            scrub = f
                            Task {
                                await player.seek(to: f * player.duration)
                                scrub = nil
                            }
                        }
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scrubbing)
            }
            .frame(height: 24)

            HStack {
                Text(timeString(displayProgress * player.duration))
                Spacer()
                Text(timeString(player.duration))
            }
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var playPauseButton: some View {
        Button {
            Task { await player.toggle(entry) }
        } label: {
            Image(systemName: playPauseIcon)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 74, height: 74)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(player.state == .playing ? "Pause" : "Play")
    }

    private var advanceButton: some View {
        Button(action: onAdvance) {
            Label(advanceLabel, systemImage: advanceSystemImage)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(.white.opacity(0.14), in: Capsule())
        .padding(.top, 2)
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
