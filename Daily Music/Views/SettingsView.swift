//
//  SettingsView.swift
//  Daily Music
//
//  Account, music connection, reminders, local preferences, sharing defaults,
//  and support/about controls for the app.
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
                    MusicLoadingView(title: nil, tint: Theme.Brand.gradient[0])
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            if model == nil {
                model = SettingsViewModel(notifications: env.notifications, settings: env.settings)
            }
            await model?.refreshPermission()
            await model?.loadFromCloud()
            await env.profileStore.load()
        }
    }
}

private enum SettingsNavSection: String, CaseIterable, Identifiable {
    case account
    case music
    case preferences
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: "Account"
        case .music: "Music"
        case .preferences: "Prefs"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .account: "person.crop.circle"
        case .music: "music.note.list"
        case .preferences: "slider.horizontal.3"
        case .about: "info.circle"
        }
    }
}

private struct SettingsForm: View {
    @Bindable var model: SettingsViewModel
    @Environment(AppEnvironment.self) private var env
    @State private var showingResetConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedSection: SettingsNavSection = .account
    @State private var showingEditProfile = false
    #if DEBUG
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0
    #endif

    var body: some View {
        Form {
            currentSections
        }
        .sheet(isPresented: $showingEditProfile) { ProfileEditView() }
        .safeAreaInset(edge: .bottom) {
            settingsBottomBar
        }
        .confirmationDialog(
            "Reset local settings?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Settings", role: .destructive) {
                Task { await model.resetLocalPreferences() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This resets reminder, sharing, and personalization preferences on this device. Your account, favorites, and check-ins are not deleted.")
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await env.session.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all your data — favorites, reactions, check-ins, and preferences. This can't be undone.")
        }
    }

    @ViewBuilder
    private var currentSections: some View {
        switch selectedSection {
        case .account:
            profileSection
        case .music:
            musicSection
            reminderSection
        case .preferences:
            dailyExperienceSection
            personalizationSection
            sharingSection
        case .about:
            supportSection
            appSection
            accountManagementSection
            #if DEBUG
            developerSection
            #endif
        }
    }

    private var settingsBottomBar: some View {
        HStack(spacing: 8) {
            ForEach(SettingsNavSection.allCases) { section in
                Button {
                    withAnimation(.spring(duration: 0.28)) {
                        selectedSection = section
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: section.symbol)
                            .font(.system(size: 16, weight: .semibold))
                        Text(section.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(selectedSection == section ? .primary : .secondary)
                    .background {
                        if selectedSection == section {
                            Capsule()
                                .fill(Theme.Brand.gradient[0].opacity(0.18))
                                .glassEffect(
                                    .regular.tint(Theme.Brand.gradient[0]).interactive(),
                                    in: Capsule()
                                )
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var profileName: String {
        let name = env.profileStore.current?.displayName ?? ""
        return name.isEmpty ? "Set your name" : name
    }

    @ViewBuilder private var profileAvatar: some View {
        if let s = env.profileStore.current?.avatarURL, let url = URL(string: s) {
            AsyncImage(url: url) { image in image.resizable().scaledToFill() }
                placeholder: { InitialsAvatar(name: env.profileStore.current?.displayName, size: 48) }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
        } else {
            InitialsAvatar(name: env.profileStore.current?.displayName, size: 48)
        }
    }

    private var profileSection: some View {
        Section {
            if let session = env.session.session {
                Button {
                    showingEditProfile = true
                } label: {
                    HStack(spacing: 14) {
                        profileAvatar
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profileName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(session.isGuest ? "Guest · Edit profile" : "Edit profile")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .tint(.primary)

                Button {
                    Task { await env.session.signOut() }
                } label: {
                    HStack {
                        Text("Sign out")
                        if env.session.isWorking {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(env.session.isWorking)
            } else {
                Label("Signed out", systemImage: "person.crop.circle.badge.xmark")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Account")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if let error = env.session.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                }
                if env.session.session?.isGuest == true {
                    Text("Guest mode is for development. Favorites and check-ins still use the current Supabase session while you test.")
                }
            }
        }
    }

    private var musicSection: some View {
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
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(model.connectingAppleMusic)
            }

            Picker("Default streaming service", selection: $model.preferredStreamingService) {
                ForEach(StreamingService.allCases) { service in
                    Text(service.displayName).tag(service)
                }
            }
        } header: {
            Text("Music")
        } footer: {
            Text("MusicKit will unlock library saves and richer playback once the Apple Music entitlement is enabled.")
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

            Toggle("Weekly recap", isOn: $model.weeklyRecapEnabled)
        } header: {
            Text("Notifications")
        } footer: {
            if model.permissionDenied {
                Text("Notifications are turned off in iOS Settings. Enable them there to get your daily reminder.")
                    .foregroundStyle(.red)
            } else {
                Text("Get a nudge when the daily song is ready and a light recap of what you saved each week.")
            }
        }
    }

    private var dailyExperienceSection: some View {
        Section {
            Picker("Open app to", selection: $model.startTab) {
                ForEach(SettingsViewModel.StartTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }

            Toggle("Haptic feedback", isOn: $model.hapticsEnabled)
        } header: {
            Text("Daily Experience")
        } footer: {
            Text("These preferences are saved now so the app can wire them into launch and interaction behavior later.")
        }
    }

    private var personalizationSection: some View {
        Section {
            Picker("Discovery style", selection: $model.listeningMode) {
                ForEach(SettingsViewModel.ListeningMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            Toggle("Personalized insights", isOn: $model.allowPersonalizedInsights)
            Toggle("Allow explicit songs", isOn: $model.showExplicitSongs)
        } header: {
            Text("Personalization")
        } footer: {
            Text("Daily Music is curated, but these preferences give future recommendations and archetypes a clearer signal.")
        }
    }

    private var sharingSection: some View {
        Section {
            Toggle("Include journal quote", isOn: $model.includeJournalInShares)
            Toggle("Include Daily Music mark", isOn: $model.includeWatermarkInShares)
        } header: {
            Text("Sharing")
        } footer: {
            Text("Choose what appears on generated share cards by default.")
        }
    }

    private var supportSection: some View {
        Section("Support") {
            Link(destination: URL(string: "mailto:support@dailymusic.app?subject=Daily%20Music%20Feedback")!) {
                Label("Send feedback", systemImage: "envelope")
            }

            Link(destination: URL(string: "https://dailymusic.app/privacy")!) {
                Label("Privacy policy", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://dailymusic.app/terms")!) {
                Label("Terms of service", systemImage: "doc.text")
            }
        }
    }

    private var appSection: some View {
        Section {
            LabeledContent("Version", value: model.appVersion)

            Button("Reset local settings", role: .destructive) {
                showingResetConfirmation = true
            }
        } header: {
            Text("App")
        } footer: {
            Text("Resetting local settings does not remove your account, favorites, check-ins, or Supabase data.")
        }
    }

    private var accountManagementSection: some View {
        Section {
            if env.session.session != nil {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Text("Delete account")
                        if env.session.isWorking {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(env.session.isWorking)
            } else {
                Label("No signed-in account", systemImage: "person.crop.circle.badge.xmark")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Account Management")
        } footer: {
            Text("Deleting your account permanently removes your profile, favorites, reactions, check-ins, and preferences.")
        }
    }

    #if DEBUG
    private var developerSection: some View {
        Section {
            Button("Reset onboarding", role: .destructive) {
                resetOnboarding()
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("DEBUG only. Clears the local onboarding flags (completion, version, taste-seed, memento, first-listen) and drops you back into the wizard. Doesn't touch the server onboarded_at — the version gate re-triggers locally.")
        }
    }

    /// Wipes the on-device onboarding state so the wizard re-appears. `completedOnboardingVersion = 0`
    /// is the dependable trigger (it survives the launch reconcile, unlike hasCompletedOnboarding).
    private func resetOnboarding() {
        SeedRatings.clear()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "startingMood")
        defaults.removeObject(forKey: "startingGenre")
        defaults.removeObject(forKey: "startingDecade")
        defaults.removeObject(forKey: "heardEntryID")
        completedOnboardingVersion = 0
        hasCompletedOnboarding = false   // flips RootView's gate → onboarding shows
    }
    #endif
}
