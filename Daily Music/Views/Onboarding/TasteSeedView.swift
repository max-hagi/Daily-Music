//
//  TasteSeedView.swift
//  Daily Music
//
//  The onboarding "find your frequency" flow, shown as a full-screen cover right
//  after the name step: a warm intro → the StarterPack rated one song at a time (tap
//  the art to preview, 👍/👎) → an instant first-read reveal. The 👍/👎 are saved via
//  SeedRatings to seed the user's REAL taste mirror, so a profile is established at
//  onboarding and then evolves from daily ratings. Same gesture as the daily ritual.
//

import SwiftUI

struct TasteSeedView: View {
    let displayName: String
    var onComplete: (StartingRead) -> Void
    var onSkip: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: Equatable { case intro, rating, reveal }
    @State private var phase: Phase = .intro
    @State private var index = 0
    @State private var picks: [RatedSong] = []
    @State private var read = StartingRead()

    private let songs = StarterPack.songs
    private var player: MusicPlayer { env.musicPlayer }
    private var firstName: String {
        let n = displayName.split(separator: " ").first.map(String.init) ?? displayName
        return n.isEmpty ? "there" : n
    }
    private var current: DailyEntry { songs[min(index, songs.count - 1)] }

    var body: some View {
        ZStack {
            Theme.Brand.gradient.first.map { $0.opacity(0.12) }?.ignoresSafeArea()
            Color(.systemGroupedBackground).opacity(0.6).ignoresSafeArea()
            switch phase {
            case .intro:  intro
            case .rating: ratingView
            case .reveal: reveal
            }
        }
        .overlay(alignment: .topTrailing) {
            if phase != .reveal {
                Button("Skip") { stopAndExit(onSkip) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: phase)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: index)
    }

    // MARK: intro
    private var intro: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "dial.medium.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.Brand.gradient[0])
            Text("Alright, \(firstName) —\nlet's find your frequency")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Tap a song to hear a taste, then react 👍 or 👎. This seeds your taste profile — it grows from your daily songs after.")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Spacer()
            Button { phase = .rating } label: {
                Text("Begin").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: Theme.Brand.gradient[0]))
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    // MARK: rating — one song at a time
    private var ratingView: some View {
        let song = current
        let isPreviewing = player.isPlaying(song)
        return VStack(spacing: Theme.Spacing.lg) {
            Spacer(minLength: Theme.Spacing.xl)
            Text("\(index + 1) of \(songs.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Button { togglePreview(song) } label: {
                ZStack(alignment: .bottomTrailing) {
                    AlbumArtView(url: song.albumArtURL, cornerRadius: 24)
                        .frame(maxWidth: 300)
                    Image(systemName: isPreviewing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .padding(12)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPreviewing ? "Pause preview" : "Preview \(song.title)")

            VStack(spacing: 4) {
                Text(song.title)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                Text(song.artist)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Text("Tap the art to hear a taste")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            HStack(spacing: Theme.Spacing.xl) {
                judgmentButton(value: -1, symbol: "hand.thumbsdown.fill", tint: .secondary)
                judgmentButton(value: 1, symbol: "hand.thumbsup.fill", tint: Theme.Brand.gradient[0])
            }
            .padding(.bottom, 40)
        }
    }

    private func judgmentButton(value: Int, symbol: String, tint: Color) -> some View {
        Button { judge(value) } label: {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 92, height: 92)
                .background(tint, in: Circle())
                .shadow(color: tint.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value > 0 ? "Like" : "Dislike")
    }

    // MARK: reveal
    private var reveal: some View {
        let profile = TasteProfile.resolve(mood: read.mood, modifier: nil)
        return VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: profile.symbol)
                .font(.system(size: 56))
                .foregroundStyle(profile.colors.first ?? Theme.Brand.gradient[0])
            Text("Your starting frequency")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(readHeadline)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Text("Your taste mirror starts here and sharpens every day you rate a song.")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Spacer()
            Button { stopAndExit { onComplete(read) } } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: profile.colors.first ?? Theme.Brand.gradient[0]))
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    private var readHeadline: String {
        let parts = [read.mood, read.genre].compactMap { $0 }
        return parts.isEmpty ? "An open book 📖" : parts.joined(separator: " · ")
    }

    // MARK: actions
    private func togglePreview(_ song: DailyEntry) {
        Task { await player.toggle(song) }
    }

    private func judge(_ value: Int) {
        Haptics.tap()
        picks.append(RatedSong(entry: current, value: value))
        Task { await player.stop() }
        if index + 1 < songs.count {
            index += 1
        } else {
            read = StartingRead.from(picks: picks)
            SeedRatings.save(picks)   // seed the real taste mirror
            phase = .reveal
        }
    }

    private func stopAndExit(_ action: @escaping () -> Void) {
        Task { await player.stop() }
        action()
    }
}
