import Foundation
import UserNotifications

/// One gentle local notification a day. Nothing leaves the device.
enum DailyReminder {
    static let identifier = "daily-prayer"

    /// Asks for permission if needed and schedules the reminder. Returns false if notifications are off.
    static func schedule(minutesAfterMidnight minutes: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = title(forHour: minutes / 60)
        content.body = "Take a quiet minute with Ashtotra. 🙏"
        content.sound = .default

        var time = DateComponents()
        time.hour = minutes / 60
        time.minute = minutes % 60
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        )
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await center.add(request)
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    static func title(forHour hour: Int) -> String {
        switch hour {
        case 4..<12: "Time for your morning prayers"
        case 12..<17: "A moment for prayer"
        default: "Time for your evening prayers"
        }
    }
}
