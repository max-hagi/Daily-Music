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
    // `didSet` is a PROPERTY OBSERVER — it runs every time the property is assigned.
    // Here it mirrors the value into UserDefaults so the preference persists across
    // launches automatically. These two are plain `var` (not private(set)) because
    // the Settings UI binds two-way to them (a Toggle / DatePicker writes back).
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
    // UserDefaults = a simple key/value store for small user preferences.
    private let defaults = UserDefaults.standard

    // Namespacing the string keys in an enum avoids typos and "magic strings"
    // scattered around (one definition, referenced as Keys.enabled).
    private enum Keys {
        static let enabled = "reminderEnabled"
        static let time = "reminderTime"
    }

    init(notifications: NotificationService) {
        self.notifications = notifications
        // Restore saved prefs. `defaults.bool` returns false if unset (a fine
        // default). `object(forKey:)` returns Any?, so we cast with `as? Date` and
        // fall back to 8 AM if it's missing or the wrong type.
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
            // If the user denies the system prompt, flip the toggle back off and
            // flag it so the UI can explain why nothing was scheduled.
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
        // Pull just the hour+minute out of the chosen Date → a daily-repeating time.
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        await notifications.scheduleDailyReminder(at: comps)
    }

    /// Stand-in for the MusicKit authorization flow we'll add later.
    func connectAppleMusic() async {
        connectingAppleMusic = true
        defer { connectingAppleMusic = false }   // always clear the spinner on exit
        try? await Task.sleep(for: .milliseconds(500))
        appleMusicConnected = true
    }
}
