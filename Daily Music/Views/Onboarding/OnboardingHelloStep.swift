//
//  OnboardingHelloStep.swift
//  Daily Music
//
//  Step 1 of onboarding: the identity step. Name is required (the wizard's
//  Continue button enforces it); the photo is optional (initials default).
//

import SwiftUI

struct OnboardingHelloStep: View {
    @Binding var displayName: String
    @Binding var avatarURL: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Say hello 👋")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text("What should we call you?")
                .foregroundStyle(.secondary)
            ProfileEditor(displayName: $displayName, avatarURL: $avatarURL, nameRequired: true)
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }
}
