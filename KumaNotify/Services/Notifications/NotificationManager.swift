import Foundation
import AppKit
import UserNotifications
import os

enum NotificationAuthorizationStatus: String, Sendable {
    case notDetermined
    case denied
    case authorized
}

@MainActor
protocol NotificationManaging: AnyObject {
    func sendDownAlert(
        serverConnectionId: UUID,
        monitorId: String,
        monitorName: String,
        serverName: String,
        soundOption: NotificationSoundOption
    )
    func sendRecoveryAlert(
        serverConnectionId: UUID,
        monitorId: String,
        monitorName: String,
        serverName: String,
        downDuration: TimeInterval?,
        soundOption: NotificationSoundOption
    )
    func sendCertExpiryWarning(
        serverConnectionId: UUID,
        monitorId: String,
        monitorName: String,
        daysRemaining: Int,
        soundOption: NotificationSoundOption
    )
}

final class NotificationManager: NSObject, Sendable, NotificationManaging {
    static let shared = NotificationManager()

    static func downAlertIdentifier(serverConnectionId: UUID, monitorId: String) -> String {
        "down_\(serverConnectionId.uuidString)_\(monitorId)"
    }

    static func recoveryAlertIdentifier(serverConnectionId: UUID, monitorId: String) -> String {
        "recovery_\(serverConnectionId.uuidString)_\(monitorId)"
    }

    static func certExpiryIdentifier(serverConnectionId: UUID, monitorId: String, daysRemaining: Int) -> String {
        "cert_\(serverConnectionId.uuidString)_\(monitorId)_\(daysRemaining)"
    }

    func requestPermission() async -> NotificationAuthorizationStatus {
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return await notificationAuthorizationStatus()
        } catch {
            Logger.app.error("Notification permission request failed: \(error.localizedDescription)")
            return .denied
        }
    }

    func notificationAuthorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .notDetermined:
            return .notDetermined
        default:
            return .denied
        }
    }

    func notificationsAuthorized() async -> Bool {
        await notificationAuthorizationStatus() == .authorized
    }

    @discardableResult
    func openSystemNotificationSettings() -> Bool {
        if let deepLink = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"),
           NSWorkspace.shared.open(deepLink) {
            return true
        }

        let systemSettingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        return NSWorkspace.shared.open(systemSettingsURL)
    }

    func sendDownAlert(
        serverConnectionId: UUID,
        monitorId: String,
        monitorName: String,
        serverName: String,
        soundOption: NotificationSoundOption = .system
    ) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Monitor Down")
        content.subtitle = monitorName
        content.body = String(format: String(localized: "'%@' on %@ is not responding."), monitorName, serverName)
        content.sound = soundOption == .silent ? nil : .default
        content.categoryIdentifier = "MONITOR_DOWN"
        content.interruptionLevel = .timeSensitive

        scheduleNotification(
            id: Self.downAlertIdentifier(serverConnectionId: serverConnectionId, monitorId: monitorId),
            content: content
        )
    }

    func sendRecoveryAlert(
        serverConnectionId: UUID,
        monitorId: String,
        monitorName: String,
        serverName: String,
        downDuration: TimeInterval?,
        soundOption: NotificationSoundOption = .system
    ) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Monitor Recovered")
        content.subtitle = monitorName

        if let duration = downDuration {
            let durationStr = Self.durationFormatter.string(from: duration) ?? "\(Int(duration))s"
            content.body = String(format: String(localized: "'%@' is back up after %@."), monitorName, durationStr)
        } else {
            content.body = String(format: String(localized: "'%@' on %@ is back up."), monitorName, serverName)
        }

        content.sound = soundOption == .silent ? nil : .default
        content.categoryIdentifier = "MONITOR_RECOVERY"

        scheduleNotification(
            id: Self.recoveryAlertIdentifier(serverConnectionId: serverConnectionId, monitorId: monitorId),
            content: content
        )
    }

    func sendCertExpiryWarning(
        serverConnectionId: UUID,
        monitorId: String,
        monitorName: String,
        daysRemaining: Int,
        soundOption: NotificationSoundOption = .system
    ) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "SSL Certificate Expiring")
        content.subtitle = monitorName
        content.body = String(format: String(localized: "Certificate for '%@' expires in %lld days."), monitorName, daysRemaining)
        content.sound = soundOption == .silent ? nil : .default
        content.categoryIdentifier = "CERT_EXPIRY"

        scheduleNotification(
            id: Self.certExpiryIdentifier(
                serverConnectionId: serverConnectionId,
                monitorId: monitorId,
                daysRemaining: daysRemaining
            ),
            content: content
        )
    }

    func sendTestNotification(soundOption: NotificationSoundOption = .system) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Kuma Notify")
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
