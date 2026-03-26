import Foundation
import SwiftUI
import ServiceManagement
import os

@Observable
final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults

    init() {
        self.defaults = UserDefaults.standard
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            "pollingInterval": AppConstants.defaultPollingInterval,
            "iconStyle": MenuBarIconStyle.sfSymbol.rawValue,
            "notificationsEnabled": true,
        ])
    }

    // MARK: - Polling

    var pollingInterval: TimeInterval {
        get { defaults.double(forKey: "pollingInterval") }
        set { defaults.set(newValue, forKey: "pollingInterval") }
    }

    func effectivePollingInterval(isPro: Bool) -> TimeInterval {
        let floor = isPro ? AppConstants.minimumPollingPro : AppConstants.minimumPollingBasic
        return max(pollingInterval, floor)
    }

    // MARK: - Appearance

    var menuBarIconStyle: MenuBarIconStyle {
        get { MenuBarIconStyle(rawValue: defaults.string(forKey: "iconStyle") ?? "") ?? .sfSymbol }
        set { defaults.set(newValue.rawValue, forKey: "iconStyle") }
    }

    // MARK: - Notifications

    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: "notificationsEnabled") }
        set { defaults.set(newValue, forKey: "notificationsEnabled") }
    }

    var notificationSound: NotificationSoundOption {
        get { NotificationSoundOption(rawValue: defaults.string(forKey: "notificationSound") ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: "notificationSound") }
    }

    /// DND end time. If in the future, DND is active.
    var dndUntil: Date? {
        get { defaults.object(forKey: "dndUntil") as? Date }
        set { defaults.set(newValue, forKey: "dndUntil") }
    }

    var isDndActive: Bool {
        guard let until = dndUntil else { return false }
        return until > Date()
    }

    /// Acknowledged monitor IDs (silenced). Key: "serverConnectionId:monitorId"
    var acknowledgedMonitors: Set<String> {
        get { Set(defaults.stringArray(forKey: "acknowledgedMonitors") ?? []) }
        set { defaults.set(Array(newValue), forKey: "acknowledgedMonitors") }
    }

    func acknowledgeMonitor(connectionId: UUID, monitorId: String) {
        var set = acknowledgedMonitors
        set.insert("\(connectionId):\(monitorId)")
        acknowledgedMonitors = set
    }

    func unacknowledgeMonitor(connectionId: UUID, monitorId: String) {
        var set = acknowledgedMonitors
        set.remove("\(connectionId):\(monitorId)")
        acknowledgedMonitors = set
    }

    func isMonitorAcknowledged(connectionId: UUID, monitorId: String) -> Bool {
        acknowledgedMonitors.contains("\(connectionId):\(monitorId)")
    }

    // MARK: - Server Connections

    var serverConnections: [ServerConnection] {
        get {
            guard let data = defaults.data(forKey: "serverConnections") else {
                // Migration: read legacy single connection
                if let legacy = legacyServerConnection {
                    return [legacy]
                }
                return []
            }
            do {
                return try JSONDecoder().decode([ServerConnection].self, from: data)
            } catch {
                Logger.app.error("Failed to decode ServerConnections: \(error.localizedDescription)")
                return []
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "serverConnections")
                // Clean up legacy key after migration
                defaults.removeObject(forKey: "serverConnection")
            } catch {
                Logger.app.error("Failed to encode ServerConnections: \(error.localizedDescription)")
            }
        }
    }

    /// Default connection shown in menu bar. Returns the one marked `isDefault`, or the first.
    var serverConnection: ServerConnection? {
        get { serverConnections.first(where: \.isDefault) ?? serverConnections.first }
        set {
            if let newValue {
                var connections = serverConnections
                if let idx = connections.firstIndex(where: { $0.id == newValue.id }) {
                    connections[idx] = newValue
                } else {
                    connections.append(newValue)
                }
                serverConnections = connections
            }
        }
    }

    func addConnection(_ connection: ServerConnection) {
        var connections = serverConnections
        // If first connection, make it default
        var conn = connection
        if connections.isEmpty {
            conn.isDefault = true
        }
        connections.append(conn)
        serverConnections = connections
    }

    func removeConnection(id: UUID) {
        var connections = serverConnections
        let wasDefault = connections.first(where: { $0.id == id })?.isDefault ?? false
        connections.removeAll { $0.id == id }
        if wasDefault, let first = connections.indices.first {
            connections[first].isDefault = true
        }
        serverConnections = connections
    }

    func setDefaultConnection(id: UUID) {
        var connections = serverConnections
        for i in connections.indices {
            connections[i].isDefault = (connections[i].id == id)
        }
        serverConnections = connections
    }

    func updateConnection(_ connection: ServerConnection) {
        var connections = serverConnections
        if let idx = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[idx] = connection
            serverConnections = connections
        }
    }

    /// Legacy single-connection migration helper
    private var legacyServerConnection: ServerConnection? {
        guard let data = defaults.data(forKey: "serverConnection") else { return nil }
        return try? JSONDecoder().decode(ServerConnection.self, from: data)
    }

    // MARK: - Launch at Login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Logger.app.error("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - First Launch

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }
}

enum NotificationSoundOption: String, CaseIterable, Sendable {
    case system = "system"
    case silent = "silent"

    var label: String {
        switch self {
        case .system: String(localized: "System Sound")
        case .silent: String(localized: "Silent")
        }
    }
}

enum DndPreset: String, CaseIterable, Identifiable {
    case oneHour = "1h"
    case untilTomorrow = "tomorrow"
    case indefinite = "indefinite"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneHour: String(localized: "1 hour")
        case .untilTomorrow: String(localized: "Until tomorrow")
        case .indefinite: String(localized: "Indefinitely")
        }
    }

    var endDate: Date {
        switch self {
        case .oneHour:
            Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        case .untilTomorrow:
            Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 8), matchingPolicy: .nextTime) ?? Date()
        case .indefinite:
            Date.distantFuture
        }
    }
}

enum MenuBarIconStyle: String, Codable, CaseIterable, Sendable {
    case sfSymbol = "sf_symbol"
    case colorDot = "color_dot"
    case textAndIcon = "text_and_icon"

    var label: String {
        switch self {
        case .sfSymbol: String(localized: "Antenna Icon")
        case .colorDot: String(localized: "Color Dot")
        case .textAndIcon: String(localized: "Text + Icon")
        }
    }
}
