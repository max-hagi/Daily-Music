//
//  NotificationService.swift
//  Daily Music
//
//  The daily reminder. UserNotifications needs no backend, so we schedule a
//  repeating local notification on the device at the user's chosen time.
//

import Foundation
import UserNotifications   // Apple's framework for local + push notifications

protocol NotificationService {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async -> Bool
    /// Schedule (or reschedule) the once-a-day reminder at the given time.
    func scheduleDailyReminder(at time: DateComponents) async
    func cancelDailyReminder() async
}

final class LocalNotificationService: NotificationService {
    // The system-wide notification hub (a singleton). We talk to it for everything.
    private let center = UNUserNotificationCenter.current()
    // A STABLE identifier so re-scheduling replaces the old reminder rather than
    // stacking up duplicates.
    private let reminderID = "daily-song-reminder"

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

    func scheduleDailyReminder(at time: DateComponents) async {
        await cancelDailyReminder()   // clear the previous one first (idempotent reschedule)

        // The notification's payload (what the user sees). UNMutableContent is the
        // editable form you fill in.
        let content = UNMutableNotificationContent()
        content.title = "Today's song is ready"
        content.body = "Your daily track and journal entry are waiting."
        content.sound = .default

        // DateComponents with ONLY hour+minute set means "match this time every
        // day" — that's what makes the calendar trigger below repeat daily.
        var trigger = DateComponents()
        trigger.hour = time.hour
        trigger.minute = time.minute

        // A request = id + content + trigger. `repeats: true` fires it every day.
        let request = UNNotificationRequest(
            identifier: reminderID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        try? await center.add(request)   // hand it to the system to schedule
    }

    func cancelDailyReminder() async {
        // Remove the pending request by its id (no-op if nothing is scheduled).
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
    }
}
