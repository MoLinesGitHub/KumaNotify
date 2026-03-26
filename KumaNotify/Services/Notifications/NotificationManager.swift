import Foundation
import UserNotifications
import os

final class NotificationManager: NSObject, Sendable {
    static let shared = NotificationManager()

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Logger.app.error("Notification permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    func sendDownAlert(monitorId: String, monitorName: String, serverName: String, soundOption: NotificationSoundOption = .system) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Monitor Down")
        content.subtitle = monitorName
        content.body = String(localized: "'\(monitorName)' on \(serverName) is not responding.")
        content.sound = soundOption == .silent ? nil : .default
        content.categoryIdentifier = "MONITOR_DOWN"
        content.interruptionLevel = .timeSensitive

        scheduleNotification(id: "down_\(monitorId)", content: content)
    }

    func sendRecoveryAlert(monitorId: String, monitorName: String, serverName: String, downDuration: TimeInterval?, soundOption: NotificationSoundOption = .system) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Monitor Recovered")
        content.subtitle = monitorName

        if let duration = downDuration {
            let durationStr = Self.durationFormatter.string(from: duration) ?? "\(Int(duration))s"
            content.body = String(localized: "'\(monitorName)' is back up after \(durationStr).")
        } else {
            content.body = String(localized: "'\(monitorName)' on \(serverName) is back up.")
        }

        content.sound = soundOption == .silent ? nil : .default
        content.categoryIdentifier = "MONITOR_RECOVERY"

        scheduleNotification(id: "recovery_\(monitorId)", content: content)
    }

    func sendCertExpiryWarning(monitorId: String, monitorName: String, daysRemaining: Int, soundOption: NotificationSoundOption = .system) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "SSL Certificate Expiring")
        content.subtitle = monitorName
        content.body = String(localized: "Certificate for '\(monitorName)' expires in \(daysRemaining) days.")
        content.sound = soundOption == .silent ? nil : .default
        content.categoryIdentifier = "CERT_EXPIRY"

        scheduleNotification(id: "cert_\(monitorId)_\(daysRemaining)", content: content)
    }

    func sendTestNotification(soundOption: NotificationSoundOption = .system) {
        let content = UNMutableNotificationContent()
        content.title = "Kuma Notify"
        content.body = String(localized: "Test notification — sound is working!")
        content.sound = soundOption == .silent ? nil : .default

        scheduleNotification(id: "test_\(UUID().uuidString)", content: content)
    }

    private func scheduleNotification(id: String, content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Logger.app.error("Failed to deliver notification '\(id)': \(error.localizedDescription)")
            }
        }
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.hour, .minute, .second]
        f.maximumUnitCount = 2
        return f
    }()
}
