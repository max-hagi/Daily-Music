//
//  RootView.swift
//  Daily Music
//
//  The auth gate. Restores any existing session on launch, then shows either the
//  sign-in screen or the main tabs. Also loads favorites once signed in.
//

import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var didRestore = false

    var body: some View {
        ZStack {
            if !didRestore {
                MusicLoadingView(title: "Daily Music", tint: Theme.Brand.gradient[2])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WelcomeGradientBackground())
                    .transition(.opacity)
            } else if env.session.isSignedIn {
                MainTabView()
                    .task { await env.favoritesStore.load() }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                SignInView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 1.08).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.65, dampingFraction: 0.86), value: didRestore)
        .animation(.spring(response: 0.75, dampingFraction: 0.84), value: env.session.isSignedIn)
        .task {
            guard !didRestore else { return }
            // Keep the branded launch animation on screen long enough to be seen,
            // even when session restore returns instantly (cached session).
            let start = ContinuousClock.now
            await env.session.restore()
            let minimum = Duration.seconds(1.7)
            let elapsed = start.duration(to: .now)
            if elapsed < minimum {
                try? await Task.sleep(for: minimum - elapsed)
            }
            didRestore = true
        }
    }
}
