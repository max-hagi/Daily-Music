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
    @State private var isCompletingSignIn = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0

    /// Show onboarding if it has never been completed, OR if this device last
    /// completed an older onboarding version (so a meaningful change re-prompts
    /// once — see OnboardingConfig). Incomplete onboarding re-prompts naturally
    /// because completion is only stamped in OnboardingView.finish().
    private var needsOnboarding: Bool {
        !hasCompletedOnboarding || completedOnboardingVersion < OnboardingConfig.currentVersion
    }

    var body: some View {
        // ZStack layers views back-to-front. Here only one branch is shown at a
        // time, but stacking them lets SwiftUI cross-fade between branches.
        ZStack {
            if !didRestore {
                // Phase 1: branded splash while we restore the session.
                MusicLoadingView(title: "Daily Music", tint: .white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppLoadingBackdrop())
                    .transition(.opacity)        // fade when this branch leaves
            } else if isCompletingSignIn {
                MusicLoadingView(title: "Daily Music", tint: .white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppLoadingBackdrop())
                    .transition(.opacity)
            } else if env.session.isSignedIn && needsOnboarding {
                // Phase 2a: signed in but onboarding not done (or an older version) → wizard.
                OnboardingView()
                    .transition(.opacity)
            } else if env.session.isSignedIn {
                // Phase 2b: signed in → main app. `.task` kicks off favorites +
                // profile loading once MainTabView appears.
                MainTabView()
                    .task {
                        await env.favoritesStore.load()
                        await env.profileStore.load()
                    }
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
        .animation(.spring(response: 0.7, dampingFraction: 0.85), value: needsOnboarding)
        .onChange(of: env.session.isSignedIn) { oldValue, newValue in
            guard didRestore, !oldValue, newValue else { return }
            isCompletingSignIn = true
            Haptics.success()   // signed in

            Task {
                await reconcileOnboardingState(env)
                try? await Task.sleep(for: .milliseconds(1200))
                isCompletingSignIn = false
            }
        }
        // `.task` runs this async work when RootView first appears. SwiftUI
        // automatically cancels it if the view goes away.
        .task {
            guard !didRestore else { return }    // don't re-run on later redraws
            let start = Date()
            // Resolve the session + onboarding status BEFORE routing, so a returning
            // user is never briefly shown the wizard while the profile check is still
            // in flight. Capped at 4s so a slow/offline network can't pin the splash —
            // on timeout we route with the cached value and reconcile next launch.
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [env] in await resolveLaunchState(env) }
                group.addTask { try? await Task.sleep(for: .seconds(4)) }
                await group.next()               // continue when resolution OR the cap finishes
                group.cancelAll()                // cancel the loser; in-flight network is cancellable
            }
            // Hold the branded splash for a minimum beat even if resolution was instant.
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < 1.2 { try? await Task.sleep(for: .seconds(1.2 - elapsed)) }
            didRestore = true                    // flip the flag → triggers the animated swap above
        }
        .onOpenURL { url in
            guard url.scheme == "dailymusic" else { return }
            if url.host == "friend" {
                let code = url.lastPathComponent
                if !code.isEmpty { UserDefaults.standard.set(code, forKey: "pendingFriendCode") }
            } else if url.host == "today" {
                UserDefaults.standard.set(true, forKey: "pendingTodayRoute")
            }
        }
    }

}

/// Restores the session, then reconciles the local onboarding cache against the
/// server source of truth (`profiles.onboarded_at`). A free function (no `self`) so
/// it can run inside the launch task group; it writes the cache via `UserDefaults`,
/// which the `@AppStorage("hasCompletedOnboarding")` bindings observe.
@MainActor
private func resolveLaunchState(_ env: AppEnvironment) async {
    await env.session.restore()
    await reconcileOnboardingState(env)
}

@MainActor
private func reconcileOnboardingState(_ env: AppEnvironment) async {
    guard env.session.isSignedIn,
          !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
    await env.profileStore.load()
    // If the load failed (offline) `current` is nil — leave the cache untouched so a
    // returning user isn't bounced back into onboarding.
    if let profile = env.profileStore.current {
        UserDefaults.standard.set(profile.isOnboarded, forKey: "hasCompletedOnboarding")
    }
}

private struct AppLoadingBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: isAnimating ? .bottomLeading : .topLeading,
            endPoint: isAnimating ? .topTrailing : .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            LinearGradient(
                colors: overlayColors,
                startPoint: isAnimating ? .leading : .top,
                endPoint: isAnimating ? .trailing : .bottom
            )
            .ignoresSafeArea()
        }
        .overlay {
            VStack(spacing: 18) {
                ForEach(0..<5, id: \.self) { _ in
                    Capsule(style: .continuous)
                        .fill(lineColor)
                        .frame(height: 1)
                }
            }
            .padding(.horizontal, 44)
            .rotationEffect(.degrees(-8))
            .opacity(0.5)
        }
        .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            [
                Color(red: 0.09, green: 0.052, blue: 0.064),
                Color(red: 0.18, green: 0.105, blue: 0.13),
                Color(red: 0.075, green: 0.058, blue: 0.052),
                Color(red: 0.13, green: 0.09, blue: 0.07)
            ]
        } else {
            [
                Color(red: 0.98, green: 0.38, blue: 0.5),
                Color(red: 0.56, green: 0.36, blue: 0.7),
                Color(red: 0.74, green: 0.52, blue: 0.48),
                Color(red: 0.98, green: 0.74, blue: 0.58)
            ]
        }
    }

    private var overlayColors: [Color] {
        colorScheme == .dark
            ? [.white.opacity(0.08), .clear, .black.opacity(0.28)]
            : [.white.opacity(0.24), .clear, .black.opacity(0.18)]
    }

    private var lineColor: Color {
        .white.opacity(colorScheme == .dark ? 0.08 : 0.14)
    }
}
