//
//  NotificationService.swift
//  Daily Music
//
//  The daily reminder. This one is "real" even in v1 — UserNotifications needs
//  no backend, so we schedule a repeating LOCAL notification on the device.
//  v1 uses a single fixed time; custom morning/evening times come later.
//

import Foundation
import UserNotifications

protocol NotificationService {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async -> Bool
    /// Schedule (or reschedule) the once-a-day reminder at the given time.
    func scheduleDailyReminder(at time: DateComponents) async
    func cancelDailyReminder() async
}

final class LocalNotificationService: NotificationService {
    private let center = UNUserNotificationCenter.current()
    private let reminderID = "daily-song-reminder"

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleDailyReminder(at time: DateComponents) async {
        await cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "Today's song is ready"
        content.body = "Your daily track and journal entry are waiting."
        content.sound = .default

        // hour + minute only → repeats every day at that time.
        var trigger = DateComponents()
        trigger.hour = time.hour
        trigger.minute = time.minute

        let request = UNNotificationRequest(
            identifier: reminderID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        try? await center.add(request)
    }

    func cancelDailyReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
    }
}
