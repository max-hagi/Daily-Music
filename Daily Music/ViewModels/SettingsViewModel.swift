//
//  SettingsViewModel.swift
//  Daily Music
//
//  Drives the Settings screen: the daily reminder (real local notifications) and
//  the Apple Music connect state (mocked in v1). Reminder preferences persist in
//  UserDefaults so they survive relaunch.
//

import Foundation
import UserNotifications

@MainActor
@Observable
final class SettingsViewModel {
    var reminderEnabled = false {
        didSet { defaults.set(reminderEnabled, forKey: Keys.enabled) }
    }
    var reminderTime: Date {
        didSet { defaults.set(reminderTime, forKey: Keys.time) }
    }
    private(set) var permissionDenied = false
    private(set) var appleMusicConnected = false
    private(set) var connectingAppleMusic = false

    private let notifications: NotificationService
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let enabled = "reminderEnabled"
        static let time = "reminderTime"
    }

    init(notifications: NotificationService) {
        self.notifications = notifications
        self.reminderEnabled = defaults.bool(forKey: Keys.enabled)
        self.reminderTime = defaults.object(forKey: Keys.time) as? Date
            ?? Self.defaultReminderTime
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
}
