//
//  ReminderNotificationService.swift
//  Fyra
//

import Foundation
import UserNotifications

enum ReminderNotificationService {
    private static let reminderIdentifier = "fyra.daily.reminder"

    /// Request permission if needed and keep reminders in sync with settings.
    static func syncReminderNotifications(
        enabled: Bool,
        reminderTime: Date?
    ) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard enabled, let reminderTime else {
            center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
            return true
        }

        let granted = await ensureAuthorization(center: center)
        guard granted else {
            center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
            return false
        }

        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Time for your check-in"
        content.body = "A quick photo and weight log keeps your progress clear."
        content.sound = .default

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderTime)
        let minute = calendar.component(.minute, from: reminderTime)
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )

        return await withCheckedContinuation { continuation in
            center.add(request) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    private static func ensureAuthorization(center: UNUserNotificationCenter) async -> Bool {
        let status = await notificationAuthorizationStatus(center: center)
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    private static func notificationAuthorizationStatus(
        center: UNUserNotificationCenter
    ) async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }
}
