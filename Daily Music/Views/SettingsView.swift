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
    // @Bindable lets us make two-way BINDINGS ($model.reminderEnabled) to an
    // @Observable object's properties — needed for Toggle/DatePicker which write
    // back. (The parent owns the model; this view just binds to it.)
    @Bindable var model: SettingsViewModel
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        // `Form` renders the grouped, inset settings-style list automatically.
        Form {
            accountSection
            appleMusicSection
            reminderSection
        }
    }

    private var accountSection: some View {
        // A Section groups related rows under a header.
        Section("Account") {
            if let session = env.session.session {
                // LabeledContent = a "label … value" row.
                LabeledContent("Signed in as", value: session.displayName ?? "You")
                if session.isGuest {
                    Label("Guest mode (debug)", systemImage: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(.secondary)
                }
                // `role: .destructive` paints the button red (system convention).
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
        // This Section uses the explicit header:/footer: form (vs the string shorthand).
        Section {
            // `isOn: $model.reminderEnabled` — the `$` makes a two-way binding so the
            // toggle reads AND writes the property. `.onChange` then runs side effects
            // (request permission + (re)schedule) whenever the value flips. The closure
            // gets (oldValue, newValue); we ignore the old one with `_`.
            Toggle("Daily reminder", isOn: $model.reminderEnabled)
                .onChange(of: model.reminderEnabled) { _, enabled in
                    Task { await model.applyReminderSetting(enabled: enabled) }
                }

            // Only reveal the time picker when the reminder is on.
            if model.reminderEnabled {
                DatePicker(
                    "Time",
                    selection: $model.reminderTime,
                    displayedComponents: .hourAndMinute   // time only, no date
                )
                .onChange(of: model.reminderTime) { _, _ in
                    Task { await model.scheduleReminder() }   // reschedule at the new time
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
