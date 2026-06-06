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
    @State private var isApplyingReminder = false
    @State private var saveError: String?
    /// Drives the slide direction of the step transition (forward vs. back).
    @State private var goingForward = true

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.top, 16)
            Spacer(minLength: 0)
            stepContent
                .id(step)
                .transition(stepTransition)
            Spacer(minLength: 0)
            buttons.padding(.horizontal, 28).padding(.bottom, 32)
        }
        .clipped()   // keep the sliding step content from bleeding past the edges
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            if settings == nil {
                settings = SettingsViewModel(
                    notifications: env.notifications,
                    settings: env.settings,
                    syncAutomatically: false
                )
            }
            // Pre-select the reminder + streaming service from the account so a
            // returning user sees their existing choices, not the defaults.
            await settings?.loadFromCloud()
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

    @ViewBuilder private var stepContent: some View {
        switch step {
        case 0:
            OnboardingHelloStep(displayName: $displayName, avatarURL: $avatarURL)
        case 1:
            if let settings {
                OnboardingReminderStep(settings: settings)
            } else {
                onboardingStepLoader
            }
        default:
            if let settings {
                OnboardingListenStep(settings: settings)
            } else {
                onboardingStepLoader
            }
        }
    }

    private var onboardingStepLoader: some View {
        MusicLoadingView(title: nil, tint: Theme.Brand.gradient[0])
            .frame(height: 120)
    }

    /// Slide + fade: forward pushes in from the trailing edge, back from leading.
    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
            removal:   .move(edge: goingForward ? .leading  : .trailing).combined(with: .opacity)
        )
    }

    private var header: some View {
        HStack {
            backButton
            Spacer()
            progressDots
            Spacer()
            // Mirror the back button's footprint so the dots stay centered.
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder private var backButton: some View {
        if step > 0 {
            Button { goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isSaving || isApplyingReminder)
            .accessibilityLabel("Back")
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
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
            Button { primaryAction() } label: {
                Text(step == totalSteps - 1 ? "Finish" : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: Theme.Brand.gradient[0]))
            .disabled((step == 0 && !nameFilled) || isSaving || isApplyingReminder)

            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // Skip is offered only on the optional steps (2 & 3), never on step 1.
            if step > 0 {
                Button(step == totalSteps - 1 ? "Skip" : "Skip for now") { skipAction() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .disabled(isSaving || isApplyingReminder)
            }
        }
    }

    private func primaryAction() {
        guard step == 1 else {
            advance()
            return
        }
        enableReminderAndAdvance()
    }

    private func skipAction() {
        guard step == 1 else {
            advance()
            return
        }
        disableReminderAndAdvance()
    }

    private func enableReminderAndAdvance() {
        guard let settings else { return }
        saveError = nil
        isApplyingReminder = true
        Task {
            settings.reminderEnabled = true
            await settings.applyReminderSetting(enabled: true)
            isApplyingReminder = false
            if !settings.permissionDenied {
                advance()
            }
        }
    }

    private func disableReminderAndAdvance() {
        guard let settings else { return }
        saveError = nil
        isApplyingReminder = true
        Task {
            settings.reminderEnabled = false
            await settings.applyReminderSetting(enabled: false)
            isApplyingReminder = false
            advance()
        }
    }

    private func advance() {
        saveError = nil
        if step < totalSteps - 1 {
            goingForward = true
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step += 1 }
        } else {
            finish()
        }
    }

    private func goBack() {
        guard step > 0 else { return }
        saveError = nil
        goingForward = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step -= 1 }
    }

    private func finish() {
        isSaving = true
        saveError = nil
        Task {
            // Persist reminder + streaming-service choices FIRST. This settings
            // upsert creates/repairs the profiles row with the user's REAL choices,
            // so the profile save below only patches name/avatar and its seed never
            // needs to write default settings (which could otherwise replace the
            // user's picks). flush() swallows its own errors, so a settings hiccup
            // still lets onboarding finish.
            await settings?.flush()
            do {
                try await env.profileStore.save(
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                    avatarURL: avatarURL
                )
                hasCompletedOnboarding = true
                Haptics.success()   // welcome in
            } catch {
                saveError = "Couldn't save your profile. Check your connection and try again."
                #if DEBUG
                print("Onboarding finish save failed:", error)
                #endif
            }
            isSaving = false
        }
    }
}
