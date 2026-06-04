//
//  OnboardingView.swift
//  Daily Music
//
//  The 3-step wizard. Name is required (Continue is disabled on step 1 until it's
//  filled); the photo and steps 2–3 are skippable. Steps 2–3 persist live via a
//  shared SettingsViewModel; the name+avatar are saved on Finish. Completion flips
//  @AppStorage("hasCompletedOnboarding"), which RootView watches.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var step = 0
    @State private var displayName = ""
    @State private var avatarURL: String?
    @State private var settings: SettingsViewModel?
    @State private var isSaving = false

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            progressDots.padding(.top, 24)
            Spacer(minLength: 0)
            Group {
                switch step {
                case 0:
                    OnboardingHelloStep(displayName: $displayName, avatarURL: $avatarURL)
                case 1:
                    if let settings { OnboardingReminderStep(settings: settings) }
                default:
                    if let settings { OnboardingListenStep(settings: settings) }
                }
            }
            Spacer(minLength: 0)
            buttons.padding(.horizontal, 28).padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            if settings == nil {
                settings = SettingsViewModel(notifications: env.notifications, settings: env.settings)
            }
            await env.profileStore.load()
            if let c = env.profileStore.current {
                displayName = c.displayName ?? ""
                avatarURL = c.avatarURL
            }
        }
    }

    private var nameFilled: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Theme.Brand.gradient[0] : Color.secondary.opacity(0.3))
                    .frame(width: i == step ? 18 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
    }

    private var buttons: some View {
        VStack(spacing: 6) {
            Button { advance() } label: {
                Text(step == totalSteps - 1 ? "Finish" : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: Theme.Brand.gradient[0]))
            .disabled((step == 0 && !nameFilled) || isSaving)

            // Skip is offered only on the optional steps (2 & 3), never on step 1.
            if step > 0 {
                Button(step == totalSteps - 1 ? "Skip" : "Skip for now") { advance() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .disabled(isSaving)
            }
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation { step += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        isSaving = true
        Task {
            try? await env.profileStore.save(
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                avatarURL: avatarURL
            )
            isSaving = false
            hasCompletedOnboarding = true
        }
    }
}
