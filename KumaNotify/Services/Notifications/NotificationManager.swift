import Foundation
import UserNotifications

final class NotificationManager: NSObject, Sendable {
    static let shared = NotificationManager()

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func sendDownAlert(monitorName: String, serverName: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Monitor Down")
        content.subtitle = monitorName
        content.body = String(localized: "'\(monitorName)' on \(serverName) is not responding.")
        content.sound = .default
        content.categoryIdentifier = "MONITOR_DOWN"
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "down_\(monitorName)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendRecoveryAlert(monitorName: String, serverName: String, downDuration: TimeInterval?) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Monitor Recovered")
        content.subtitle = monitorName

        if let duration = downDuration {
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .abbreviated
            formatter.allowedUnits = [.hour, .minute, .second]
            let durationStr = formatter.string(from: duration) ?? "\(Int(duration))s"
            content.body = String(localized: "'\(monitorName)' is back up after \(durationStr).")
        } else {
            content.body = String(localized: "'\(monitorName)' on \(serverName) is back up.")
        }

        content.sound = .default
        content.categoryIdentifier = "MONITOR_RECOVERY"

        let request = UNNotificationRequest(
            identifier: "recovery_\(monitorName)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendCertExpiryWarning(monitorName: String, daysRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "SSL Certificate Expiring")
        content.subtitle = monitorName
        content.body = String(localized: "Certificate for '\(monitorName)' expires in \(daysRemaining) days.")
        content.sound = .default
        content.categoryIdentifier = "CERT_EXPIRY"

        let request = UNNotificationRequest(
            identifier: "cert_\(monitorName)_\(daysRemaining)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
