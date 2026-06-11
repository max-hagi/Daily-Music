//
//  TasteSeedView.swift
//  Daily Music
//
//  The onboarding "find your frequency" flow: a warm intro (with audio consent)
//  → the StarterPack rated via a swipe card deck (auto-playing, looping previews,
//  👍/👎 fallback thumbs) → an instant first-read reveal → straight into today's
//  first listening ceremony. The 👍/👎 picks are saved via SeedRatings to seed
//  the user's REAL taste mirror, so a profile is established at onboarding and
//  then evolves from daily ratings. Same gesture as the daily ritual.
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
    @State private var deck = TasteSeedDeck(songs: StarterPack.songs)
    @State private var read = StartingRead()
    @State private var artPalette = ArtworkPalette()

    /// Bloom colors per phase: brand violet for the intro, the current card's
    /// artwork color while rating, the archetype's colors at reveal.
    private var bloomPalette: [Color] {
        switch phase {
        case .intro:
            return [.purple, .pink, .indigo]
        case .rating:
            let a = artPalette.accent
            return [a, a, .indigo]
        case .reveal:
            let profile = TasteMirror.build(from: deck.picks).archetype ?? .theShapeshifter
            return profile.colors.isEmpty ? [.purple, .pink, .indigo] : profile.colors
        }
    }

    private var player: MusicPlayer { env.musicPlayer }
    private var firstName: String {
        let n = displayName.split(separator: " ").first.map(String.init) ?? displayName
        return n.isEmpty ? "there" : n
    }

    var body: some View {
        ZStack {
            // One bloom backdrop across all phases; while rating it tints from
            // the current card's artwork. Adaptive chrome keeps light mode light.
            OnboardingBloomBackground(palette: bloomPalette)
                .ignoresSafeArea()
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
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: deck.index)
        .onChange(of: phase) { _, newPhase in
            // Begin tapped → rating starts → first preview auto-plays. The Begin
            // tap is the consenting user gesture for audio.
            guard newPhase == .rating, let song = deck.current else { return }
            Task { await player.toggle(song) }
            Task { await artPalette.load(from: song.albumArtURL) }
        }
        .onChange(of: deck.index) { _, _ in
            // Each swipe re-tints the bloom from the next card's artwork.
            guard phase == .rating, let song = deck.current else { return }
            Task { await artPalette.load(from: song.albumArtURL) }
        }
        .onChange(of: player.state) { _, newState in
            // Loop: a finished preview restarts until the user swipes.
            guard phase == .rating, newState == .finished,
                  let song = deck.current, player.nowPlayingEntryID == song.id else { return }
            Task { await player.toggle(song) }   // toggle from .finished replays fresh
        }
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
            Text("Songs will play out loud — headphones on 🎧. Swipe right if you're into it, left if not. This seeds your taste profile; it grows from your daily songs after.")
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

    // MARK: rating — the swipe deck
    private var ratingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer(minLength: Theme.Spacing.xl)
            deckDots

            TasteSeedCardStack(
                cards: deck.upcoming,
                onTapFront: { if let song = deck.current { togglePreview(song) } },
                onJudge: judge
            )
            .frame(height: 330)

            if let song = deck.current {
                songMeta(song)
                    .id(deck.index)   // crossfade the block per card
                    .transition(.opacity)
            }

            swipeHints

            Spacer()

            // Compact fallbacks: swiping is the primary gesture, but the thumbs
            // stay for one-handed reach, VoiceOver, and Reduce Motion users.
            HStack(spacing: Theme.Spacing.xl) {
                judgmentButton(value: -1, symbol: "hand.thumbsdown.fill", tint: .secondary)
                judgmentButton(value: 1, symbol: "hand.thumbsup.fill", tint: artPalette.accent)
            }
            .padding(.bottom, 32)
        }
    }

    /// Deck progress: one dot per starter song — filled when judged, big when current.
    private var deckDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<deck.songs.count, id: \.self) { i in
                Circle()
                    .fill(i == deck.index ? artPalette.accent
                          : i < deck.index ? Color.primary.opacity(0.75) : Color.primary.opacity(0.25))
                    .frame(width: i == deck.index ? 9 : 6, height: i == deck.index ? 9 : 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: deck.index)
        .accessibilityLabel(deck.positionText)
    }

    /// Title, artist, live preview progress, and the song's flavor tags — fixed
    /// below the deck so the peeking cards never collide with text.
    private func songMeta(_ song: DailyEntry) -> some View {
        VStack(spacing: 8) {
            Text(song.title)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
            Text(song.artist)
                .font(.headline)
                .foregroundStyle(.secondary).lineLimit(1)

            // Live preview bar — shows the clip moving (tap the art to pause).
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.18))
                Capsule().fill(Color.primary)
                    .frame(width: 200 * player.progress)
            }
            .frame(width: 200, height: 4)
            .padding(.top, 2)
            .accessibilityHidden(true)

            HStack(spacing: 6) {
                ForEach([song.mood, song.genre, song.year.map(String.init)].compactMap { $0 }, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                        .foregroundStyle(.primary.opacity(0.85))
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    /// Explicit gesture affordance — which direction means what.
    private var swipeHints: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                Text("Nah")
            }
            .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
            Spacer()
            HStack(spacing: 6) {
                Text("Into it")
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(Color(red: 0.4, green: 0.9, blue: 0.55))
        }
        .font(.subheadline.weight(.bold))
        .padding(.horizontal, 56)
        .padding(.top, 4)
        .accessibilityHidden(true)   // the card exposes Like/Dislike actions
    }

    private func judgmentButton(value: Int, symbol: String, tint: Color) -> some View {
        Button { judge(value) } label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(tint, in: Circle())
                .shadow(color: tint.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value > 0 ? "Like" : "Dislike")
    }

    // MARK: reveal
    private var reveal: some View {
        // All starter songs are judged by the time reveal shows, which clears
        // the unlock threshold — use the real engine for the first-read profile.
        let profile = TasteMirror.build(from: deck.picks).archetype ?? .theShapeshifter
        return VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: profile.symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(profile.colors.first ?? Theme.Brand.gradient[0])
                Text("Your starting frequency")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                // The archetype is the headline — the identity moment. The
                // mood · genre read is demoted to flavor text under it.
                Text(profile.title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(profile.tagline)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(readHeadline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(profile.colors.first ?? Theme.Brand.gradient[0])
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                Text("Your taste mirror starts here and sharpens every day you rate a song. Today's song is waiting once you finish setup.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.lg)
            .glassCard(cornerRadius: 24)
            .padding(.horizontal, Theme.Spacing.lg)
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
        deck.judge(value)
        if let next = deck.current {
            Task { await player.toggle(next) }   // different entry → starts fresh
        } else {
            read = StartingRead.from(picks: deck.picks)
            SeedRatings.save(deck.picks)   // seed the real taste mirror
            Task { await player.stop() }
            phase = .reveal
        }
    }

    private func stopAndExit(_ action: @escaping () -> Void) {
        Task { await player.stop() }
        action()
    }
}
