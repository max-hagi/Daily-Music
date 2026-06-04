//
//  OnboardingReminderStep.swift
//  Daily Music
//
//  Step 2: pick a reminder time and (optionally) turn the daily nudge on. Toggling
//  it on is the in-context moment we ask for notification permission, via the same
//  SettingsViewModel.applyReminderSetting the Settings screen uses.
//

import SwiftUI

struct OnboardingReminderStep: View {
    @Bindable var settings: SettingsViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Never miss a day")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text("A gentle nudge when the new song drops.")
                .foregroundStyle(.secondary)

            DatePicker("Reminder time", selection: $settings.reminderTime,
                       displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Toggle("Daily reminder", isOn: $settings.reminderEnabled)
                .padding(.horizontal)
                .onChange(of: settings.reminderEnabled) { _, on in
                    Task { await settings.applyReminderSetting(enabled: on) }
                }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }
}
