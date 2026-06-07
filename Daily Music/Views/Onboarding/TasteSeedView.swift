//
//  TasteSeedView.swift
//  Daily Music
//
//  The onboarding "find your frequency" flow, shown as a full-screen cover right
//  after the name step: a warm intro → 7 "this or that" rounds (tap a cover to
//  preview, tap Choose to pick) → an instant first-read reveal. Picks build a
//  StartingRead via the real TasteMirror. Onboarding-only: nothing is written to
//  song_ratings.
//

import SwiftUI

struct TasteSeedView: View {
    let displayName: String
    var onComplete: (StartingRead) -> Void
    var onSkip: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: Equatable { case intro, rounds, reveal }
    @State private var phase: Phase = .intro
    @State private var roundIndex = 0
    @State private var picks: [RatedSong] = []
    @State private var read = StartingRead()

    private let rounds = StarterPack.rounds()
    private var player: MusicPlayer { env.musicPlayer }
    private var firstName: String {
        let n = displayName.split(separator: " ").first.map(String.init) ?? displayName
        return n.isEmpty ? "there" : n
    }

    var body: some View {
        ZStack {
            Theme.Brand.gradient.first.map { $0.opacity(0.12) }?.ignoresSafeArea()
            Color(.systemGroupedBackground).opacity(0.6).ignoresSafeArea()
            switch phase {
            case .intro:  intro
            case .rounds: roundsView
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
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: roundIndex)
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
            Text("A few quick taps. For each pair, pick the one that pulls you — tap a cover to hear a taste first.")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Spacer()
            Button { phase = .rounds } label: {
                Text("Begin").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: Theme.Brand.gradient[0]))
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    // MARK: rounds
    private var roundsView: some View {
        let pair = rounds[roundIndex]
        return VStack(spacing: Theme.Spacing.lg) {
            Text("\(roundIndex + 1) of \(rounds.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Spacing.xl)
            Text("Which pulls you?")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
            HStack(spacing: Theme.Spacing.md) {
                choiceCard(pair.0)
                choiceCard(pair.1)
            }
            .padding(.horizontal, Theme.Spacing.md)
            Spacer()
        }
    }

    private func choiceCard(_ song: DailyEntry) -> some View {
        let isPreviewing = player.isPlaying(song)
        return VStack(spacing: Theme.Spacing.sm) {
            Button { togglePreview(song) } label: {
                ZStack(alignment: .bottomTrailing) {
                    AlbumArtView(url: song.albumArtURL, cornerRadius: 16)
                    Image(systemName: isPreviewing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .padding(8)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPreviewing ? "Pause preview of \(song.title)" : "Preview \(song.title)")

            VStack(spacing: 2) {
                Text(song.title).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Button { choose(song) } label: {
                Text("Choose").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Brand.gradient[0])
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: reveal
    private var reveal: some View {
        let profile = TasteProfile.resolve(mood: read.mood, decade: read.decade, theme: nil)
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
            Text("A starting point — your real taste mirror grows as you rate your daily songs.")
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

    private func choose(_ song: DailyEntry) {
        Haptics.tap()
        let pair = rounds[roundIndex]
        let other = song.id == pair.0.id ? pair.1 : pair.0
        picks.append(RatedSong(entry: song, value: 1))
        picks.append(RatedSong(entry: other, value: -1))
        Task { await player.stop() }
        if roundIndex + 1 < rounds.count {
            roundIndex += 1
        } else {
            read = StartingRead.from(picks: picks)
            phase = .reveal
        }
    }

    private func stopAndExit(_ action: @escaping () -> Void) {
        Task { await player.stop() }
        action()
    }
}
