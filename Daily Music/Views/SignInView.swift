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
import Combine

struct SignInView: View {
    @Environment(AppEnvironment.self) private var env
    // Real album covers (read from the public catalogue) for the montage backdrop.
    @State private var artURLs: [URL] = []

    var body: some View {
        ZStack {
            // A montage of real covers when we have them; the animated gradient is
            // the graceful fallback while they load (or if the fetch fails).
            if artURLs.isEmpty {
                WelcomeGradientBackground()
            } else {
                AlbumArtMontage(urls: artURLs)
            }

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
                        // Kick off async sign-in. The Button action itself is sync,
                        // so wrap the await in a Task.
                        Task { await env.session.signInWithApple() }
                    } label: {
                        HStack {
                            // Swap the Apple logo for the bouncing-bars spinner while
                            // a sign-in is in flight (isWorking is observed → live).
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
                    .buttonStyle(PrimaryActionButtonStyle(tint: .black))   // our custom style from Styles.swift
                    .disabled(env.session.isWorking)   // prevent double-taps mid-request

                    // `#if DEBUG` is a COMPILE-TIME flag: this button only exists in
                    // debug builds, so the guest bypass can never ship to the App Store.
                    #if DEBUG
                    Button("Continue as guest (debug)") {
                        Task { await env.session.continueAsGuest() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .disabled(env.session.isWorking)
                    #endif

                    // Conditionally show an error message if sign-in failed.
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
        .task { await loadArt() }
    }

    /// Pull a handful of real covers from the public catalogue for the montage.
    private func loadArt() async {
        let entries = (try? await env.entries.publishedHistory()) ?? []
        artURLs = Array(entries.compactMap(\.albumArtURL).prefix(10))
    }
}

// Cross-fades through real album covers behind a dark scrim, with a slow
// Ken-Burns drift — a living preview of what the user will discover.
struct AlbumArtMontage: View {
    let urls: [URL]
    @State private var index = 0
    @State private var zoomIn = false

    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black

            ForEach(Array(urls.enumerated()), id: \.offset) { offset, url in
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.black
                }
                .scaleEffect(zoomIn ? 1.18 : 1.04)
                .blur(radius: 6)
                .opacity(offset == index ? 1 : 0)
                .animation(.easeInOut(duration: 1.4), value: index)
            }

            // Dark scrim so the white welcome content stays readable.
            LinearGradient(
                colors: [.black.opacity(0.35), .black.opacity(0.55), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                zoomIn = true
            }
        }
        .onReceive(timer) { _ in
            guard !urls.isEmpty else { return }
            index = (index + 1) % urls.count
        }
    }
}

// The animated, color-shifting backdrop used on the splash + sign-in screens.
// Reused (not duplicated) so both screens match.
struct WelcomeGradientBackground: View {
    @State private var isAnimating = false

    var body: some View {
        // A diagonal gradient. The start/end POINTS swap based on isAnimating, so
        // toggling it makes the gradient slowly sweep across the screen.
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
        .hueRotation(.degrees(isAnimating ? 18 : -8))   // also drift the hue for shimmer
        .ignoresSafeArea()   // extend under the notch / home indicator, full-bleed
        .overlay {
            // A second gradient layered on top adds a soft light/shadow sheen.
            LinearGradient(
                colors: [.white.opacity(0.24), .clear, .black.opacity(0.2)],
                startPoint: isAnimating ? .leading : .top,
                endPoint: isAnimating ? .trailing : .bottom
            )
            .ignoresSafeArea()
        }
        // Slow, infinitely reversing animation tied to isAnimating → endless drift.
        .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}
