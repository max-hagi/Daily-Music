//
//  MusicLoadingView.swift
//  Daily Music
//
//  A small music-themed loading indicator used while the app is getting ready.
//

import SwiftUI

struct MusicLoadingView: View {
    var title: String? = "Daily Music"
    var tint: Color = .accentColor

    @State private var isAnimating = false

    private let barHeights: [CGFloat] = [18, 30, 24, 36, 22]

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(barHeights.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: 8, height: barHeights[index])
                        .scaleEffect(y: isAnimating ? 0.45 : 1, anchor: .bottom)
                        .animation(
                            .easeInOut(duration: 0.58)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.09),
                            value: isAnimating
                        )
                }
            }
            .frame(height: 44)
            .accessibilityHidden(true)

            if let title {
                Text(title)
                    .font(.dmHeadline())
                    .foregroundStyle(.primary)
            }
        }
        .onAppear { isAnimating = true }
    }
}
