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

    var reminderEnabled = false {
        didSet { defaults.set(reminderEnabled, forKey: Keys.reminderEnabled) }
    }

    var reminderTime: Date {
        didSet { defaults.set(reminderTime, forKey: Keys.reminderTime) }
    }

    var listeningMode: ListeningMode = .balanced {
        didSet { defaults.set(listeningMode.rawValue, forKey: Keys.listeningMode) }
    }

    var startTab: StartTab = .today {
        didSet { defaults.set(startTab.rawValue, forKey: Keys.startTab) }
    }

    var hapticsEnabled = true {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    var showExplicitSongs = true {
        didSet { defaults.set(showExplicitSongs, forKey: Keys.showExplicitSongs) }
    }

    var allowPersonalizedInsights = true {
        didSet { defaults.set(allowPersonalizedInsights, forKey: Keys.allowPersonalizedInsights) }
    }

    var includeJournalInShares = true {
        didSet { defaults.set(includeJournalInShares, forKey: Keys.includeJournalInShares) }
    }

    var includeWatermarkInShares = true {
        didSet { defaults.set(includeWatermarkInShares, forKey: Keys.includeWatermarkInShares) }
    }

    var weeklyRecapEnabled = true {
        didSet { defaults.set(weeklyRecapEnabled, forKey: Keys.weeklyRecapEnabled) }
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
    private let defaults = UserDefaults.standard

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

    init(notifications: NotificationService) {
        self.notifications = notifications
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
