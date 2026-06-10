import SwiftUI

struct OnboardingReminderStep: View {
    @Bindable var settings: SettingsViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Never miss a day")
                .font(.system(size: 28, weight: .heavy, design: .rounded))

            Text("Pick when you want the daily nudge.")
                .foregroundStyle(.secondary)

            DatePicker("Reminder time", selection: $settings.reminderTime,
                       displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .glassCard(cornerRadius: 20)

            if settings.permissionDenied {
                Text("Notifications are blocked right now. You can skip for now or enable them in Settings later.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }
}
