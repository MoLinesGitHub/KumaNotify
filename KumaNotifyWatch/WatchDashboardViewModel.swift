import Foundation
import Observation
import SwiftUI

struct WatchStatusSummary {
    let label: String
    let color: Color
    let upCount: Int
    let totalCount: Int
    let downCount: Int
}

@Observable
@MainActor
final class WatchDashboardViewModel {
    private let service: any MonitoringServiceProtocol

    var isLoading = false
    var errorMessage: String?
    var result: StatusPageResult?
    var lastRefreshDate: Date?

    init(service: any MonitoringServiceProtocol = UptimeKumaService()) {
        self.service = service
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

    func refresh(connection: ServerConnection) async {
        isLoading = true
        errorMessage = nil

        do {
            result = try await service.fetchStatusPage(connection: connection)
            lastRefreshDate = .now
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func clearSnapshot() {
        result = nil
        errorMessage = nil
        lastRefreshDate = nil
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
}
