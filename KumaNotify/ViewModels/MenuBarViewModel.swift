import SwiftUI
import WidgetKit

@Observable
@MainActor
final class MenuBarViewModel {
    private let settingsStore: SettingsStore
    let pollingEngine: PollingEngine
    private let networkMonitor: NetworkMonitor
    private let persistence: PersistenceManager?
    private let storeManager: StoreManager?
    private let powerMonitor: PowerMonitor
    private let widgetDefaults: UserDefaults?
    private let reloadWidgets: () -> Void

    var overallStatus: OverallStatus = .unreachable
    var upCount = 0
    var totalCount = 0
    var lastCheckTime: Date?
    var hasActiveIncident = false
    var errorMessage: String?

    // Namespaced: "serverConnectionId:monitorId"
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
        settingsStore: SettingsStore,
        pollingEngine: PollingEngine,
        networkMonitor: NetworkMonitor = NetworkMonitor(),
        persistence: PersistenceManager? = nil,
        storeManager: StoreManager? = nil,
        powerMonitor: PowerMonitor = PowerMonitor(),
        widgetDefaults: UserDefaults? = UserDefaults(suiteName: AppConstants.appGroupId),
        reloadWidgets: @escaping () -> Void = {
            WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
        },
        shouldStartMonitors: Bool = true
    ) {
        self.settingsStore = settingsStore
        self.pollingEngine = pollingEngine
        self.networkMonitor = networkMonitor
        self.persistence = persistence
        self.storeManager = storeManager
        self.powerMonitor = powerMonitor
        self.widgetDefaults = widgetDefaults
        self.reloadWidgets = reloadWidgets
        if shouldStartMonitors {
            self.networkMonitor.start()
            self.powerMonitor.start()
        }
    }

    func startPolling() {
        let connections = settingsStore.serverConnections
        guard !connections.isEmpty else { return }
        refreshPollingInterval()

        pollingEngine.start { [weak self] in
            await self?.fetchAllServers()
        }
    }

    func refreshPollingInterval() {
        let isPro = storeManager?.proUnlocked ?? false
        pollingEngine.interval = settingsStore.effectivePollingInterval(
            isPro: isPro,
            isOnBattery: powerMonitor.isOnBattery,
            batteryLevel: powerMonitor.batteryLevel
        )
    }

    func stopPolling() {
        pollingEngine.stop()
        networkMonitor.stop()
        powerMonitor.stop()
    }

    func refresh() async {
        await fetchAllServers()
    }

    // MARK: - Multi-server fetch

    private func fetchAllServers() async {
        guard networkMonitor.isConnected else {
            overallStatus = .unreachable
            upCount = 0
            totalCount = 0
            lastCheckTime = Date()
            hasActiveIncident = false
            errorMessage = String(localized: "No network connection")
            publishWidgetData(downCount: 0)
            refreshPollingInterval()
            return
        }

        let connections = settingsStore.serverConnections
        guard !connections.isEmpty else { return }

        var allUp = 0
        var allTotal = 0
        var allDown = 0
        var anyError: String?
        var degradedReason: OverallStatus.DegradedReason?

        for connection in connections {
            let service = MonitoringServiceFactory.create(for: connection.provider)
            do {
                let result = try await service.fetchStatusPage(connection: connection)
                let monitors = result.groups.flatMap(\.monitors)

                let up = monitors.filter { $0.currentStatus == .up }.count
                let down = monitors.filter { $0.currentStatus == .down }.count
                allUp += up
                allTotal += monitors.count
                allDown += down

                if settingsStore.notificationsEnabled {
                    detectStateTransitions(
                        monitors: monitors,
                        connection: connection
                    )
                }

                if degradedReason == nil {
                    degradedReason = findDegradedReason(monitors: monitors)
                }
            } catch {
                anyError = error.localizedDescription
            }
        }

        upCount = allUp
        totalCount = allTotal
        lastCheckTime = Date()
        hasActiveIncident = allDown > 0

        if allTotal == 0, let anyError {
            errorMessage = anyError
            overallStatus = .unreachable
            pollingEngine.reportFailure()
        } else {
            errorMessage = nil
            if allDown > 0 {
                overallStatus = .someDown(count: allDown, total: allTotal)
            } else if let reason = degradedReason {
                overallStatus = .degraded(reason: reason)
            } else {
                overallStatus = .allUp
            }
            pollingEngine.reportSuccess()
        }

        publishWidgetData(downCount: allDown)
        refreshPollingInterval()
    }

    private func publishWidgetData(downCount: Int) {
        let data = WidgetData(
            upCount: upCount,
            totalCount: totalCount,
            downCount: downCount,
            overallStatusRaw: overallStatus.widgetKey,
            lastCheckTime: lastCheckTime,
            serverName: settingsStore.serverConnection?.name,
            hasActiveIncident: hasActiveIncident
        )
        if let defaults = widgetDefaults {
            data.write(to: defaults)
            reloadWidgets()
        }
    }

    // MARK: - State transitions

    private func detectStateTransitions(monitors: [UnifiedMonitor], connection: ServerConnection) {
        // Skip notifications if DND active or notifications disabled
        guard !settingsStore.isDndActive else {
            // Still record incidents even during DND
            recordTransitionsOnly(monitors: monitors, connection: connection)
            return
        }

        let notifications = NotificationManager.shared
        let soundOption = settingsStore.notificationSound

        for monitor in monitors {
            let key = "\(connection.id):\(monitor.id)"
            let previousStatus = previousMonitorStatuses[key]
            let isAcknowledged = settingsStore.isMonitorAcknowledged(
                connectionId: connection.id, monitorId: monitor.id
            )

            if previousStatus == .up && monitor.currentStatus == .down {
                monitorDownSince[key] = Date()
                if !isAcknowledged {
                    notifications.sendDownAlert(
                        serverConnectionId: connection.id,
                        monitorId: monitor.id, monitorName: monitor.name,
                        serverName: connection.name, soundOption: soundOption
                    )
                }
                persistence?.recordIncident(IncidentRecord(
                    monitorId: monitor.id,
                    monitorName: monitor.name,
                    serverConnectionId: connection.id,
                    serverName: connection.name,
                    transitionType: .wentDown
                ))
            } else if previousStatus == .down && monitor.currentStatus == .up {
                let downDuration = monitorDownSince[key].map { Date().timeIntervalSince($0) }
                monitorDownSince.removeValue(forKey: key)
                // Auto-clear acknowledge on recovery
                settingsStore.unacknowledgeMonitor(connectionId: connection.id, monitorId: monitor.id)
                if !isAcknowledged {
                    notifications.sendRecoveryAlert(
                        serverConnectionId: connection.id,
                        monitorId: monitor.id, monitorName: monitor.name,
                        serverName: connection.name, downDuration: downDuration,
                        soundOption: soundOption
                    )
                }
                persistence?.recordIncident(IncidentRecord(
                    monitorId: monitor.id,
                    monitorName: monitor.name,
                    serverConnectionId: connection.id,
                    serverName: connection.name,
                    transitionType: .recovered,
                    downDuration: downDuration
                ))
            }

            previousMonitorStatuses[key] = monitor.currentStatus
        }
    }

    /// Record state transitions for persistence without sending notifications (used during DND)
    private func recordTransitionsOnly(monitors: [UnifiedMonitor], connection: ServerConnection) {
        for monitor in monitors {
            let key = "\(connection.id):\(monitor.id)"
            let previousStatus = previousMonitorStatuses[key]

            if previousStatus == .up && monitor.currentStatus == .down {
                monitorDownSince[key] = Date()
                persistence?.recordIncident(IncidentRecord(
                    monitorId: monitor.id, monitorName: monitor.name,
                    serverConnectionId: connection.id, serverName: connection.name,
                    transitionType: .wentDown
                ))
            } else if previousStatus == .down && monitor.currentStatus == .up {
                let downDuration = monitorDownSince[key].map { Date().timeIntervalSince($0) }
                monitorDownSince.removeValue(forKey: key)
                persistence?.recordIncident(IncidentRecord(
                    monitorId: monitor.id, monitorName: monitor.name,
                    serverConnectionId: connection.id, serverName: connection.name,
                    transitionType: .recovered, downDuration: downDuration
                ))
            }

            previousMonitorStatuses[key] = monitor.currentStatus
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
