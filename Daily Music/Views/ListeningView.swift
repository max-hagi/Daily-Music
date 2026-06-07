//
//  ListeningView.swift
//  Daily Music
//
//  The immersive "listen first" screen. Plays today's 30-sec preview over a
//  blurred-art backdrop, then calls onAdvance() when the preview finishes (or
//  when the listener taps "Read today's story"). Presentational only — it drives
//  playback through the shared MusicPlayer in AppEnvironment.
//

import SwiftUI

struct ListeningView: View {
    let entry: DailyEntry
    var onAdvance: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var player: MusicPlayer { env.musicPlayer }

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                artwork
                titleBlock
                progressBar
                controls
                Spacer()
                readStoryButton
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .preferredColorScheme(.dark)
        .task {
            if !player.isPlaying(entry) && player.state != .finished {
                await player.toggle(entry)
            }
            pulse = !reduceMotion
        }
        .onChange(of: player.state) { _, newValue in
            guard newValue == .finished else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.8))  // a beat, then the story
                onAdvance()
            }
        }
    }

    private var backdrop: some View {
        AsyncImage(url: entry.albumArtURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Color.black
        }
        .ignoresSafeArea()
        .blur(radius: 55)
        .overlay(Color.black.opacity(0.5).ignoresSafeArea())
    }

    private var artwork: some View {
        let breathing = player.state == .playing && pulse
        return AlbumArtView(url: entry.albumArtURL, cornerRadius: 24)
            .frame(maxWidth: 300)
            .scaleEffect(breathing ? 1.0 : 0.97)
            .animation(
                breathing ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .default,
                value: breathing
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(entry.title)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            Text(entry.artist)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(.white).frame(width: geo.size.width * player.progress)
            }
        }
        .frame(height: 4)
        .padding(.horizontal)
    }

    @ViewBuilder private var controls: some View {
        if player.state == .playing && !reduceMotion {
            MusicLoadingView(title: nil, tint: .white)
                .frame(height: 42)
        } else {
            Color.clear.frame(height: 42)
        }
        Button {
            Task { await player.toggle(entry) }
        } label: {
            Image(systemName: playPauseIcon)
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
        }
        .accessibilityLabel(player.state == .playing ? "Pause" : "Play")
    }

    private var readStoryButton: some View {
        Button(action: onAdvance) {
            Label("Read today's story", systemImage: "arrow.down")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white.opacity(0.18))
        .foregroundStyle(.white)
    }

    private var playPauseIcon: String {
        switch player.state {
        case .playing:  "pause.circle.fill"
        case .finished: "arrow.counterclockwise.circle.fill"
        default:        "play.circle.fill"
        }
    }
}
