//
//  SignInView.swift
//  Daily Music
//
//  The unauthenticated landing screen. The only shipping sign-in path is email
//  (a real Supabase OTP account). Real Sign in with Apple needs the paid-account
//  entitlement and will be added back here once that's available — until then we
//  do NOT show a fake Apple button, since a non-functional one fails App Review.
//  The "Continue as guest" button is compiled into DEBUG builds only, so anonymous
//  sessions can never ship to the App Store.
//

import SwiftUI

struct SignInView: View {
    @Environment(AppEnvironment.self) private var env
    // Real album covers (read from the public catalogue) for the montage backdrop.
    @State private var artURLs: [URL] = []
    @State private var showingEmail = false

    var body: some View {
        ZStack {
            // A wall of real covers when we have them; the animated gradient is
            // the graceful fallback while they load (or if the fetch fails).
            if artURLs.isEmpty {
                WelcomeGradientBackground()
            } else {
                AlbumArtGridBackdrop(urls: artURLs)
            }

            VStack(spacing: 24) {
                Spacer(minLength: 28)

                VStack(spacing: Theme.Spacing.md) {
                    MusicLoadingView(title: nil, tint: .white)
                        .padding(20)
                        .background(.white.opacity(0.18), in: Circle())
                        .overlay {
                            Circle().stroke(.white.opacity(0.35), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)

                    VStack(spacing: Theme.Spacing.sm) {
                        Text("Daily Music")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text("One hand-picked song a day, with a story to go with it.")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showingEmail = true
                    } label: {
                        Label("Continue with email", systemImage: "envelope.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle(tint: Theme.Brand.gradient[0]))
                    .disabled(env.session.isWorking)   // prevent double-taps mid-request

                    // NOTE: The real "Sign in with Apple" button goes here once the
                    // paid-account entitlement is set up. It must use ASAuthorization
                    // (SignInWithAppleButton) and link to the Supabase user — not the
                    // current anonymous placeholder. A fake Apple button fails review,
                    // so nothing is shown until the real flow exists.

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
        .sheet(isPresented: $showingEmail) {
            EmailSignInSheet()
        }
    }

    /// Pull real covers from the current entry source for the moving cover wall.
    private func loadArt() async {
        let entries = (try? await env.entries.publishedHistory()) ?? []
        artURLs = Array(entries.compactMap(\.albumArtURL).prefix(24))
    }
}

// A slowly panning cover wall. Each tile stays readable; the motion comes from
// moving the whole grid, not zooming a single cover past recognition.
struct AlbumArtGridBackdrop: View {
    let urls: [URL]
    @State private var isPanning = false

    private var repeatedURLs: [URL] {
        guard !urls.isEmpty else { return [] }
        let repeats = max(3, Int(ceil(Double(48) / Double(urls.count))))
        return Array(repeating: urls, count: repeats).flatMap { $0 }
    }

    var body: some View {
        GeometryReader { proxy in
            let tile = max(92, min(proxy.size.width / 3.2, 132))
            let columns = max(4, Int(ceil(proxy.size.width / tile)) + 2)
            let gridItems = Array(repeating: GridItem(.fixed(tile), spacing: 10), count: columns)

            ZStack {
                AlbumWallStageBackground()

                LazyVGrid(columns: gridItems, spacing: 10) {
                    ForEach(Array(repeatedURLs.enumerated()), id: \.offset) { _, url in
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.white.opacity(0.14))
                        }
                        .frame(width: tile, height: tile)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(.white.opacity(0.16), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.24), radius: 10, y: 6)
                    }
                }
                .frame(width: CGFloat(columns) * tile + CGFloat(columns - 1) * 10)
                .rotationEffect(.degrees(-8))
                .scaleEffect(1.08)
                .offset(x: isPanning ? -72 : 18, y: isPanning ? -118 : -34)
                .opacity(0.82)
                .animation(.easeInOut(duration: 18).repeatForever(autoreverses: true), value: isPanning)

                LinearGradient(
                    colors: [
                        .black.opacity(0.25),
                        .black.opacity(0.5),
                        .black.opacity(0.86)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay {
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.26)],
                        center: .center,
                        startRadius: 80,
                        endRadius: 360
                    )
                }
            }
            .ignoresSafeArea()
            .onAppear { isPanning = true }
        }
        .ignoresSafeArea()
    }
}

struct AlbumWallStageBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.025, blue: 0.035),
                    Color(red: 0.055, green: 0.045, blue: 0.07),
                    Color(red: 0.015, green: 0.035, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.95, green: 0.24, blue: 0.43).opacity(0.32),
                    .clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Color(red: 0.0, green: 0.62, blue: 0.74).opacity(0.24),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 60,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
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
