//
//  NotificationService.swift
//  Daily Music
//
//  The daily reminder. UserNotifications needs no backend, so we schedule local
//  notifications on the device at the user's chosen time.
//
//  Instead of ONE repeating notification (same copy forever — people learn to
//  swipe it away), we schedule a rolling two-week window of dated reminders
//  with rotating copy, refreshed every app open (see MainTabView). The soonest
//  one can carry the user's live streak count. If someone doesn't open the app
//  for two weeks the reminders quietly stop — deliberate: past that point a
//  daily ping is spam, not a nudge.
//

import Foundation
import UserNotifications   // Apple's framework for local + push notifications

protocol NotificationService {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async -> Bool
    /// Schedule (or reschedule) the rolling daily reminders at the given time.
    /// `streak` (current run, if known) personalizes the next reminder's copy.
    func scheduleDailyReminder(at time: DateComponents, streak: Int?) async
    func cancelDailyReminder() async
    /// Schedule (or clear) the repeating "your recap is ready" announcement,
    /// fired on the 1st of every month. Tapping it deep-links to the recap.
    func setMonthlyRecapAnnouncement(enabled: Bool) async
}

extension NotificationService {
    /// Convenience for call sites that don't know the streak (e.g. Settings).
    func scheduleDailyReminder(at time: DateComponents) async {
        await scheduleDailyReminder(at: time, streak: nil)
    }
}

final class LocalNotificationService: NotificationService {
    // The system-wide notification hub (a singleton). We talk to it for everything.
    private let center = UNUserNotificationCenter.current()
    /// How many days of reminders to keep scheduled ahead.
    private let windowDays = 14
    // STABLE identifiers so re-scheduling replaces the old reminders rather
    // than stacking up duplicates. "daily-song-reminder" (no suffix) is the
    // legacy repeating one — still cleared for users upgrading from it.
    private var reminderIDs: [String] {
        ["daily-song-reminder"] + (0..<windowDays).map { "daily-song-reminder-\($0)" }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        // Has the user granted/denied notification permission? Read it off the
        // current settings object.
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        // Shows the system "Allow Notifications?" prompt. `try?` swallows the
        // throw and `?? false` treats any error as "not granted".
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleDailyReminder(at time: DateComponents, streak: Int?) async {
        await cancelDailyReminder()   // clear the previous window first (idempotent reschedule)

        let calendar = Calendar.current
        let now = Date()

        // The first fire date: today at the chosen time, or tomorrow if that
        // moment has already passed.
        guard let todayAtTime = calendar.date(
            bySettingHour: time.hour ?? 8,
            minute: time.minute ?? 0,
            second: 0,
            of: now
        ) else { return }
        let firstFire = todayAtTime > now
            ? todayAtTime
            : calendar.date(byAdding: .day, value: 1, to: todayAtTime) ?? todayAtTime

        for offset in 0..<windowDays {
            guard let fireDate = calendar.date(byAdding: .day, value: offset, to: firstFire) else { continue }

            let copy = ReminderCopy.content(
                for: fireDate,
                isNextReminder: offset == 0,
                streak: streak,
                calendar: calendar
            )

            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default

            // Full date components (not just hour+minute) → fires exactly once
            // on that day, so each day can carry its own copy.
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "daily-song-reminder-\(offset)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)   // hand it to the system to schedule
        }
    }

    func cancelDailyReminder() async {
        // Remove all pending reminders by id (no-op for ids with nothing scheduled).
        center.removePendingNotificationRequests(withIdentifiers: reminderIDs)
    }

    func setMonthlyRecapAnnouncement(enabled: Bool) async {
        let id = "monthly-recap-announcement"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your monthly recap is ready"
        content.body = "The songs, artists, and streaks that made your month — wrapped up."
        content.sound = .default
        // AppPushDelegate opens this URL on tap → Insights presents last
        // month's Wrapped (see RootView's onOpenURL + MainTabView routing).
        content.userInfo = ["url": "dailymusic://wrapped"]

        // Day-of-month + hour with repeats → fires at 10:00 on the 1st, monthly.
        var trigger = DateComponents()
        trigger.day = 1
        trigger.hour = 10
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        try? await center.add(request)
    }
}
