//
//  MusicLoadingView.swift
//  Daily Music
//
//  A music-themed loading indicator. The bars flow continuously off a sine wave
//  for a smooth equalizer motion.
//

import SwiftUI

struct MusicLoadingView: View {
    var title: String? = "Daily Music"
    var tint: Color = .accentColor

    @Environment(\.colorScheme) private var colorScheme

    private let barCount = 5
    private let maxHeight: CGFloat = 42
    private let minHeight: CGFloat = 12

    var body: some View {
        equalizer
            .frame(width: 76, height: maxHeight)
            .padding(title == nil ? 0 : 22)
            .background {
                if title != nil {
                    glassBadge
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title ?? "Loading")
    }

    private var equalizer: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            HStack(alignment: .center, spacing: 7) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(barStyle)
                        .frame(width: 8, height: height(at: index, time: time))
                        .opacity(opacity(at: index, time: time))
                }
            }
            .frame(height: maxHeight)
        }
        .accessibilityHidden(true)
    }

    private var glassBadge: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay {
                Circle()
                    .fill(.white.opacity(colorScheme == .dark ? 0.08 : 0.18))
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.42), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .padding(1)
                    .blendMode(.screen)
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(colorScheme == .dark ? 0.28 : 0.44), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.2), radius: 28, y: 14)
    }

    private var barStyle: LinearGradient {
        LinearGradient(
            colors: [
                tint.opacity(colorScheme == .dark ? 0.98 : 0.94),
                tint.opacity(colorScheme == .dark ? 0.58 : 0.68)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func height(at index: Int, time: Double) -> CGFloat {
        let speed = 3.15
        let phase = Double(index) * 0.62
        let wave = (sin(time * speed + phase) + 1) / 2
        return minHeight + wave * (maxHeight - minHeight)
    }

    private func opacity(at index: Int, time: Double) -> Double {
        let phase = Double(index) * 0.62
        let wave = (sin(time * 3.15 + phase) + 1) / 2
        return 0.68 + wave * 0.32
    }
}
