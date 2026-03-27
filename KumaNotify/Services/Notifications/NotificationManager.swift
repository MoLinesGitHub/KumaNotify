import Foundation
import AppKit
import UserNotifications

enum NotificationAuthorizationStatus: String, Sendable {
    case notDetermined
    case denied
    case authorized
}

protocol NotificationManaging: Sendable {
    func sendDownAlert(
        serverConnectionId: UUID,
        monitorId: String,
        monitorName: String,
        serverName: String,
        soundOption: NotificationSoundOption
    ) async
    func sendRecoveryAlert(
        serverConnectionId: UUID,
        monitorId: String,
        monitorName: String,
        serverName: String,
        downDuration: TimeInterval?,
        soundOption: NotificationSoundOption
    ) async
    func sendCertExpiryWarning(
        serverConnectionId: UUID,
        monitorId: String,
        monitorName: String,
        daysRemaining: Int,
        soundOption: NotificationSoundOption
    ) async
    func sendTestNotification(soundOption: NotificationSoundOption) async
}

actor NotificationManager: NotificationManaging {
    static let shared = NotificationManager()

    private let requestAuthorizationHandler: @Sendable () async throws -> Bool
    private let authorizationStatusHandler: @Sendable () async -> UNAuthorizationStatus
    private let openURLHandler: @Sendable (URL) -> Bool
    private let scheduleRequestHandler: @Sendable (UNNotificationRequest) -> Void

    init(
        requestAuthorizationHandler: @escaping @Sendable () async throws -> Bool = {
            try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        },
        authorizationStatusHandler: @escaping @Sendable () async -> UNAuthorizationStatus = {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        },
        openURLHandler: @escaping @Sendable (URL) -> Bool = { url in
            // Open URL must happen on MainActor
            Task { @MainActor in
                _ = NSWorkspace.shared.open(url)
            }
            return true
        },
        scheduleRequestHandler: @escaping @Sendable (UNNotificationRequest) -> Void = { request in
            let requestIdentifier = request.identifier
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    print("Notifications: Failed to deliver notification '\(requestIdentifier)': \(error.localizedDescription)")
                }
            }
        }
    ) {
        self.requestAuthorizationHandler = requestAuthorizationHandler
        self.authorizationStatusHandler = authorizationStatusHandler
        self.openURLHandler = openURLHandler
        self.scheduleRequestHandler = scheduleRequestHandler
    }

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
            _ = try await requestAuthorizationHandler()
            return await notificationAuthorizationStatus()
        } catch {
            print("Notifications: Notification permission request failed: \(error.localizedDescription)")
            return .denied
        }
    }

    func notificationAuthorizationStatus() async -> NotificationAuthorizationStatus {
        switch await authorizationStatusHandler() {
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
        if let deepLink = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            if openURLHandler(deepLink) {
                return true
            }
        }

        let systemSettingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        return openURLHandler(systemSettingsURL)
    }

    func sendDownAlert(
        serverConnectionId: UUID,
        monitorId: String,
        monitorName: String,
        serverName: String,
        soundOption: NotificationSoundOption = .system
    ) async {
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
    ) async {
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
    ) async {
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

    func sendTestNotification(soundOption: NotificationSoundOption = .system) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Kuma Notify")
        content.body = String(localized: "Test notification — sound is working!")
        content.sound = soundOption == .silent ? nil : .default

        scheduleNotification(id: "test_\(UUID().uuidString)", content: content)
    }

    private func scheduleNotification(id: String, content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        scheduleRequestHandler(request)
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.hour, .minute, .second]
        f.maximumUnitCount = 2
        return f
    }()
}
