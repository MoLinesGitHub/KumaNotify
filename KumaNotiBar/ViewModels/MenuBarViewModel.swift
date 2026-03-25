import SwiftUI

@Observable
@MainActor
final class MenuBarViewModel {
    private let service: any MonitoringServiceProtocol
    private let settingsStore: SettingsStore
    let pollingEngine: PollingEngine
    private let networkMonitor: NetworkMonitor

    var overallStatus: OverallStatus = .unreachable
    var upCount = 0
    var totalCount = 0
    var lastCheckTime: Date?
    var hasActiveIncident = false
    var errorMessage: String?

    private var previousMonitorStatuses: [String: MonitorStatus] = [:]
    private var monitorDownSince: [String: Date] = [:]

    var iconStyle: MenuBarIconStyle { settingsStore.menuBarIconStyle }
    var statusColor: Color { overallStatus.color }

    var menuBarTitle: String {
        switch iconStyle {
        case .sfSymbol, .colorDot: ""
        case .textAndIcon: "\(upCount)/\(totalCount)"
        }
    }

    var menuBarImage: String {
        overallStatus.sfSymbol
    }

    init(
        service: any MonitoringServiceProtocol,
        settingsStore: SettingsStore,
        pollingEngine: PollingEngine,
        networkMonitor: NetworkMonitor = NetworkMonitor()
    ) {
        self.service = service
        self.settingsStore = settingsStore
        self.pollingEngine = pollingEngine
        self.networkMonitor = networkMonitor
        self.networkMonitor.start()
    }

    func startPolling() {
        guard let connection = settingsStore.serverConnection else { return }
        pollingEngine.interval = settingsStore.pollingInterval

        pollingEngine.start { [weak self] in
            await self?.fetchStatus(connection: connection)
        }
    }

    func stopPolling() {
        pollingEngine.stop()
    }

    func refresh() async {
        guard let connection = settingsStore.serverConnection else { return }
        await fetchStatus(connection: connection)
    }

    private func fetchStatus(connection: ServerConnection) async {
        guard networkMonitor.isConnected else {
            overallStatus = .unreachable
            errorMessage = "No network connection"
            return
        }

        do {
            let result = try await service.fetchStatusPage(connection: connection)
            let allMonitors = result.groups.flatMap(\.monitors)

            totalCount = allMonitors.count
            upCount = allMonitors.filter { $0.currentStatus == .up }.count
            let downCount = allMonitors.filter { $0.currentStatus == .down }.count
            lastCheckTime = Date()
            hasActiveIncident = downCount > 0
            errorMessage = nil

            if settingsStore.notificationsEnabled {
                detectStateTransitions(monitors: allMonitors, serverName: connection.name)
            }

            if downCount > 0 {
                overallStatus = .someDown(count: downCount, total: totalCount)
            } else if let degraded = findDegradedReason(monitors: allMonitors) {
                overallStatus = .degraded(reason: degraded)
            } else {
                overallStatus = .allUp
            }

            pollingEngine.reportSuccess()
        } catch {
            errorMessage = error.localizedDescription
            overallStatus = .unreachable
            pollingEngine.reportFailure()
        }
    }

    private func detectStateTransitions(monitors: [UnifiedMonitor], serverName: String) {
        let notifications = NotificationManager.shared

        for monitor in monitors {
            let previousStatus = previousMonitorStatuses[monitor.id]

            if previousStatus == .up && monitor.currentStatus == .down {
                monitorDownSince[monitor.id] = Date()
                notifications.sendDownAlert(monitorName: monitor.name, serverName: serverName)
            } else if previousStatus == .down && monitor.currentStatus == .up {
                let downDuration = monitorDownSince[monitor.id].map { Date().timeIntervalSince($0) }
                monitorDownSince.removeValue(forKey: monitor.id)
                notifications.sendRecoveryAlert(
                    monitorName: monitor.name,
                    serverName: serverName,
                    downDuration: downDuration
                )
            }

            previousMonitorStatuses[monitor.id] = monitor.currentStatus
        }
    }

    private func findDegradedReason(monitors: [UnifiedMonitor]) -> OverallStatus.DegradedReason? {
        for monitor in monitors {
            if let ping = monitor.latestPing, ping > AppConstants.degradedPingThreshold {
                return .highPing(monitorName: monitor.name, pingMs: ping)
            }
            if let uptime = monitor.uptime24h, uptime < AppConstants.degradedUptimeThreshold {
                return .lowUptime(monitorName: monitor.name, uptimePercent: uptime)
            }
            if let days = monitor.certExpiryDays, days < AppConstants.certExpiryWarningDays {
                return .certExpiringSoon(monitorName: monitor.name, daysRemaining: days)
            }
        }
        return nil
    }
}
