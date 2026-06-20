//
//  FriendReactionBubbles.swift
//  Daily Music
//
//  Floating friend-reaction bubbles pinned around the Today sleeve. Each bubble
//  is a friend avatar + their verdict emoji (❤️ loved / 👎 passed). Caps at a few
//  visible bubbles with a "+N" overflow so it never clutters the hero. Intended
//  to be placed in an overlay sized to the cover; see EntryDetailImmersive.
//

import SwiftUI

struct FriendReactionBubbles: View {
    let reactions: [FriendReaction]
    var maxVisible = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    // Anchor each bubble to a corner of the cover, nudged slightly outward.
    private let anchors: [(Alignment, CGSize)] = [
        (.topTrailing,   CGSize(width: 14,  height: -12)),
        (.bottomLeading, CGSize(width: -16, height: 14)),
        (.bottomTrailing,CGSize(width: 12,  height: 18)),
        (.topLeading,    CGSize(width: -12, height: -10))
    ]

    var body: some View {
        let split = BubbleLayout.split(reactions, maxVisible: maxVisible)
        ZStack {
            ForEach(Array(split.shown.enumerated()), id: \.element.id) { index, reaction in
                let anchor = anchors[index % anchors.count]
                bubble(reaction)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: anchor.0)
                    .offset(anchor.1)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        reduceMotion ? nil
                        : .spring(response: 0.45, dampingFraction: 0.6)
                            .delay(0.06 * Double(index)),
                        value: appeared)
            }

            if split.overflow > 0 {
                overflowBubble(split.overflow)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: 26)
                    .opacity(appeared ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut.delay(0.28), value: appeared)
            }
        }
        .allowsHitTesting(false)
        .onAppear { appeared = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(split))
    }

    private func bubble(_ reaction: FriendReaction) -> some View {
        HStack(spacing: 5) {
            InitialsAvatar(name: reaction.friend.displayName, size: 26)
            Text(reaction.verdict.emoji).font(.system(size: 13))
        }
        .padding(3)
        .padding(.trailing, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    private func overflowBubble(_ count: Int) -> some View {
        Text("+\(count)")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    private func accessibilitySummary(_ split: (shown: [FriendReaction], overflow: Int)) -> String {
        let parts = split.shown.map { "\($0.friend.displayName ?? "A friend") \($0.verdict.feedVerb) this" }
        let extra = split.overflow > 0 ? " and \(split.overflow) more" : ""
        return parts.joined(separator: ", ") + extra
    }
}
