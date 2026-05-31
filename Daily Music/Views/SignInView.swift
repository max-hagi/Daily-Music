//
//  SignInView.swift
//  Daily Music
//
//  The unauthenticated landing screen. v1 fakes Sign in with Apple through the
//  mock AuthService; the real ASAuthorizationAppleIDButton flow drops in here
//  later. The "Continue as guest" button is compiled into DEBUG builds only, so
//  it can never ship to the App Store.
//

import SwiftUI

struct SignInView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ZStack {
            WelcomeGradientBackground()

            VStack(spacing: 28) {
                Spacer(minLength: 32)

                VStack(spacing: Theme.Spacing.lg) {
                    MusicLoadingView(title: nil, tint: .white)
                        .padding(22)
                        .background(.white.opacity(0.18), in: Circle())
                        .overlay {
                            Circle().stroke(.white.opacity(0.35), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)

                    VStack(spacing: Theme.Spacing.sm) {
                        Text("Daily Music")
                            .font(.system(size: 46, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text("One hand-picked song a day, with a story to go with it.")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white.opacity(0.86))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task { await env.session.signInWithApple() }
                    } label: {
                        HStack {
                            if env.session.isWorking {
                                MusicLoadingView(title: nil, tint: .white)
                                    .scaleEffect(0.42)
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "applelogo")
                            }
                            Text("Sign in with Apple")
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle(tint: .black))
                    .disabled(env.session.isWorking)

                    #if DEBUG
                    Button("Continue as guest (debug)") {
                        Task { await env.session.continueAsGuest() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .disabled(env.session.isWorking)
                    #endif

                    if let error = env.session.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

struct WelcomeGradientBackground: View {
    @State private var isAnimating = false

    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.24, blue: 0.43),
                Color(red: 0.35, green: 0.25, blue: 0.95),
                Color(red: 0.0, green: 0.7, blue: 0.86),
                Color(red: 1.0, green: 0.62, blue: 0.2)
            ],
            startPoint: isAnimating ? .bottomLeading : .topLeading,
            endPoint: isAnimating ? .topTrailing : .bottomTrailing
        )
        .hueRotation(.degrees(isAnimating ? 18 : -8))
        .ignoresSafeArea()
        .overlay {
            LinearGradient(
                colors: [.white.opacity(0.24), .clear, .black.opacity(0.2)],
                startPoint: isAnimating ? .leading : .top,
                endPoint: isAnimating ? .trailing : .bottom
            )
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}
