//
//  SettingsView.swift
//  Daily Music
//
//  Account, Apple Music connect, and the daily reminder. The reminder uses real
//  local notifications; everything else is mocked for v1.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: SettingsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    SettingsForm(model: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            if model == nil { model = SettingsViewModel(notifications: env.notifications) }
            await model?.refreshPermission()
        }
    }
}

private struct SettingsForm: View {
    @Bindable var model: SettingsViewModel
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Form {
            accountSection
            appleMusicSection
            reminderSection
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if let session = env.session.session {
                LabeledContent("Signed in as", value: session.displayName ?? "You")
                if session.isGuest {
                    Label("Guest mode (debug)", systemImage: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(.secondary)
                }
                Button("Sign out", role: .destructive) {
                    Task { await env.session.signOut() }
                }
            }
        }
    }

    private var appleMusicSection: some View {
        Section {
            if model.appleMusicConnected {
                Label("Apple Music connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    Task { await model.connectAppleMusic() }
                } label: {
                    HStack {
                        Label("Connect Apple Music", systemImage: "applelogo")
                        if model.connectingAppleMusic {
                            Spacer(); ProgressView()
                        }
                    }
                }
                .disabled(model.connectingAppleMusic)
            }
        } header: {
            Text("Music")
        } footer: {
            Text("Connecting lets you add the daily song to your Daily Playlist and play full tracks.")
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Daily reminder", isOn: $model.reminderEnabled)
                .onChange(of: model.reminderEnabled) { _, enabled in
                    Task { await model.applyReminderSetting(enabled: enabled) }
                }

            if model.reminderEnabled {
                DatePicker(
                    "Time",
                    selection: $model.reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: model.reminderTime) { _, _ in
                    Task { await model.scheduleReminder() }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            if model.permissionDenied {
                Text("Notifications are turned off in iOS Settings. Enable them there to get your daily reminder.")
                    .foregroundStyle(.red)
            } else {
                Text("Get a nudge when each day's song is ready.")
            }
        }
    }
}
