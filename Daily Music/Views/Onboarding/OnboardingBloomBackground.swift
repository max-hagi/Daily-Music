//
//  OnboardingBloomBackground.swift
//  Daily Music
//
//  The onboarding backdrop: 3 large blurred color blobs drifting slowly over an
//  adaptive base (near-white in light mode, near-black in dark / forceDark).
//  Changing `palette` crossfades the blob colors — callers animate step changes
//  by wrapping the palette change in withAnimation. Respects Reduce Motion
//  (no drift; palette crossfades still work).
//

import SwiftUI

struct OnboardingBloomBackground: View {
    /// Blob colors; cycled if fewer than 3. Animatable via the fills.
    var palette: [Color]
    /// Force the dark base regardless of system setting (used while rating,
    /// where the chrome is white-on-dark).
    var forceDark = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    private var isDark: Bool { forceDark || scheme == .dark }

    var body: some View {
        ZStack {
            (isDark ? Color(red: 0.05, green: 0.05, blue: 0.08)
                    : Color(red: 0.99, green: 0.99, blue: 1.0))
                .ignoresSafeArea()
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    blob(color(0), size: w * 1.1)
                        .position(x: drift ? w * 0.20 : w * 0.05,
                                  y: drift ? h * 0.05 : h * 0.18)
                    blob(color(1), size: w * 0.95)
                        .position(x: drift ? w * 0.85 : w * 1.00,
                                  y: drift ? h * 0.30 : h * 0.10)
                    blob(color(2), size: w * 1.25)
                        .position(x: drift ? w * 0.60 : w * 0.35,
                                  y: drift ? h * 1.00 : h * 0.88)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func color(_ i: Int) -> Color {
        palette.isEmpty ? Theme.Brand.gradient[0] : palette[i % palette.count]
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 80)
            .opacity(isDark ? 0.38 : 0.55)
    }
}

#Preview("Light") {
    OnboardingBloomBackground(palette: [.purple, .cyan, .pink])
}

#Preview("Force dark") {
    OnboardingBloomBackground(palette: [.orange, .pink, .yellow], forceDark: true)
}
