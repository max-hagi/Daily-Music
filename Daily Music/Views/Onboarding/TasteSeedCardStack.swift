//
//  TasteSeedCardStack.swift
//  Daily Music
//
//  The onboarding swipe deck. Renders TasteSeedDeck.upcoming (front first):
//  the front card follows the drag with rotation and an INTO IT / NAH badge,
//  flying off past the threshold; the next cards peek behind. Dumb on purpose —
//  judgment recording, persistence, and audio live in TasteSeedView.
//

import SwiftUI

struct TasteSeedCardStack: View {
    let cards: [DailyEntry]            // deck.upcoming — front card first, max 3
    var onTapFront: () -> Void         // tap art → pause/resume preview
    var onJudge: (Int) -> Void         // +1 / -1 for the front card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGSize = .zero
    @State private var flying = false  // front card is mid-fling; ignore input

    private let commitDistance: CGFloat = 110

    var body: some View {
        ZStack {
            // Reversed so the front card (index 0) draws on top.
            ForEach(Array(cards.enumerated().reversed()), id: \.element.id) { depth, song in
                card(song, depth: depth)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: cards.first?.id)
    }

    @ViewBuilder
    private func card(_ song: DailyEntry, depth: Int) -> some View {
        // Art-only cards: title/artist live in TasteSeedView below the deck so
        // the peeking back cards can never overlap the song text.
        let isFront = depth == 0
        AlbumArtView(url: song.albumArtURL, cornerRadius: 24)
            .frame(maxWidth: 300)
            .overlay {
                // Full-card wash: the whole cover tints toward the verdict
                // as the drag commits, so the direction reads at a glance.
                if isFront, drag.width != 0 {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(drag.width > 0 ? Color.green : Color.red)
                        .opacity(Double(min(1, abs(drag.width) / commitDistance)) * 0.35)
                }
            }
            .overlay(alignment: .topLeading) { if isFront { badge } }
        .scaleEffect(isFront ? 1 : 1 - 0.05 * CGFloat(depth))
        .offset(y: isFront ? 0 : CGFloat(depth) * -16)   // back cards peek above
        .rotationEffect(.degrees(isFront ? Double(drag.width / 18) : (depth == 1 ? -2.5 : 2.5)))
        .offset(isFront ? drag : .zero)
        .shadow(color: .black.opacity(isFront ? 0.25 : 0.1), radius: 14, y: 8)
        .zIndex(isFront ? 1 : 0)
        .onTapGesture { if isFront { onTapFront() } }
        .gesture(isFront ? dragGesture : nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isFront ? "\(song.title) by \(song.artist), now previewing" : "")
        .accessibilityHidden(!isFront)
        .accessibilityAction(named: "Like") { onJudge(1) }
        .accessibilityAction(named: "Dislike") { onJudge(-1) }
        .accessibilityAction(named: "Pause or play preview") { onTapFront() }
    }

    // The INTO IT / NAH stamp that fades in as the drag approaches the threshold.
    @ViewBuilder private var badge: some View {
        let strength = min(1, abs(drag.width) / commitDistance)
        if drag.width != 0 {
            Text(drag.width > 0 ? "INTO IT" : "NAH")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(drag.width > 0 ? .green : .red)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(drag.width > 0 ? Color.green : Color.red, lineWidth: 3))
                .rotationEffect(.degrees(drag.width > 0 ? -12 : 12))
                .padding(14)
                .opacity(Double(strength))
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !flying else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !flying else { return }
                if abs(value.translation.width) >= commitDistance {
                    judge(value.translation.width > 0 ? 1 : -1)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        drag = .zero
                    }
                }
            }
    }

    private func judge(_ value: Int) {
        if reduceMotion {
            // No fling — TasteSeedView's card-change crossfade handles the transition.
            drag = .zero
            onJudge(value)
            return
        }
        flying = true
        withAnimation(.easeOut(duration: 0.25)) {
            drag = CGSize(width: value > 0 ? 640 : -640, height: drag.height * 1.5)
        } completion: {
            onJudge(value)
            drag = .zero
            flying = false
        }
    }
}
