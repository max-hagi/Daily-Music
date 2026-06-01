//
//  MusicLoadingView.swift
//  Daily Music
//
//  A music-themed loading indicator. The bars flow continuously off a sine wave
//  (each offset by a phase) driven by TimelineView(.animation), so it reads as a
//  smooth travelling equalizer rather than a discrete on/off bounce.
//

import SwiftUI

struct MusicLoadingView: View {
    var title: String? = "Daily Music"
    var tint: Color = .accentColor

    private let barCount = 5
    private let maxHeight: CGFloat = 40
    private let minHeight: CGFloat = 10

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // TimelineView(.animation) re-renders every frame, handing us the current
            // time. We derive each bar's height from a sine wave of that time, so the
            // motion is continuous — no two-state snapping.
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                HStack(alignment: .center, spacing: 6) {
                    ForEach(0..<barCount, id: \.self) { index in
                        Capsule()
                            .fill(tint.gradient)
                            .frame(width: 7, height: height(at: index, time: t))
                    }
                }
                .frame(height: maxHeight)
            }
            .frame(height: maxHeight)
            .accessibilityHidden(true)   // decorative — hide from VoiceOver

            if let title {
                Text(title)
                    .font(.dmHeadline())
                    .foregroundStyle(.primary)
            }
        }
    }

    // Each bar is the same sine wave offset by its index, producing a wave that
    // travels across the row. (sin → −1...1, remapped to minHeight...maxHeight.)
    private func height(at index: Int, time: Double) -> CGFloat {
        let speed = 3.2
        let phase = Double(index) * 0.6
        let wave = (sin(time * speed + phase) + 1) / 2 // 0...1
        return minHeight + wave * (maxHeight - minHeight)
    }
}
