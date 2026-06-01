//
//  RootView.swift
//  Daily Music
//
//  The auth gate. Restores any existing session on launch, then shows either the
//  sign-in screen or the main tabs. Also loads favorites once signed in.
//

import SwiftUI

struct RootView: View {
    // Pull the container back out of the environment that Daily_MusicApp injected.
    @Environment(AppEnvironment.self) private var env
    // Local UI flag owned by this view: have we finished restoring the session?
    // Drives the splash → content swap. @State because the view mutates it.
    @State private var didRestore = false

    var body: some View {
        // ZStack layers views back-to-front. Here only one branch is shown at a
        // time, but stacking them lets SwiftUI cross-fade between branches.
        ZStack {
            if !didRestore {
                // Phase 1: branded splash while we restore the session.
                MusicLoadingView(title: "Daily Music", tint: Theme.Brand.gradient[2])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WelcomeGradientBackground())
                    .transition(.opacity)        // fade when this branch leaves
            } else if env.session.isSignedIn {
                // Phase 2a: signed in → main app. `.task` kicks off favorites
                // loading once MainTabView appears (and cancels if it leaves).
                MainTabView()
                    .task { await env.favoritesStore.load() }
                    // Asymmetric transition: different animation for appearing
                    // (insertion) vs disappearing (removal).
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                // Phase 2b: not signed in → welcome / sign-in screen.
                SignInView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 1.08).combined(with: .opacity)
                    ))
            }
        }
        // These `.animation(value:)` modifiers say: whenever `didRestore` or
        // `isSignedIn` changes, animate the resulting view swap with this spring.
        .animation(.spring(response: 0.65, dampingFraction: 0.86), value: didRestore)
        .animation(.spring(response: 0.75, dampingFraction: 0.84), value: env.session.isSignedIn)
        // `.task` runs this async work when RootView first appears. SwiftUI
        // automatically cancels it if the view goes away.
        .task {
            guard !didRestore else { return }    // don't re-run on later redraws
            // Keep the branded launch animation on screen long enough to be seen,
            // even when session restore returns instantly (cached session).
            let start = ContinuousClock.now      // monotonic clock for measuring elapsed time
            await env.session.restore()          // suspends here until restore finishes
            let minimum = Duration.seconds(1.7)
            let elapsed = start.duration(to: .now)
            if elapsed < minimum {
                // Pad out the splash so it's not a jarring flash. `try?` because
                // sleep can throw on cancellation; we don't care if it does.
                try? await Task.sleep(for: minimum - elapsed)
            }
            didRestore = true                    // flip the flag → triggers the animated swap above
        }
    }
}
