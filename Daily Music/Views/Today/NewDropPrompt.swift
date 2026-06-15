//
//  NewDropPrompt.swift
//  Daily Music
//
//  The in-app "your song of the day is ready" card that replaces the auto-opening
//  ceremony. Blind by design — the song stays hidden so tapping Listen is still a
//  reveal. Listen opens the player; Maybe later drops to the (uncollected) song zone.
//

import SwiftUI

struct NewDropPrompt: View {
    let dateText: String
    let onListen: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { onDismiss() }
                .accessibilityHidden(true)   // VoiceOver dismisses via the "Maybe later" button

            VStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle().fill(.white.opacity(0.12))
                        .frame(width: 76, height: 76)
                        .scaleEffect(pulse && !reduceMotion ? 1.12 : 0.96)
                    Image(systemName: "music.note")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)   // decorative

                VStack(spacing: 6) {
                    Text(dateText.uppercased())
                        .font(.caption.weight(.heavy)).tracking(2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Your song of the day is ready")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text("Hear it first — listen all the way to collect it.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                Button(action: onListen) {
                    Label("Listen", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(tint: Theme.Brand.gradient[0]))

                Button("Maybe later", action: onDismiss)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 2)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
