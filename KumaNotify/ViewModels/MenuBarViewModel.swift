import SwiftUI
import WidgetKit

@Observable
@MainActor
final class MenuBarViewModel {
    private let settingsStore: SettingsStore
    let pollingEngine: PollingEngine
    private let serviceFactory: (MonitoringProvider) -> any MonitoringServiceProtocol
    private let networkMonitor: NetworkMonitor
    private let persistence: PersistenceManager?
    private let storeManager: StoreManager?
    private let powerMonitor: PowerMonitor
    private let notifications: NotificationManaging
    private let widgetDefaults: UserDefaults?
    private let reloadWidgets: () -> Void
    private let notificationAuthorizationStatusProvider: @Sendable () async -> NotificationAuthorizationStatus
    private var lastWidgetReloadSignature: String?

    private var latestStatusPageResults: [UUID: StatusPageResult] = [:]
    private var latestConnectionErrors: [UUID: String] = [:]

    var overallStatus: OverallStatus = .unreachable
    var upCount = 0
    var totalCount = 0
    var lastCheckTime: Date?
    var hasActiveIncident = false
    var errorMessage: String?

    // Namespaced: "serverConnectionId:monitorId"
    private var previousMonitorStatuses: [String: MonitorStatus] = [:]
    private var monitorDownSince: [String: Date] = [:]
    private var lastCertExpiryWarningDays: [String: Int] = [:]
    private var lastDownAlertSoundAt: Date?

    var iconStyle: MenuBarIconStyle { settingsStore.menuBarIconStyle }
    var statusColor: Color { overallStatus.color }

    var menuBarTitle: String {
        switch iconStyle {
        case .sfSymbol, .colorDot:
            return ""
        case .textAndIcon:
            if case .unreachable = overallStatus {
                return ""
            }
            return "\(upCount)/\(totalCount)"
        }
    }

    var menuBarImage: String {
        overallStatus.menuBarAssetName
    }

    init(
        settingsStore: SettingsStore,
        pollingEngine: PollingEngine,
        serviceFactory: @escaping (MonitoringProvider) -> any MonitoringServiceProtocol = MonitoringServiceFactory.create,
        networkMonitor: NetworkMonitor = NetworkMonitor(),
        persistence: PersistenceManager? = nil,
        storeManager: StoreManager? = nil,
        powerMonitor: PowerMonitor = PowerMonitor(),
        notifications: NotificationManaging = NotificationManager.shared,
        widgetDefaults: UserDefaults? = UserDefaults(suiteName: AppConstants.appGroupId),
        notificationAuthorizationStatusProvider: @escaping @Sendable () async -> NotificationAuthorizationStatus = {
            await NotificationManager.shared.notificationAuthorizationStatus()
        },
        reloadWidgets: @escaping () -> Void = {
            WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
        },
        shouldStartMonitors: Bool = true
    ) {
        self.settingsStore = settingsStore
        self.pollingEngine = pollingEngine
        self.serviceFactory = serviceFactory
        self.networkMonitor = networkMonitor
        self.persistence = persistence
        self.storeManager = storeManager
        self.powerMonitor = powerMonitor
        self.notifications = notifications
        self.widgetDefaults = widgetDefaults
        self.reloadWidgets = reloadWidgets
        self.notificationAuthorizationStatusProvider = notificationAuthorizationStatusProvider
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

    func statusPageResult(for connectionId: UUID) -> StatusPageResult? {
        latestStatusPageResults[connectionId]
    }

    func connectionErrorMessage(for connectionId: UUID) -> String? {
        latestConnectionErrors[connectionId]
    }

    // MARK: - Multi-server fetch

    private func fetchAllServers() async {
        let connections = settingsStore.serverConnections
        let notificationAuthorizationStatus = await notificationAuthorizationStatusProvider()
        if settingsStore.notificationAuthorizationStatus != notificationAuthorizationStatus {
            settingsStore.notificationAuthorizationStatus = notificationAuthorizationStatus
        }

        guard networkMonitor.isConnected else {
            let offlineMessage = String(localized: "No network connection")
            clearConnectionSnapshots(errorMessage: offlineMessage, connections: connections)
            overallStatus = .unreachable
            upCount = 0
            totalCount = 0
            lastCheckTime = Date()
            hasActiveIncident = false
            errorMessage = offlineMessage
            pollingEngine.reportFailure()
            publishWidgetData(downCount: 0)
            refreshPollingInterval()
            return
        }

        guard !connections.isEmpty else {
            clearConnectionSnapshots()
            return
        }

        var allUp = 0
        var allTotal = 0
        var allDown = 0
        var failedConnections = 0
        var anyError: String?
        var degradedReason: OverallStatus.DegradedReason?

        for connection in connections {
            let service = serviceFactory(connection.provider)
            do {
                let result = try await service.fetchStatusPage(connection: connection)
                latestStatusPageResults[connection.id] = result
                latestConnectionErrors[connection.id] = nil
                let monitors = result.groups.flatMap(\.monitors)

                let up = monitors.filter { $0.currentStatus == .up }.count
                let down = monitors.filter { $0.currentStatus == .down }.count
                allUp += up
                allTotal += monitors.count
                allDown += down

                await detectStateTransitions(
                    monitors: monitors,
                    connection: connection
                )
                pruneMonitorState(for: connection.id, activeMonitorIDs: Set(monitors.map(\.id)))

                if degradedReason == nil {
                    degradedReason = findDegradedReason(monitors: monitors)
                }
            } catch {
                failedConnections += 1
                anyError = error.localizedDescription
                latestStatusPageResults[connection.id] = nil
                latestConnectionErrors[connection.id] = error.localizedDescription
            }
        }

        upCount = allUp
        totalCount = allTotal
        lastCheckTime = Date()
        hasActiveIncident = allDown > 0 || failedConnections > 0

        if failedConnections > 0 {
            errorMessage = anyError ?? String(localized: "One or more servers are unreachable")
            overallStatus = .unreachable
            pollingEngine.reportFailure()
        } else if allTotal == 0 {
            errorMessage = nil
            overallStatus = .unreachable
            pollingEngine.reportSuccess()
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

    private func clearConnectionSnapshots(
        errorMessage: String? = nil,
        connections: [ServerConnection] = []
    ) {
        latestStatusPageResults.removeAll()
        if let errorMessage {
            latestConnectionErrors = Dictionary(
                uniqueKeysWithValues: connections.map { ($0.id, errorMessage) }
            )
        } else {
            latestConnectionErrors.removeAll()
        }
    }

    private func publishWidgetData(downCount: Int) {
        let data = WidgetData(
            upCount: upCount,
            totalCount: totalCount,
            downCount: downCount,
            overallStatusRaw: overallStatus.widgetKey,
            lastCheckTime: lastCheckTime,
            serverName: settingsStore.serverConnections.count == 1 ? settingsStore.serverConnection?.name : nil,
            hasActiveIncident: hasActiveIncident
        )
        if let defaults = widgetDefaults {
            data.write(to: defaults)
            let signature = data.reloadSignature
            guard signature != lastWidgetReloadSignature else { return }
            lastWidgetReloadSignature = signature
            reloadWidgets()
        }
    }

    // MARK: - State transitions

    private func detectStateTransitions(monitors: [UnifiedMonitor], connection: ServerConnection) async {
        let soundOption = settingsStore.notificationSound
        let shouldSendNotifications =
            settingsStore.notificationsEnabled
            && settingsStore.notificationAuthorizationStatus == .authorized
            && !settingsStore.isDndActive

        for monitor in monitors {
            let key = monitorStateKey(connectionId: connection.id, monitorId: monitor.id)
            let previousStatus = previousMonitorStatuses[key]
            let isAcknowledged = settingsStore.isMonitorAcknowledged(
                connectionId: connection.id, monitorId: monitor.id
            )

            if let daysRemaining = monitor.certExpiryDays,
               (0..<AppConstants.certExpiryWarningDays).contains(daysRemaining) {
                if shouldSendNotifications, lastCertExpiryWarningDays[key] != daysRemaining {
                    await notifications.sendCertExpiryWarning(
                        serverConnectionId: connection.id,
                        monitorId: monitor.id,
                        monitorName: monitor.name,
                        daysRemaining: daysRemaining,
                        soundOption: soundOption
                    )
                    lastCertExpiryWarningDays[key] = daysRemaining
                }
            } else {
                lastCertExpiryWarningDays.removeValue(forKey: key)
            }

            if previousStatus == .up && monitor.currentStatus == .down {
                monitorDownSince[key] = Date()
                if shouldSendNotifications && !isAcknowledged {
                    let downAlertSoundOption = nextDownAlertSoundOption(default: soundOption)
                    await notifications.sendDownAlert(
                        serverConnectionId: connection.id,
                        monitorId: monitor.id, monitorName: monitor.name,
                        serverName: connection.name, soundOption: downAlertSoundOption
                    )
                }

                await persistence?.recordIncident(IncidentRecordSnapshot(
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
                if shouldSendNotifications && !isAcknowledged {
                    await notifications.sendRecoveryAlert(
                        serverConnectionId: connection.id,
                        monitorId: monitor.id, monitorName: monitor.name,
                        serverName: connection.name, downDuration: downDuration,
                        soundOption: soundOption
                    )
                }
                await persistence?.recordIncident(IncidentRecordSnapshot(
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

    private func nextDownAlertSoundOption(default soundOption: NotificationSoundOption) -> NotificationSoundOption {
        let cooldown = settingsStore.downAlertSoundCooldown
        guard cooldown > 0 else {
            lastDownAlertSoundAt = Date()
            return soundOption
        }

        let now = Date()
        if let lastDownAlertSoundAt,
           now.timeIntervalSince(lastDownAlertSoundAt) < cooldown {
            return .silent
        }

        lastDownAlertSoundAt = now
        return soundOption
    }

    private func pruneMonitorState(for connectionId: UUID, activeMonitorIDs: Set<String>) {
        pruneStateDictionary(&previousMonitorStatuses, connectionId: connectionId, activeMonitorIDs: activeMonitorIDs)
        pruneStateDictionary(&monitorDownSince, connectionId: connectionId, activeMonitorIDs: activeMonitorIDs)
        pruneStateDictionary(&lastCertExpiryWarningDays, connectionId: connectionId, activeMonitorIDs: activeMonitorIDs)
    }

    private func pruneStateDictionary<Value>(
        _ dictionary: inout [String: Value],
        connectionId: UUID,
        activeMonitorIDs: Set<String>
    ) {
        let prefix = "\(connectionId.uuidString):"
        let keysToRemove = dictionary.keys.filter { key in
            guard key.hasPrefix(prefix) else { return false }
            let monitorID = String(key.dropFirst(prefix.count))
            return !activeMonitorIDs.contains(monitorID)
        }

        for key in keysToRemove {
            dictionary.removeValue(forKey: key)
        }
    }

    private func monitorStateKey(connectionId: UUID, monitorId: String) -> String {
        "\(connectionId.uuidString):\(monitorId)"
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
