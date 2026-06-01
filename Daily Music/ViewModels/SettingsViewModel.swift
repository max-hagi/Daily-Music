//
//  SettingsViewModel.swift
//  Daily Music
//
//  Drives the Settings screen: reminders, local app preferences, and the Apple
//  Music connect state. Reminder and preference choices persist in UserDefaults
//  so they survive relaunch.
//

import Foundation
import UserNotifications

@MainActor
@Observable
final class SettingsViewModel {
    enum ListeningMode: String, CaseIterable, Identifiable {
        case balanced = "Balanced"
        case familiar = "Familiar"
        case adventurous = "Adventurous"

        var id: String { rawValue }
    }

    enum StartTab: String, CaseIterable, Identifiable {
        case today = "Today"
        case vault = "Vault"
        case insights = "Insights"

        var id: String { rawValue }
    }

    // Each preference writes to UserDefaults (instant local cache + offline) AND
    // schedules a debounced sync to Supabase (the synced source of truth).
    var reminderEnabled = false {
        didSet { defaults.set(reminderEnabled, forKey: Keys.reminderEnabled); scheduleSync() }
    }

    var reminderTime: Date {
        didSet { defaults.set(reminderTime, forKey: Keys.reminderTime); scheduleSync() }
    }

    var listeningMode: ListeningMode = .balanced {
        didSet { defaults.set(listeningMode.rawValue, forKey: Keys.listeningMode); scheduleSync() }
    }

    var startTab: StartTab = .today {
        didSet { defaults.set(startTab.rawValue, forKey: Keys.startTab); scheduleSync() }
    }

    var hapticsEnabled = true {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled); scheduleSync() }
    }

    var showExplicitSongs = true {
        didSet { defaults.set(showExplicitSongs, forKey: Keys.showExplicitSongs); scheduleSync() }
    }

    var allowPersonalizedInsights = true {
        didSet { defaults.set(allowPersonalizedInsights, forKey: Keys.allowPersonalizedInsights); scheduleSync() }
    }

    var includeJournalInShares = true {
        didSet { defaults.set(includeJournalInShares, forKey: Keys.includeJournalInShares); scheduleSync() }
    }

    var includeWatermarkInShares = true {
        didSet { defaults.set(includeWatermarkInShares, forKey: Keys.includeWatermarkInShares); scheduleSync() }
    }

    var weeklyRecapEnabled = true {
        didSet { defaults.set(weeklyRecapEnabled, forKey: Keys.weeklyRecapEnabled); scheduleSync() }
    }

    private(set) var permissionDenied = false
    private(set) var appleMusicConnected = false
    private(set) var connectingAppleMusic = false

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private let notifications: NotificationService
    private let settingsService: SettingsService
    private let defaults = UserDefaults.standard
    /// Debounce handle for the cloud save, and a guard so applying a remote load
    /// doesn't immediately echo back as a save.
    private var syncTask: Task<Void, Never>?
    private var isApplyingRemote = false

    private enum Keys {
        static let reminderEnabled = "reminderEnabled"
        static let reminderTime = "reminderTime"
        static let listeningMode = "settings.listeningMode"
        static let startTab = "settings.startTab"
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let showExplicitSongs = "settings.showExplicitSongs"
        static let allowPersonalizedInsights = "settings.allowPersonalizedInsights"
        static let includeJournalInShares = "settings.includeJournalInShares"
        static let includeWatermarkInShares = "settings.includeWatermarkInShares"
        static let weeklyRecapEnabled = "settings.weeklyRecapEnabled"
    }

    init(notifications: NotificationService, settings: SettingsService) {
        self.notifications = notifications
        self.settingsService = settings
        self.reminderEnabled = defaults.bool(forKey: Keys.reminderEnabled)
        self.reminderTime = defaults.object(forKey: Keys.reminderTime) as? Date
            ?? Self.defaultReminderTime
        self.listeningMode = Self.storedEnum(Keys.listeningMode, default: .balanced, defaults: defaults)
        self.startTab = Self.storedEnum(Keys.startTab, default: .today, defaults: defaults)
        self.hapticsEnabled = Self.storedBool(Keys.hapticsEnabled, default: true, defaults: defaults)
        self.showExplicitSongs = Self.storedBool(Keys.showExplicitSongs, default: true, defaults: defaults)
        self.allowPersonalizedInsights = Self.storedBool(Keys.allowPersonalizedInsights, default: true, defaults: defaults)
        self.includeJournalInShares = Self.storedBool(Keys.includeJournalInShares, default: true, defaults: defaults)
        self.includeWatermarkInShares = Self.storedBool(Keys.includeWatermarkInShares, default: true, defaults: defaults)
        self.weeklyRecapEnabled = Self.storedBool(Keys.weeklyRecapEnabled, default: true, defaults: defaults)
    }

    /// 8:00 AM today as a sensible default time-of-day.
    private static var defaultReminderTime: Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }

    func refreshPermission() async {
        permissionDenied = await notifications.authorizationStatus() == .denied
    }

    // MARK: - Cloud sync (Supabase profiles row)

    /// A snapshot of the current preferences as the synced blob.
    var currentSettings: UserSettings {
        var s = UserSettings()
        s.reminderEnabled = reminderEnabled
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        s.reminderHour = comps.hour ?? 8
        s.reminderMinute = comps.minute ?? 0
        s.listeningMode = listeningMode.rawValue
        s.startTab = startTab.rawValue
        s.hapticsEnabled = hapticsEnabled
        s.showExplicitSongs = showExplicitSongs
        s.allowPersonalizedInsights = allowPersonalizedInsights
        s.includeJournalInShares = includeJournalInShares
        s.includeWatermarkInShares = includeWatermarkInShares
        s.weeklyRecapEnabled = weeklyRecapEnabled
        return s
    }

    /// Pull the account's saved settings and apply them, overriding local cache.
    func loadFromCloud() async {
        let result = try? await settingsService.load()
        guard let remote = result ?? nil else { return }
        isApplyingRemote = true
        apply(remote)
        isApplyingRemote = false
        if reminderEnabled { await scheduleReminder() }
    }

    private func apply(_ s: UserSettings) {
        reminderEnabled = s.reminderEnabled
        reminderTime = Calendar.current.date(
            bySettingHour: s.reminderHour, minute: s.reminderMinute, second: 0, of: Date()
        ) ?? reminderTime
        listeningMode = ListeningMode(rawValue: s.listeningMode) ?? .balanced
        startTab = StartTab(rawValue: s.startTab) ?? .today
        hapticsEnabled = s.hapticsEnabled
        showExplicitSongs = s.showExplicitSongs
        allowPersonalizedInsights = s.allowPersonalizedInsights
        includeJournalInShares = s.includeJournalInShares
        includeWatermarkInShares = s.includeWatermarkInShares
        weeklyRecapEnabled = s.weeklyRecapEnabled
    }

    /// Debounced cloud save — coalesces rapid changes (e.g. dragging the time
    /// picker) into one write ~0.6s after the last change.
    private func scheduleSync() {
        guard !isApplyingRemote else { return }
        let snapshot = currentSettings
        syncTask?.cancel()
        syncTask = Task { [settingsService] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            try? await settingsService.save(snapshot)
        }
    }

    /// Called when the toggle flips. Requests permission on first enable, then
    /// schedules or cancels the repeating reminder.
    func applyReminderSetting(enabled: Bool) async {
        if enabled {
            let granted = await notifications.requestAuthorization()
            guard granted else {
                permissionDenied = true
                reminderEnabled = false
                return
            }
            permissionDenied = false
            await scheduleReminder()
        } else {
            await notifications.cancelDailyReminder()
        }
    }

    func scheduleReminder() async {
        guard reminderEnabled else { return }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        await notifications.scheduleDailyReminder(at: comps)
    }

    /// Stand-in for the MusicKit authorization flow we'll add later.
    func connectAppleMusic() async {
        connectingAppleMusic = true
        defer { connectingAppleMusic = false }
        try? await Task.sleep(for: .milliseconds(500))
        appleMusicConnected = true
    }

    func resetLocalPreferences() async {
        reminderEnabled = false
        reminderTime = Self.defaultReminderTime
        listeningMode = .balanced
        startTab = .today
        hapticsEnabled = true
        showExplicitSongs = true
        allowPersonalizedInsights = true
        includeJournalInShares = true
        includeWatermarkInShares = true
        weeklyRecapEnabled = true
        await notifications.cancelDailyReminder()
        await refreshPermission()
    }

    private static func storedBool(_ key: String, default defaultValue: Bool, defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    private static func storedEnum<T: RawRepresentable>(
        _ key: String,
        default defaultValue: T,
        defaults: UserDefaults
    ) -> T where T.RawValue == String {
        guard let rawValue = defaults.string(forKey: key) else { return defaultValue }
        return T(rawValue: rawValue) ?? defaultValue
    }
}
