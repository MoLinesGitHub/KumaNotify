import Foundation
import Observation
import SwiftUI
import WidgetKit

struct WatchStatusSummary {
    let label: String
    let color: Color
    let upCount: Int
    let totalCount: Int
    let downCount: Int
}

struct WatchIncidentSummary: Identifiable {
    let id: String
    let title: String
    let detail: String?
    let date: Date?
    let color: Color
}

@Observable
@MainActor
final class WatchDashboardViewModel {
    private let service: any MonitoringServiceProtocol
    private let widgetDefaults: UserDefaults?
    private let reloadWidgets: () -> Void
    private static let timestampFormatterLock = NSLock()
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var isLoading = false
    var errorMessage: String?
    var result: StatusPageResult?
    var lastRefreshDate: Date?

    init(
        service: any MonitoringServiceProtocol = UptimeKumaService(),
        widgetDefaults: UserDefaults? = UserDefaults(suiteName: AppConstants.appGroupId),
        reloadWidgets: @escaping () -> Void = {
            WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.watchWidgetKind)
        }
    ) {
        self.service = service
        self.widgetDefaults = widgetDefaults
        self.reloadWidgets = reloadWidgets
    }

    var monitors: [UnifiedMonitor] {
        guard let result else { return [] }
        return result.groups
            .flatMap(\.monitors)
            .sorted {
                if statusPriority(for: $0.currentStatus) != statusPriority(for: $1.currentStatus) {
                    return statusPriority(for: $0.currentStatus) < statusPriority(for: $1.currentStatus)
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    var summary: WatchStatusSummary {
        let allMonitors = monitors
        let totalCount = allMonitors.count
        let downCount = allMonitors.filter { $0.currentStatus == .down }.count
        let upCount = allMonitors.filter { $0.currentStatus == .up }.count

        if totalCount == 0 {
            return WatchStatusSummary(
                label: String(localized: "No data"),
                color: .appStatusOffline,
                upCount: 0,
                totalCount: 0,
                downCount: 0
            )
        }

        if downCount > 0 {
            return WatchStatusSummary(
                label: String.localizedStringWithFormat(
                    String(localized: "%lld down"),
                    Int64(downCount)
                ),
                color: .appStatusDown,
                upCount: upCount,
                totalCount: totalCount,
                downCount: downCount
            )
        }

        if isDegraded(monitors: allMonitors) {
            return WatchStatusSummary(
                label: String(localized: "Degraded"),
                color: .appStatusDegraded,
                upCount: upCount,
                totalCount: totalCount,
                downCount: 0
            )
        }

        return WatchStatusSummary(
            label: String(localized: "All OK"),
            color: .appStatusUp,
            upCount: upCount,
            totalCount: totalCount,
            downCount: 0
        )
    }

    var maintenances: [UnifiedMaintenance] {
        guard let result else { return [] }
        return result.maintenances.sorted { lhs, rhs in
            switch (lhs.startDate, rhs.startDate) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    var recentIncidents: [WatchIncidentSummary] {
        guard let result else { return [] }
        return result.incidents.enumerated().map { index, incident in
            let date = incident.lastUpdatedDate.flatMap(parseTimestamp(_:))
                ?? incident.createdDate.flatMap(parseTimestamp(_:))
            return WatchIncidentSummary(
                id: incident.id.map(String.init) ?? "incident-\(index)",
                title: incident.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? incident.title!
                    : String(localized: "Incident"),
                detail: incident.content?.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date,
                color: incidentColor(style: incident.style)
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (lhsDate?, rhsDate?):
                return lhsDate > rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    func refresh(connection: ServerConnection) async {
        isLoading = true
        errorMessage = nil

        do {
            result = try await service.fetchStatusPage(connection: connection)
            lastRefreshDate = .now
            publishWidgetSnapshot(connection: connection)
        } catch {
            result = nil
            errorMessage = error.localizedDescription
            lastRefreshDate = .now
            publishOfflineWidgetSnapshot(connection: connection)
        }

        isLoading = false
    }

    func clearSnapshot() {
        result = nil
        errorMessage = nil
        lastRefreshDate = nil
        if let widgetDefaults {
            WidgetData.clear(from: widgetDefaults)
            reloadWidgets()
        }
    }

    func latestHeartbeat(for monitorID: String) -> UnifiedHeartbeat? {
        result?.heartbeats[monitorID]?.max(by: { $0.time < $1.time })
    }

    private func isDegraded(monitors: [UnifiedMonitor]) -> Bool {
        monitors.contains { monitor in
            if let latestPing = monitor.latestPing, latestPing > AppConstants.degradedPingThreshold {
                return true
            }
            if let uptime24h = monitor.uptime24h, uptime24h < AppConstants.degradedUptimeThreshold {
                return true
            }
            if let certExpiryDays = monitor.certExpiryDays, certExpiryDays < AppConstants.certExpiryWarningDays {
                return true
            }
            return false
        }
    }

    private func statusPriority(for status: MonitorStatus) -> Int {
        switch status {
        case .down: 0
        case .pending: 1
        case .maintenance: 2
        case .up: 3
        }
    }

    private func incidentColor(style: String?) -> Color {
        switch style?.lowercased() {
        case "danger", "critical":
            .appStatusDown
        case "warning":
            .appStatusDegraded
        default:
            .appStatusOffline
        }
    }

    private func parseTimestamp(_ value: String) -> Date? {
        Self.timestampFormatterLock.lock()
        defer { Self.timestampFormatterLock.unlock() }
        return Self.timestampFormatter.date(from: value)
    }

    private func publishWidgetSnapshot(connection: ServerConnection) {
        guard let widgetDefaults, let result else { return }

        let monitors = result.groups.flatMap(\.monitors)
        let upCount = monitors.filter { $0.currentStatus == .up }.count
        let downCount = monitors.filter { $0.currentStatus == .down }.count
        let totalCount = monitors.count

        let overallStatusRaw: String
        if totalCount == 0 {
            overallStatusRaw = "unreachable"
        } else if downCount > 0 {
            overallStatusRaw = "someDown"
        } else if isDegraded(monitors: monitors) {
            overallStatusRaw = "degraded"
        } else {
            overallStatusRaw = "allUp"
        }

        WidgetData(
            upCount: upCount,
            totalCount: totalCount,
            downCount: downCount,
            overallStatusRaw: overallStatusRaw,
            lastCheckTime: lastRefreshDate,
            serverName: result.title.isEmpty ? connection.name : result.title,
            hasActiveIncident: downCount > 0 || !result.incidents.isEmpty,
            activeIncidentCount: result.incidents.count
        ).write(to: widgetDefaults)

        reloadWidgets()
    }

    private func publishOfflineWidgetSnapshot(connection: ServerConnection) {
        guard let widgetDefaults else { return }

        WidgetData(
            upCount: 0,
            totalCount: 0,
            downCount: 0,
            overallStatusRaw: "unreachable",
            lastCheckTime: lastRefreshDate,
            serverName: connection.name,
            hasActiveIncident: false,
            activeIncidentCount: 0
        ).write(to: widgetDefaults)

        reloadWidgets()
    }
}
