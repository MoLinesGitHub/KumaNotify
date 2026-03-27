import XCTest
import UserNotifications
import IOKit.ps
@testable import KumaNotify

final class KumaNotifyTests: XCTestCase {
    struct FailingTestError: LocalizedError {
        var errorDescription: String? { "Restore failed" }
    }

    @MainActor
    private func makeSettingsStore() -> (suiteName: String, store: SettingsStore) {
        let suiteName = "KumaNotifyTests.\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        return (suiteName, SettingsStore(suiteName: suiteName))
    }

    private func localizableCatalogContents() throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = repoRoot.appendingPathComponent("KumaNotify/Resources/Localizable.xcstrings")
        return try String(contentsOf: catalogURL, encoding: .utf8)
    }

    private func projectYAMLContents() throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectURL = repoRoot.appendingPathComponent("project.yml")
        return try String(contentsOf: projectURL, encoding: .utf8)
    }

    actor CountingMonitoringService: MonitoringServiceProtocol {
        private(set) var statusPageCallCount = 0
        private(set) var heartbeatCallCount = 0
        let result: StatusPageResult

        init(result: StatusPageResult) {
            self.result = result
        }

        func fetchStatusPage(connection: ServerConnection) async throws -> StatusPageResult {
            statusPageCallCount += 1
            return result
        }

        func fetchHeartbeats(connection: ServerConnection) async throws -> HeartbeatResult {
            heartbeatCallCount += 1
            return HeartbeatResult(heartbeats: [:], uptimes: [:])
        }

        func validateConnection(_ connection: ServerConnection) async throws -> Bool {
            true
        }

        func callCounts() -> (statusPage: Int, heartbeat: Int) {
            (statusPageCallCount, heartbeatCallCount)
        }
    }

    actor SequencedMonitoringService: MonitoringServiceProtocol {
        private var results: [StatusPageResult]

        init(results: [StatusPageResult]) {
            self.results = results
        }

        func fetchStatusPage(connection: ServerConnection) async throws -> StatusPageResult {
            if results.count > 1 {
                return results.removeFirst()
            }
            return results.first!
        }

        func fetchHeartbeats(connection: ServerConnection) async throws -> HeartbeatResult {
            HeartbeatResult(heartbeats: [:], uptimes: [:])
        }

        func validateConnection(_ connection: ServerConnection) async throws -> Bool {
            true
        }
    }

    struct ScriptedMonitoringService: MonitoringServiceProtocol {
        let fetchStatusPageHandler: @Sendable (ServerConnection) async throws -> StatusPageResult
        let fetchHeartbeatsHandler: @Sendable (ServerConnection) async throws -> HeartbeatResult
        let validateConnectionHandler: @Sendable (ServerConnection) async throws -> Bool

        init(
            fetchStatusPageHandler: @escaping @Sendable (ServerConnection) async throws -> StatusPageResult,
            fetchHeartbeatsHandler: @escaping @Sendable (ServerConnection) async throws -> HeartbeatResult = { _ in
                HeartbeatResult(heartbeats: [:], uptimes: [:])
            },
            validateConnectionHandler: @escaping @Sendable (ServerConnection) async throws -> Bool = { _ in true }
        ) {
            self.fetchStatusPageHandler = fetchStatusPageHandler
            self.fetchHeartbeatsHandler = fetchHeartbeatsHandler
            self.validateConnectionHandler = validateConnectionHandler
        }

        func fetchStatusPage(connection: ServerConnection) async throws -> StatusPageResult {
            try await fetchStatusPageHandler(connection)
        }

        func fetchHeartbeats(connection: ServerConnection) async throws -> HeartbeatResult {
            try await fetchHeartbeatsHandler(connection)
        }

        func validateConnection(_ connection: ServerConnection) async throws -> Bool {
            try await validateConnectionHandler(connection)
        }
    }

    @MainActor
    final class NotificationSpy: NotificationManaging {
        private(set) var downAlerts: [(UUID, String)] = []
        private(set) var downAlertSoundOptions: [NotificationSoundOption] = []
        private(set) var recoveryAlerts: [(UUID, String)] = []
        private(set) var certExpiryWarnings: [(UUID, String, Int)] = []
        private(set) var testNotificationCount = 0

        func sendDownAlert(
            serverConnectionId: UUID,
            monitorId: String,
            monitorName: String,
            serverName: String,
            soundOption: NotificationSoundOption
        ) async {
            downAlerts.append((serverConnectionId, monitorId))
            downAlertSoundOptions.append(soundOption)
        }

        func sendRecoveryAlert(
            serverConnectionId: UUID,
            monitorId: String,
            monitorName: String,
            serverName: String,
            downDuration: TimeInterval?,
            soundOption: NotificationSoundOption
        ) async {
            recoveryAlerts.append((serverConnectionId, monitorId))
        }

        func sendCertExpiryWarning(
            serverConnectionId: UUID,
            monitorId: String,
            monitorName: String,
            daysRemaining: Int,
            soundOption: NotificationSoundOption
        ) async {
            certExpiryWarnings.append((serverConnectionId, monitorId, daysRemaining))
        }

        func sendTestNotification(soundOption: NotificationSoundOption) async {
            testNotificationCount += 1
        }
    }

    final class NotificationRequestRecorder: @unchecked Sendable {
        var requests: [UNNotificationRequest] = []

        func record(_ request: UNNotificationRequest) {
            requests.append(request)
        }
    }

    final class URLRecorder: @unchecked Sendable {
        var urls: [URL] = []

        func record(_ url: URL) {
            urls.append(url)
        }
    }

    actor ScriptedHTTPClient: HTTPClientProtocol {
        private(set) var requestedURLs: [URL] = []
        let statusPageResponse: UKStatusPageResponse
        let heartbeatResponse: UKHeartbeatResponse
        let errorByURL: [URL: Error]

        init(
            statusPageResponse: UKStatusPageResponse,
            heartbeatResponse: UKHeartbeatResponse,
            errorByURL: [URL: Error] = [:]
        ) {
            self.statusPageResponse = statusPageResponse
            self.heartbeatResponse = heartbeatResponse
            self.errorByURL = errorByURL
        }

        func get<T: Decodable & Sendable>(url: URL) async throws -> T {
            requestedURLs.append(url)

            if let error = errorByURL[url] {
                throw error
            }

            switch T.self {
            case is UKHeartbeatResponse.Type:
                return heartbeatResponse as! T
            case is UKStatusPageResponse.Type:
                return statusPageResponse as! T
            default:
                fatalError("Unexpected response type requested: \(T.self)")
            }
        }

        func requestedURLSnapshot() -> [URL] {
            requestedURLs
        }
    }

    func testMonitorStatusRawValues() {
        XCTAssertEqual(MonitorStatus.up.rawValue, 1)
        XCTAssertEqual(MonitorStatus.down.rawValue, 0)
        XCTAssertEqual(MonitorStatus.pending.rawValue, 2)
        XCTAssertEqual(MonitorStatus.maintenance.rawValue, 3)
    }

    func testMonitorStatusLabelsNotEmpty() {
        for status in MonitorStatus.allCases {
            XCTAssertFalse(status.label.isEmpty)
        }
    }

    func testOverallStatusLabels() {
        XCTAssertFalse(OverallStatus.allUp.label.isEmpty)
        XCTAssertFalse(OverallStatus.unreachable.label.isEmpty)
        XCTAssertFalse(OverallStatus.someDown(count: 2, total: 5).label.isEmpty)
    }

    func testIncidentTransitionType() {
        XCTAssertEqual(IncidentTransitionType.wentDown.rawValue, "went_down")
        XCTAssertEqual(IncidentTransitionType.recovered.rawValue, "recovered")
        XCTAssertFalse(IncidentTransitionType.wentDown.label.isEmpty)
        XCTAssertFalse(IncidentTransitionType.recovered.label.isEmpty)
    }

    @MainActor
    func testSettingsStoreEffectivePollingIntervalAppliesFloorAndBatterySaver() {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        store.pollingInterval = 20
        XCTAssertEqual(store.effectivePollingInterval(isPro: false), AppConstants.minimumPollingBasic)

        store.batterySaverEnabled = true
        XCTAssertEqual(store.effectivePollingInterval(isPro: true, isOnBattery: true, batteryLevel: 0.1), 60)
    }

    @MainActor
    func testSettingsStoreNotificationsDefaultToDisabledUntilAuthorized() {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        XCTAssertFalse(store.notificationsEnabled)
        XCTAssertEqual(store.notificationAuthorizationStatus, .notDetermined)
    }

    @MainActor
    func testSettingsStoreNotificationPreferenceIsIndependentFromAuthorization() {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        store.notificationAuthorizationStatus = .authorized
        store.notificationsEnabled = false

        XCTAssertFalse(store.notificationsEnabled)
        XCTAssertEqual(store.notificationAuthorizationStatus, .authorized)
    }

    @MainActor
    func testSettingsStoreDownAlertSoundCooldownDefaultsAndPersists() {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(store.downAlertSoundCooldown, AppConstants.downAlertSoundCooldown)

        store.downAlertSoundCooldown = DownAlertSoundCooldownOption.oneMinute.rawValue

        XCTAssertEqual(store.downAlertSoundCooldown, 60)
    }

    @MainActor
    func testSettingsStoreMaintainsDefaultConnectionWhenUpdatingAndRemoving() {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let primary = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        let secondary = ServerConnection(
            name: "Secondary",
            baseURL: URL(string: "https://secondary.example.com")!,
            statusPageSlug: "secondary",
            isDefault: false
        )

        store.addConnection(primary)
        store.addConnection(secondary)
        store.setDefaultConnection(id: secondary.id)

        XCTAssertEqual(store.serverConnection?.id, secondary.id)

        store.removeConnection(id: secondary.id)

        XCTAssertEqual(store.serverConnections.count, 1)
        XCTAssertEqual(store.serverConnection?.id, primary.id)
        XCTAssertTrue(store.serverConnections[0].isDefault)
    }

    @MainActor
    func testSettingsStoreServerConnectionSetterKeepsSingleDefault() {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let primary = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        let secondary = ServerConnection(
            name: "Secondary",
            baseURL: URL(string: "https://secondary.example.com")!,
            statusPageSlug: "secondary",
            isDefault: false
        )

        store.addConnection(primary)
        store.addConnection(secondary)

        store.serverConnection = ServerConnection(
            id: secondary.id,
            name: secondary.name,
            baseURL: secondary.baseURL,
            statusPageSlug: secondary.statusPageSlug,
            isDefault: true
        )

        XCTAssertEqual(store.serverConnection?.id, secondary.id)
        XCTAssertEqual(store.serverConnections.filter(\.isDefault).count, 1)
    }

    func testServerConnectionNormalizedDisplayNameFallsBackForWhitespaceOnlyInput() {
        XCTAssertEqual(
            ServerConnection.normalizedDisplayName(from: "   \n\t  "),
            String(localized: "My Kuma Server")
        )
        XCTAssertEqual(
            ServerConnection.normalizedDisplayName(from: "  Primary  "),
            "Primary"
        )
    }

    func testServerConnectionNormalizedStatusPageSlugTrimsOuterSlashesAndRejectsNestedPaths() {
        XCTAssertEqual(
            ServerConnection.normalizedStatusPageSlug(from: "  /status-page/  "),
            "status-page"
        )
        XCTAssertEqual(
            ServerConnection.validatedStatusPageSlug(from: "  /primary-status/  "),
            "primary-status"
        )
        XCTAssertNil(ServerConnection.validatedStatusPageSlug(from: "team/primary"))
        XCTAssertNil(ServerConnection.validatedStatusPageSlug(from: "   ///   "))
    }

    @MainActor
    func testSettingsStoreAcknowledgedMonitorRoundTrip() {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connectionId = UUID()
        let monitorId = "api"

        XCTAssertFalse(store.isMonitorAcknowledged(connectionId: connectionId, monitorId: monitorId))

        store.acknowledgeMonitor(connectionId: connectionId, monitorId: monitorId)
        XCTAssertTrue(store.isMonitorAcknowledged(connectionId: connectionId, monitorId: monitorId))

        store.unacknowledgeMonitor(connectionId: connectionId, monitorId: monitorId)
        XCTAssertFalse(store.isMonitorAcknowledged(connectionId: connectionId, monitorId: monitorId))
    }

    func testMonitorPreferencePinAndHideStayMutuallyExclusive() {
        let preference = MonitorPreference(monitorId: "worker", serverConnectionId: UUID())

        preference.pin()
        XCTAssertTrue(preference.isPinned)
        XCTAssertFalse(preference.isHidden)

        preference.hide()
        XCTAssertTrue(preference.isHidden)
        XCTAssertFalse(preference.isPinned)

        preference.pin()
        XCTAssertTrue(preference.isPinned)
        XCTAssertFalse(preference.isHidden)
    }

    @MainActor
    func testPollingEngineBackoffCapsAndResets() {
        let engine = PollingEngine()
        engine.interval = 30

        XCTAssertEqual(engine.effectiveInterval, 30)

        for _ in 0..<5 {
            engine.reportFailure()
        }

        XCTAssertEqual(engine.effectiveInterval, 300)

        engine.reportSuccess()
        XCTAssertEqual(engine.effectiveInterval, 30)
    }

    @MainActor
    func testPollingEngineReschedulesTimerWhenBackoffChanges() {
        let engine = PollingEngine()
        engine.interval = 30
        engine.start { }
        defer { engine.stop() }

        XCTAssertEqual(engine.scheduledTimerInterval, 30)

        engine.reportFailure()
        XCTAssertEqual(engine.scheduledTimerInterval, 60)

        engine.reportFailure()
        XCTAssertEqual(engine.scheduledTimerInterval, 120)

        engine.reportSuccess()
        XCTAssertEqual(engine.scheduledTimerInterval, 30)
    }

    @MainActor
    func testPersistenceManagerDeduplicatesRepeatedIncidentsWithinWindow() async throws {
        let manager = try PersistenceManager(isStoredInMemoryOnly: true)
        let timestamp = Date()
        let serverConnectionId = UUID()

        await manager.recordIncident(IncidentRecordSnapshot(
            monitorId: "api",
            monitorName: "API",
            serverConnectionId: serverConnectionId,
            serverName: "Prod",
            transitionType: .wentDown,
            timestamp: timestamp
        ))
        await manager.recordIncident(IncidentRecordSnapshot(
            monitorId: "api",
            monitorName: "API",
            serverConnectionId: serverConnectionId,
            serverName: "Prod",
            transitionType: .wentDown,
            timestamp: timestamp.addingTimeInterval(30)
        ))

        let incidents = await manager.fetchRecentIncidents(limit: 10)
        XCTAssertEqual(incidents.count, 1)
    }

    @MainActor
    func testPersistenceManagerPurgesOnlyExpiredIncidents() async throws {
        let manager = try PersistenceManager(isStoredInMemoryOnly: true)

        await manager.recordIncident(IncidentRecordSnapshot(
            monitorId: "old",
            monitorName: "Old Monitor",
            serverConnectionId: UUID(),
            serverName: "Prod",
            transitionType: .wentDown,
            timestamp: Calendar.current.date(byAdding: .day, value: -91, to: Date())!
        ))
        await manager.recordIncident(IncidentRecordSnapshot(
            monitorId: "recent",
            monitorName: "Recent Monitor",
            serverConnectionId: UUID(),
            serverName: "Prod",
            transitionType: .recovered,
            timestamp: Date(),
            downDuration: 42
        ))

        await manager.purgeOldIncidents(olderThan: 90)

        let incidents = await manager.fetchRecentIncidents(limit: 10)
        XCTAssertEqual(incidents.count, 1)
        XCTAssertEqual(incidents.first?.monitorId, "recent")
    }

    @MainActor
    func testPersistenceManagerDefaultPurgeUsesAppRetentionWindow() async throws {
        let manager = try PersistenceManager(isStoredInMemoryOnly: true)

        await manager.recordIncident(IncidentRecordSnapshot(
            monitorId: "expired",
            monitorName: "Expired Monitor",
            serverConnectionId: UUID(),
            serverName: "Prod",
            transitionType: .wentDown,
            timestamp: Calendar.current.date(
                byAdding: .day,
                value: -(AppConstants.incidentRetentionDays + 1),
                to: Date()
            )!
        ))
        await manager.recordIncident(IncidentRecordSnapshot(
            monitorId: "retained",
            monitorName: "Retained Monitor",
            serverConnectionId: UUID(),
            serverName: "Prod",
            transitionType: .wentDown,
            timestamp: Calendar.current.date(
                byAdding: .day,
                value: -(AppConstants.incidentRetentionDays - 1),
                to: Date()
            )!
        ))

        await manager.purgeOldIncidents()

        let incidents = await manager.fetchRecentIncidents(limit: 10)
        XCTAssertEqual(incidents.count, 1)
        XCTAssertEqual(incidents.first?.monitorId, "retained")
    }

    @MainActor
    func testMenuBarViewModelPublishesOfflineWidgetSnapshotAndReloadsWidget() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        store.addConnection(connection)

        let widgetSuiteName = "KumaNotifyTests.widget.\(UUID().uuidString)"
        let widgetDefaults = UserDefaults(suiteName: widgetSuiteName)!
        UserDefaults.standard.removePersistentDomain(forName: widgetSuiteName)
        defer { UserDefaults.standard.removePersistentDomain(forName: widgetSuiteName) }

        let networkMonitor = NetworkMonitor()
        networkMonitor.isConnected = false

        var reloadCount = 0
        let pollingEngine = PollingEngine()
        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: pollingEngine,
            networkMonitor: networkMonitor,
            widgetDefaults: widgetDefaults,
            reloadWidgets: { reloadCount += 1 },
            shouldStartMonitors: false
        )

        await viewModel.refresh()

        let widgetData = WidgetData.read(from: widgetDefaults)
        XCTAssertEqual(viewModel.errorMessage, String(localized: "No network connection"))
        XCTAssertEqual(widgetData?.overallStatusRaw, "unreachable")
        XCTAssertEqual(widgetData?.upCount, 0)
        XCTAssertEqual(widgetData?.totalCount, 0)
        XCTAssertEqual(pollingEngine.consecutiveFailures, 1)
        XCTAssertEqual(pollingEngine.effectiveInterval, AppConstants.defaultPollingInterval * 2)
        XCTAssertEqual(reloadCount, 1)
    }

    @MainActor
    func testMenuBarViewModelRefreshesNotificationAuthorizationStatusDuringPolling() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        store.addConnection(connection)
        store.notificationAuthorizationStatus = .denied

        let networkMonitor = NetworkMonitor()
        networkMonitor.isConnected = false

        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: PollingEngine(),
            networkMonitor: networkMonitor,
            notificationAuthorizationStatusProvider: { .authorized },
            shouldStartMonitors: false
        )

        await viewModel.refresh()

        XCTAssertEqual(store.notificationAuthorizationStatus, .authorized)
    }

    @MainActor
    func testMenuBarViewModelClearsConnectionSnapshotsWhenNetworkGoesOffline() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        store.addConnection(connection)

        let networkMonitor = NetworkMonitor()
        networkMonitor.isConnected = true

        let monitor = UnifiedMonitor(
            id: "api",
            name: "API",
            type: "http",
            currentStatus: .up,
            latestPing: 90,
            uptime24h: 1,
            uptime7d: 1,
            uptime30d: 1,
            certExpiryDays: nil,
            validCert: nil,
            url: nil,
            lastStatusChange: nil
        )
        let result = StatusPageResult(
            title: "Primary",
            groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: [monitor])],
            heartbeats: [:],
            incidents: [],
            maintenances: [],
            showCertExpiry: false
        )
        let service = ScriptedMonitoringService { _ in result }

        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: PollingEngine(),
            serviceFactory: { _ in service },
            networkMonitor: networkMonitor,
            shouldStartMonitors: false
        )

        await viewModel.refresh()
        XCTAssertNotNil(viewModel.statusPageResult(for: connection.id))

        networkMonitor.isConnected = false
        await viewModel.refresh()

        XCTAssertNil(viewModel.statusPageResult(for: connection.id))
        XCTAssertEqual(
            viewModel.connectionErrorMessage(for: connection.id),
            String(localized: "No network connection")
        )
    }

    @MainActor
    func testMenuBarViewModelMarksAggregateStatusUnreachableWhenAnyServerFails() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let primary = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        let secondary = ServerConnection(
            name: "Secondary",
            baseURL: URL(string: "https://secondary.example.com")!,
            statusPageSlug: "secondary",
            isDefault: false
        )
        store.addConnection(primary)
        store.addConnection(secondary)

        let widgetSuiteName = "KumaNotifyTests.widget.aggregate.\(UUID().uuidString)"
        let widgetDefaults = UserDefaults(suiteName: widgetSuiteName)!
        UserDefaults.standard.removePersistentDomain(forName: widgetSuiteName)
        defer { UserDefaults.standard.removePersistentDomain(forName: widgetSuiteName) }

        let monitor = UnifiedMonitor(
            id: "api",
            name: "API",
            type: "http",
            currentStatus: .up,
            latestPing: 90,
            uptime24h: 1,
            uptime7d: 1,
            uptime30d: 1,
            certExpiryDays: nil,
            validCert: nil,
            url: nil,
            lastStatusChange: nil
        )
        let result = StatusPageResult(
            title: "Primary",
            groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: [monitor])],
            heartbeats: [:],
            incidents: [],
            maintenances: [],
            showCertExpiry: false
        )
        let service = ScriptedMonitoringService { connection in
            if connection.id == primary.id {
                return result
            }
            throw APIError.serverUnreachable
        }

        let networkMonitor = NetworkMonitor()
        networkMonitor.isConnected = true

        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: PollingEngine(),
            serviceFactory: { _ in service },
            networkMonitor: networkMonitor,
            widgetDefaults: widgetDefaults,
            shouldStartMonitors: false
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.errorMessage, String(localized: "Server unreachable"))
        if case .unreachable = viewModel.overallStatus {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected aggregate status to be unreachable when one server fails")
        }

        let widgetData = WidgetData.read(from: widgetDefaults)
        XCTAssertNil(widgetData?.serverName)
        XCTAssertEqual(widgetData?.overallStatusRaw, "unreachable")
    }

    @MainActor
    func testMenuBarViewModelTreatsEmptySuccessfulStatusPageAsNoData() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        store.addConnection(connection)

        let service = ScriptedMonitoringService { _ in
            StatusPageResult(
                title: "Primary",
                groups: [],
                heartbeats: [:],
                incidents: [],
                maintenances: [],
                showCertExpiry: false
            )
        }

        let networkMonitor = NetworkMonitor()
        networkMonitor.isConnected = true

        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: PollingEngine(),
            serviceFactory: { _ in service },
            networkMonitor: networkMonitor,
            shouldStartMonitors: false
        )

        await viewModel.refresh()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.totalCount, 0)
        if case .unreachable = viewModel.overallStatus {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected empty successful status pages to surface as no data")
        }
    }

    @MainActor
    func testMenuBarViewModelTracksTransitionsWhenNotificationsAreDisabled() async throws {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        store.addConnection(connection)
        store.notificationsEnabled = false
        store.acknowledgeMonitor(connectionId: connection.id, monitorId: "api")

        let persistence = try PersistenceManager(isStoredInMemoryOnly: true)
        let networkMonitor = NetworkMonitor()
        networkMonitor.isConnected = true

        func makeResult(status: MonitorStatus) -> StatusPageResult {
            let monitor = UnifiedMonitor(
                id: "api",
                name: "API",
                type: "http",
                currentStatus: status,
                latestPing: 90,
                uptime24h: 1,
                uptime7d: 1,
                uptime30d: 1,
                certExpiryDays: nil,
                validCert: nil,
                url: nil,
                lastStatusChange: nil
            )
            return StatusPageResult(
                title: "Primary",
                groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: [monitor])],
                heartbeats: [:],
                incidents: [],
                maintenances: [],
                showCertExpiry: false
            )
        }

        let service = SequencedMonitoringService(results: [
            makeResult(status: .up),
            makeResult(status: .down),
            makeResult(status: .up),
        ])

        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: PollingEngine(),
            serviceFactory: { _ in service },
            networkMonitor: networkMonitor,
            persistence: persistence,
            shouldStartMonitors: false
        )

        await viewModel.refresh()
        await viewModel.refresh()
        await viewModel.refresh()

        let incidents = await persistence.fetchRecentIncidents(serverConnectionId: connection.id, limit: 10)
        XCTAssertEqual(incidents.count, 2)
        XCTAssertEqual(incidents.map(\.transitionType), [.recovered, .wentDown])
        XCTAssertFalse(store.isMonitorAcknowledged(connectionId: connection.id, monitorId: "api"))
    }

    @MainActor
    func testMenuBarViewModelSendsCertExpiryWarningsWithoutDuplicatingSameDayCount() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        store.addConnection(connection)
        store.notificationsEnabled = true
        store.notificationAuthorizationStatus = .authorized

        let networkMonitor = NetworkMonitor()
        networkMonitor.isConnected = true

        func makeResult(daysRemaining: Int) -> StatusPageResult {
            let monitor = UnifiedMonitor(
                id: "api",
                name: "API",
                type: "http",
                currentStatus: .up,
                latestPing: 90,
                uptime24h: 1,
                uptime7d: 1,
                uptime30d: 1,
                certExpiryDays: daysRemaining,
                validCert: true,
                url: nil,
                lastStatusChange: nil
            )
            return StatusPageResult(
                title: "Primary",
                groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: [monitor])],
                heartbeats: [:],
                incidents: [],
                maintenances: [],
                showCertExpiry: true
            )
        }

        let service = SequencedMonitoringService(results: [
            makeResult(daysRemaining: 7),
            makeResult(daysRemaining: 7),
            makeResult(daysRemaining: 6),
        ])
        let notifications = NotificationSpy()

        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: PollingEngine(),
            serviceFactory: { _ in service },
            networkMonitor: networkMonitor,
            notifications: notifications,
            notificationAuthorizationStatusProvider: { .authorized },
            shouldStartMonitors: false
        )

        await viewModel.refresh()
        await viewModel.refresh()
        await viewModel.refresh()

        XCTAssertEqual(notifications.certExpiryWarnings.count, 2)
        XCTAssertEqual(notifications.certExpiryWarnings[0].0, connection.id)
        XCTAssertEqual(notifications.certExpiryWarnings[0].1, "api")
        XCTAssertEqual(notifications.certExpiryWarnings[0].2, 7)
        XCTAssertEqual(notifications.certExpiryWarnings[1].0, connection.id)
        XCTAssertEqual(notifications.certExpiryWarnings[1].1, "api")
        XCTAssertEqual(notifications.certExpiryWarnings[1].2, 6)
    }

    @MainActor
    func testMenuBarViewModelOnlyPlaysDownAlertSoundOnceForBurstFailures() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        store.addConnection(connection)
        store.notificationsEnabled = true
        store.notificationAuthorizationStatus = .authorized
        store.notificationSound = .system

        let networkMonitor = NetworkMonitor()
        networkMonitor.isConnected = true

        let upMonitors = [
            UnifiedMonitor(
                id: "api",
                name: "API",
                type: "http",
                currentStatus: .up,
                latestPing: 120,
                uptime24h: 1,
                uptime7d: 1,
                uptime30d: 1,
                certExpiryDays: nil,
                validCert: nil,
                url: nil,
                lastStatusChange: nil
            ),
            UnifiedMonitor(
                id: "web",
                name: "Web",
                type: "http",
                currentStatus: .up,
                latestPing: 130,
                uptime24h: 1,
                uptime7d: 1,
                uptime30d: 1,
                certExpiryDays: nil,
                validCert: nil,
                url: nil,
                lastStatusChange: nil
            )
        ]

        let downMonitors = [
            UnifiedMonitor(
                id: "api",
                name: "API",
                type: "http",
                currentStatus: .down,
                latestPing: nil,
                uptime24h: 1,
                uptime7d: 1,
                uptime30d: 1,
                certExpiryDays: nil,
                validCert: nil,
                url: nil,
                lastStatusChange: nil
            ),
            UnifiedMonitor(
                id: "web",
                name: "Web",
                type: "http",
                currentStatus: .down,
                latestPing: nil,
                uptime24h: 1,
                uptime7d: 1,
                uptime30d: 1,
                certExpiryDays: nil,
                validCert: nil,
                url: nil,
                lastStatusChange: nil
            )
        ]

        let service = SequencedMonitoringService(results: [
            StatusPageResult(
                title: "Primary",
                groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: upMonitors)],
                heartbeats: [:],
                incidents: [],
                maintenances: [],
                showCertExpiry: true
            ),
            StatusPageResult(
                title: "Primary",
                groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: downMonitors)],
                heartbeats: [:],
                incidents: [],
                maintenances: [],
                showCertExpiry: true
            )
        ])
        let notifications = NotificationSpy()

        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: PollingEngine(),
            serviceFactory: { _ in service },
            networkMonitor: networkMonitor,
            notifications: notifications,
            notificationAuthorizationStatusProvider: { .authorized },
            shouldStartMonitors: false
        )

        await viewModel.refresh()
        await viewModel.refresh()

        XCTAssertEqual(notifications.downAlerts.count, 2)
        XCTAssertEqual(notifications.downAlertSoundOptions, [.system, .silent])
    }

    @MainActor
    func testMenuBarViewModelCanPlayEveryDownAlertWhenCooldownDisabled() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        store.addConnection(connection)
        store.notificationsEnabled = true
        store.notificationAuthorizationStatus = .authorized
        store.notificationSound = .system
        store.downAlertSoundCooldown = DownAlertSoundCooldownOption.everyAlert.rawValue

        let networkMonitor = NetworkMonitor()
        networkMonitor.isConnected = true

        let upMonitors = [
            UnifiedMonitor(
                id: "api",
                name: "API",
                type: "http",
                currentStatus: .up,
                latestPing: 120,
                uptime24h: 1,
                uptime7d: 1,
                uptime30d: 1,
                certExpiryDays: nil,
                validCert: nil,
                url: nil,
                lastStatusChange: nil
            ),
            UnifiedMonitor(
                id: "web",
                name: "Web",
                type: "http",
                currentStatus: .up,
                latestPing: 130,
                uptime24h: 1,
                uptime7d: 1,
                uptime30d: 1,
                certExpiryDays: nil,
                validCert: nil,
                url: nil,
                lastStatusChange: nil
            )
        ]

        let downMonitors = [
            UnifiedMonitor(
                id: "api",
                name: "API",
                type: "http",
                currentStatus: .down,
                latestPing: nil,
                uptime24h: 1,
                uptime7d: 1,
                uptime30d: 1,
                certExpiryDays: nil,
                validCert: nil,
                url: nil,
                lastStatusChange: nil
            ),
            UnifiedMonitor(
                id: "web",
                name: "Web",
                type: "http",
                currentStatus: .down,
                latestPing: nil,
                uptime24h: 1,
                uptime7d: 1,
                uptime30d: 1,
                certExpiryDays: nil,
                validCert: nil,
                url: nil,
                lastStatusChange: nil
            )
        ]

        let service = SequencedMonitoringService(results: [
            StatusPageResult(
                title: "Primary",
                groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: upMonitors)],
                heartbeats: [:],
                incidents: [],
                maintenances: [],
                showCertExpiry: true
            ),
            StatusPageResult(
                title: "Primary",
                groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: downMonitors)],
                heartbeats: [:],
                incidents: [],
                maintenances: [],
                showCertExpiry: true
            )
        ])
        let notifications = NotificationSpy()

        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: PollingEngine(),
            serviceFactory: { _ in service },
            networkMonitor: networkMonitor,
            notifications: notifications,
            notificationAuthorizationStatusProvider: { .authorized },
            shouldStartMonitors: false
        )

        await viewModel.refresh()
        await viewModel.refresh()

        XCTAssertEqual(notifications.downAlerts.count, 2)
        XCTAssertEqual(notifications.downAlertSoundOptions, [.system, .system])
    }

    @MainActor
    func testMenuBarViewModelPrunesMissingMonitorStateBeforeLaterRecovery() async throws {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        store.addConnection(connection)
        store.notificationsEnabled = false

        let persistence = try PersistenceManager(isStoredInMemoryOnly: true)
        let networkMonitor = NetworkMonitor()
        networkMonitor.isConnected = true

        func makeResult(monitors: [UnifiedMonitor]) -> StatusPageResult {
            StatusPageResult(
                title: "Primary",
                groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: monitors)],
                heartbeats: [:],
                incidents: [],
                maintenances: [],
                showCertExpiry: false
            )
        }

        let upMonitor = UnifiedMonitor(
            id: "api",
            name: "API",
            type: "http",
            currentStatus: .up,
            latestPing: 90,
            uptime24h: 1,
            uptime7d: 1,
            uptime30d: 1,
            certExpiryDays: nil,
            validCert: nil,
            url: nil,
            lastStatusChange: nil
        )
        let downMonitor = UnifiedMonitor(
            id: "api",
            name: "API",
            type: "http",
            currentStatus: .down,
            latestPing: 90,
            uptime24h: 1,
            uptime7d: 1,
            uptime30d: 1,
            certExpiryDays: nil,
            validCert: nil,
            url: nil,
            lastStatusChange: nil
        )

        let service = SequencedMonitoringService(results: [
            makeResult(monitors: [upMonitor]),
            makeResult(monitors: [downMonitor]),
            makeResult(monitors: []),
            makeResult(monitors: [upMonitor]),
        ])

        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: PollingEngine(),
            serviceFactory: { _ in service },
            networkMonitor: networkMonitor,
            persistence: persistence,
            shouldStartMonitors: false
        )

        await viewModel.refresh()
        await viewModel.refresh()
        await viewModel.refresh()
        await viewModel.refresh()

        let incidents = await persistence.fetchRecentIncidents(serverConnectionId: connection.id, limit: 10)
        XCTAssertEqual(incidents.count, 1)
        XCTAssertEqual(incidents.first?.transitionType, .wentDown)
    }

    @MainActor
    func testStoreManagerEntitlementStateMarksRestoredPurchaseAsPurchased() {
        let storeManager = StoreManager(startListeningForTransactions: false, autoRefresh: false)

        storeManager.applyEntitlementState(isEntitled: true)
        XCTAssertTrue(storeManager.proUnlocked)
        XCTAssertEqual(storeManager.purchaseState, .purchased)

        storeManager.applyEntitlementState(isEntitled: false)
        XCTAssertFalse(storeManager.proUnlocked)
        XCTAssertEqual(storeManager.purchaseState, .idle)
    }

    @MainActor
    func testStoreManagerRestoreFailuresSurfacePurchaseError() async {
        let storeManager = StoreManager(
            syncAppStore: { throw FailingTestError() },
            startListeningForTransactions: false,
            autoRefresh: false
        )

        await storeManager.restorePurchases()

        guard case .failed(let message) = storeManager.purchaseState else {
            return XCTFail("Expected restore failures to be surfaced in purchaseState")
        }
        XCTAssertEqual(message, "Restore failed")
    }

    @MainActor
    func testStoreManagerProductLoadFailuresSurfacePaywallError() async {
        let storeManager = StoreManager(
            fetchProducts: { _ in throw FailingTestError() },
            startListeningForTransactions: false,
            autoRefresh: false
        )

        await storeManager.refreshStatus()

        XCTAssertNil(storeManager.proProduct)
        XCTAssertEqual(storeManager.productLoadErrorMessage, "Restore failed")
    }

    @MainActor
    func testStoreManagerRefreshStatusClearsStaleFailureAfterSuccessfulRecovery() async {
        let storeManager = StoreManager(
            fetchProducts: { _ in [] },
            syncAppStore: { throw FailingTestError() },
            startListeningForTransactions: false,
            autoRefresh: false
        )

        await storeManager.restorePurchases()
        guard case .failed = storeManager.purchaseState else {
            return XCTFail("Expected restore failure to put purchaseState into failed")
        }

        await storeManager.refreshStatus()

        XCTAssertEqual(storeManager.purchaseState, .idle)
        XCTAssertNil(storeManager.productLoadErrorMessage)
        XCTAssertFalse(storeManager.proUnlocked)
    }

    @MainActor
    func testStoreManagerDeinitCancelsTransactionListener() async {
        let cancellationExpectation = expectation(description: "transaction listener cancelled")
        var externalTask: Task<Void, Never>?
        weak var weakManager: StoreManager?

        autoreleasepool {
            let storeManager = StoreManager(
                fetchProducts: { _ in [] },
                syncAppStore: {},
                transactionListenerFactory: { _ in
                    let task = Task<Void, Never> {
                        defer { cancellationExpectation.fulfill() }
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .milliseconds(10))
                        }
                    }
                    externalTask = task
                    return task
                },
                startListeningForTransactions: true,
                autoRefresh: false
            )
            weakManager = storeManager
        }

        XCTAssertNil(weakManager)
        await fulfillment(of: [cancellationExpectation], timeout: 1)
        XCTAssertTrue(externalTask?.isCancelled ?? false)
    }

    func testIntentStatusFormatterBuildsLocalizedSummaries() {
        let data = WidgetData(
            upCount: 3,
            totalCount: 5,
            downCount: 2,
            overallStatusRaw: "someDown",
            lastCheckTime: nil,
            serverName: "Prod",
            hasActiveIncident: true
        )

        let statusSummary = IntentStatusFormatter.statusSummary(for: data)
        XCTAssertTrue(statusSummary.value.contains(WidgetData.monitorSummaryLine(upCount: 3, totalCount: 5)))
        XCTAssertTrue(statusSummary.value.contains("2"))
        XCTAssertFalse(statusSummary.value.contains("OK"))

        let monitorCounts = IntentStatusFormatter.monitorCountSummary(for: data)
        XCTAssertTrue(monitorCounts.contains("3"))
        XCTAssertTrue(monitorCounts.contains("2"))
        XCTAssertTrue(monitorCounts.contains("5"))
    }

    func testIntentStatusFormatterOmitsCountsWhenStatusIsUnreachable() {
        let data = WidgetData(
            upCount: 5,
            totalCount: 5,
            downCount: 0,
            overallStatusRaw: "unreachable",
            lastCheckTime: nil,
            serverName: nil,
            hasActiveIncident: true
        )

        let statusSummary = IntentStatusFormatter.statusSummary(for: data)
        XCTAssertEqual(statusSummary.value, OverallStatus.unreachable.label)

        let monitorCounts = IntentStatusFormatter.monitorCountSummary(for: data)
        XCTAssertEqual(monitorCounts, OverallStatus.unreachable.label)
    }

    func testLocalizableCatalogContainsSystemSurfaceMetadata() throws {
        let contents = try localizableCatalogContents()

        [
            "Check Monitor Status",
            "Returns the current status of your monitored services.",
            "Get Monitor Count",
            "Returns how many monitors are up and total.",
            "Check Status",
            "Check %@ status",
            "How are my monitors in %@?",
            "Are my servers up in %@?",
            "Monitor your services at a glance.",
            "Notifications Disabled in System Settings",
            "Notifications are currently blocked by System Settings.",
            "Allow notifications for Kuma Notify in System Settings, then enable them again here.",
            "Open System Settings",
            "Retry",
            "Invalid status page slug",
            "%lld up / %lld total",
            "%@ — %@",
            "%1$@ current, %2$@ min, %3$@ max",
            "Uptime %@",
            "Uptime %@ (%@)"
        ].forEach { key in
            XCTAssertTrue(contents.contains("\"\(key)\""), "Missing localization key: \(key)")
        }
    }

    @MainActor
    func testPersistenceManagerFetchRecentIncidentsCanScopeToConnection() async throws {
        let manager = try PersistenceManager(isStoredInMemoryOnly: true)
        let primaryID = UUID()
        let secondaryID = UUID()

        await manager.recordIncident(IncidentRecordSnapshot(
            monitorId: "primary-api",
            monitorName: "Primary API",
            serverConnectionId: primaryID,
            serverName: "Primary",
            transitionType: .wentDown
        ))
        await manager.recordIncident(IncidentRecordSnapshot(
            monitorId: "secondary-api",
            monitorName: "Secondary API",
            serverConnectionId: secondaryID,
            serverName: "Secondary",
            transitionType: .wentDown
        ))

        let primaryIncidents = await manager.fetchRecentIncidents(serverConnectionId: primaryID, limit: 10)

        XCTAssertEqual(primaryIncidents.count, 1)
        XCTAssertEqual(primaryIncidents.first?.serverConnectionId, primaryID)
    }

    @MainActor
    func testDashboardViewModelScopesIncidentHistoryAndExportsToSelectedConnection() async throws {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let manager = try PersistenceManager(isStoredInMemoryOnly: true)
        let primaryID = UUID()
        let secondaryID = UUID()

        let primaryConnection = ServerConnection(
            id: primaryID,
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )

        await manager.recordIncident(IncidentRecordSnapshot(
            monitorId: "secondary-api",
            monitorName: "Secondary API",
            serverConnectionId: secondaryID,
            serverName: "Secondary",
            transitionType: .wentDown,
            timestamp: Date().addingTimeInterval(-300)
        ))
        await manager.recordIncident(IncidentRecordSnapshot(
            monitorId: "primary-api",
            monitorName: "Primary API",
            serverConnectionId: primaryID,
            serverName: "Primary",
            transitionType: .recovered,
            timestamp: Date(),
            downDuration: 42
        ))

        let viewModel = DashboardViewModel(
            connection: primaryConnection,
            settingsStore: store,
            persistence: manager
        )

        await viewModel.loadIncidentHistory()
        await viewModel.loadLastIncidentDate()

        XCTAssertEqual(viewModel.incidentRecords.count, 1)
        XCTAssertEqual(viewModel.incidentRecords.first?.serverConnectionId, primaryID)
        XCTAssertNotNil(viewModel.lastIncidentDate)

        let exportResult = await viewModel.exportIncidentsJSON()
        let exportURL = try XCTUnwrap(exportResult)
        defer { try? FileManager.default.removeItem(at: exportURL) }

        let data = try Data(contentsOf: exportURL)
        let items = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        )

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?["serverName"] as? String, "Primary")
    }

    @MainActor
    func testDashboardViewModelEscapesCSVFieldsWithCommasQuotesAndNewlines() async throws {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let manager = try PersistenceManager(isStoredInMemoryOnly: true)
        let connectionID = UUID()
        let connection = ServerConnection(
            id: connectionID,
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )

        await manager.recordIncident(IncidentRecordSnapshot(
            monitorId: "api",
            monitorName: "API, \"Edge\"",
            serverConnectionId: connectionID,
            serverName: "Primary\nEU",
            transitionType: .recovered,
            timestamp: Date(timeIntervalSince1970: 0),
            downDuration: 42
        ))

        let viewModel = DashboardViewModel(
            connection: connection,
            settingsStore: store,
            persistence: manager
        )

        let exportResult = await viewModel.exportIncidentsCSV()
        let exportURL = try XCTUnwrap(exportResult)
        defer { try? FileManager.default.removeItem(at: exportURL) }

        let csv = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertTrue(csv.contains("\"API, \"\"Edge\"\"\""))
        XCTAssertTrue(csv.contains("\"Primary\nEU\""))
        XCTAssertTrue(csv.contains("1970-01-01T00:00:00"))
        XCTAssertTrue(csv.contains(",recovered,42"))

    }

    @MainActor
    func testDashboardViewModelBuildEmailReportEncodesBodyWithReservedCharacters() throws {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        let viewModel = DashboardViewModel(connection: connection, settingsStore: store)

        viewModel.groups = [
            UnifiedGroup(
                id: "g1",
                name: "Core & Edge",
                weight: 0,
                monitors: [
                    UnifiedMonitor(
                        id: "api",
                        name: "API & Edge?",
                        type: "http",
                        currentStatus: .up,
                        latestPing: 90,
                        uptime24h: 1,
                        uptime7d: 1,
                        uptime30d: 1,
                        certExpiryDays: nil,
                        validCert: nil,
                        url: nil,
                        lastStatusChange: nil
                    )
                ]
            )
        ]

        let url = try XCTUnwrap(viewModel.buildEmailReport())
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let subject = components.queryItems?.first(where: { $0.name == "subject" })?.value
        let body = components.queryItems?.first(where: { $0.name == "body" })?.value

        XCTAssertEqual(subject, String(localized: "Kuma Notify — Status Report"))
        XCTAssertTrue(body?.contains("Core & Edge") == true)
        XCTAssertTrue(body?.contains("API & Edge?") == true)
        XCTAssertTrue(body?.contains("&") == true)
    }

    @MainActor
    func testDashboardViewModelUsesHeartbeatsFromStatusPageResultWithoutExtraFetch() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        let monitor = UnifiedMonitor(
            id: "api",
            name: "API",
            type: "http",
            currentStatus: .up,
            latestPing: 90,
            uptime24h: 1,
            uptime7d: 1,
            uptime30d: 1,
            certExpiryDays: nil,
            validCert: nil,
            url: nil,
            lastStatusChange: nil
        )
        let heartbeat = UnifiedHeartbeat(
            status: .up,
            time: Date(),
            message: "OK",
            ping: 90
        )
        let service = CountingMonitoringService(
            result: StatusPageResult(
                title: "Primary",
                groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: [monitor])],
                heartbeats: ["api": [heartbeat]],
                incidents: [],
                maintenances: [],
                showCertExpiry: false
            )
        )
        let viewModel = DashboardViewModel(
            connection: connection,
            settingsStore: store,
            serviceFactory: { _ in service }
        )

        await viewModel.fetchData()
        let counts = await service.callCounts()

        XCTAssertEqual(counts.statusPage, 1)
        XCTAssertEqual(counts.heartbeat, 0)
        XCTAssertEqual(viewModel.heartbeats["api"]?.count, 1)
    }

    @MainActor
    func testDashboardViewModelComputesConnectionScopedOverallStatus() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        let service = ScriptedMonitoringService { _ in
            let monitors = [
                UnifiedMonitor(
                    id: "api",
                    name: "API",
                    type: "http",
                    currentStatus: .up,
                    latestPing: 120,
                    uptime24h: 1,
                    uptime7d: 1,
                    uptime30d: 1,
                    certExpiryDays: nil,
                    validCert: nil,
                    url: nil,
                    lastStatusChange: nil
                ),
                UnifiedMonitor(
                    id: "worker",
                    name: "Worker",
                    type: "http",
                    currentStatus: .down,
                    latestPing: 70,
                    uptime24h: 0.94,
                    uptime7d: 0.94,
                    uptime30d: 0.94,
                    certExpiryDays: nil,
                    validCert: nil,
                    url: nil,
                    lastStatusChange: nil
                )
            ]
            return StatusPageResult(
                title: "Primary",
                groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: monitors)],
                heartbeats: [:],
                incidents: [],
                maintenances: [],
                showCertExpiry: false
            )
        }
        let viewModel = DashboardViewModel(
            connection: connection,
            settingsStore: store,
            serviceFactory: { _ in service }
        )

        await viewModel.fetchData()

        guard case .someDown(let count, let total) = viewModel.overallStatus else {
            return XCTFail("Expected connection-scoped status to reflect selected server monitors")
        }
        XCTAssertEqual(count, 1)
        XCTAssertEqual(total, 2)
    }

    @MainActor
    func testDashboardViewModelClearsStaleDataWhenRefreshFails() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        let viewModel = DashboardViewModel(
            connection: connection,
            settingsStore: store,
            serviceFactory: { _ in
                ScriptedMonitoringService { _ in
                    throw APIError.serverUnreachable
                }
            }
        )

        viewModel.groups = [
            UnifiedGroup(
                id: "g1",
                name: "Core",
                weight: 0,
                monitors: [
                    UnifiedMonitor(
                        id: "api",
                        name: "API",
                        type: "http",
                        currentStatus: .up,
                        latestPing: 120,
                        uptime24h: 1,
                        uptime7d: 1,
                        uptime30d: 1,
                        certExpiryDays: nil,
                        validCert: nil,
                        url: nil,
                        lastStatusChange: nil
                    )
                ]
            )
        ]
        viewModel.heartbeats = ["api": []]
        viewModel.incidents = [
            UKIncident(
                id: nil,
                title: "Outage",
                content: nil,
                style: "danger",
                createdDate: nil,
                lastUpdatedDate: nil
            )
        ]
        viewModel.maintenances = [UnifiedMaintenance(id: "m1", title: "Maintenance", description: nil, startDate: nil, endDate: nil)]
        viewModel.incidentRecords = [
            IncidentRecordSnapshot(
                monitorId: "api",
                monitorName: "API",
                serverConnectionId: connection.id,
                serverName: "Primary",
                transitionType: .wentDown
            )
        ]
        viewModel.lastIncidentDate = Date()

        await viewModel.fetchData()

        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertTrue(viewModel.heartbeats.isEmpty)
        XCTAssertTrue(viewModel.incidents.isEmpty)
        XCTAssertTrue(viewModel.maintenances.isEmpty)
        XCTAssertTrue(viewModel.incidentRecords.isEmpty)
        XCTAssertNil(viewModel.lastIncidentDate)
        XCTAssertEqual(viewModel.summaryText, String(localized: "No data"))
        XCTAssertEqual(viewModel.errorMessage, String(localized: "Server unreachable"))
    }

    @MainActor
    func testDashboardViewModelClearsIncidentMetadataWhenSwitchingConnection() {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let primary = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        let secondary = ServerConnection(
            name: "Secondary",
            baseURL: URL(string: "https://secondary.example.com")!,
            statusPageSlug: "secondary",
            isDefault: false
        )
        let viewModel = DashboardViewModel(connection: primary, settingsStore: store)
        viewModel.incidentRecords = [
            IncidentRecordSnapshot(
                monitorId: "api",
                monitorName: "API",
                serverConnectionId: primary.id,
                serverName: "Primary",
                transitionType: .wentDown
            )
        ]
        viewModel.lastIncidentDate = Date()

        viewModel.switchConnection(secondary)

        XCTAssertTrue(viewModel.incidentRecords.isEmpty)
        XCTAssertNil(viewModel.lastIncidentDate)
    }

    func testWidgetDataClearRemovesPersistedSnapshot() {
        let suiteName = "KumaNotifyTests.widget.clear.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        WidgetData(
            upCount: 1,
            totalCount: 1,
            downCount: 0,
            overallStatusRaw: "allUp",
            lastCheckTime: Date(),
            serverName: "Primary",
            hasActiveIncident: false
        ).write(to: defaults)

        WidgetData.clear(from: defaults)

        XCTAssertNil(WidgetData.read(from: defaults))
    }

    func testWidgetReloadSignatureStaysStableWithinFreshnessBucket() {
        let baseline = Date(timeIntervalSince1970: 1_000)
        let newerSameBucket = Date(timeIntervalSince1970: 1_000 + 60)

        let first = WidgetData(
            upCount: 1,
            totalCount: 1,
            downCount: 0,
            overallStatusRaw: "allUp",
            lastCheckTime: baseline,
            serverName: "Primary",
            hasActiveIncident: false
        )
        let second = WidgetData(
            upCount: 1,
            totalCount: 1,
            downCount: 0,
            overallStatusRaw: "allUp",
            lastCheckTime: newerSameBucket,
            serverName: "Primary",
            hasActiveIncident: false
        )

        XCTAssertEqual(first.reloadSignature, second.reloadSignature)
    }

    func testWidgetReloadSignatureChangesAcrossFreshnessBuckets() {
        let baseline = Date(timeIntervalSince1970: 1_000)
        let nextBucket = Date(timeIntervalSince1970: 1_000 + WidgetData.freshnessReloadInterval + 1)

        let first = WidgetData(
            upCount: 1,
            totalCount: 1,
            downCount: 0,
            overallStatusRaw: "allUp",
            lastCheckTime: baseline,
            serverName: "Primary",
            hasActiveIncident: false
        )
        let second = WidgetData(
            upCount: 1,
            totalCount: 1,
            downCount: 0,
            overallStatusRaw: "allUp",
            lastCheckTime: nextBucket,
            serverName: "Primary",
            hasActiveIncident: false
        )

        XCTAssertNotEqual(first.reloadSignature, second.reloadSignature)
    }

    func testUptimeKumaMapperParsesHeartbeatAndMaintenanceDates() {
        let mapper = UptimeKumaMapper()
        let heartbeatResult = mapper.mapHeartbeats(UKHeartbeatResponse(
            heartbeatList: [
                "1": [UKHeartbeat(status: 1, time: "2026-03-27 10:30:00", msg: "OK", ping: 42)]
            ],
            uptimeList: ["1_24": 0.99]
        ))
        let statusResult = mapper.mapStatusPage(
            UKStatusPageResponse(
                config: UKConfig(
                    slug: "primary",
                    title: "Primary",
                    description: nil,
                    icon: nil,
                    autoRefreshInterval: nil,
                    theme: nil,
                    published: true,
                    showTags: false,
                    showCertificateExpiry: false,
                    showOnlyLastHeartbeat: false,
                    footerText: nil,
                    showPoweredBy: true
                ),
                incidents: [],
                publicGroupList: [],
                maintenanceList: [
                    UKMaintenance(
                        id: 1,
                        title: "Window",
                        description: nil,
                        start: "2026-03-27 12:00:00",
                        end: "2026-03-27 13:00:00"
                    )
                ]
            ),
            heartbeatResult: heartbeatResult
        )

        XCTAssertEqual(heartbeatResult.heartbeats["1"]?.first?.ping, 42)
        XCTAssertNotNil(heartbeatResult.heartbeats["1"]?.first?.time)
        XCTAssertNotNil(statusResult.maintenances.first?.startDate)
        XCTAssertNotNil(statusResult.maintenances.first?.endDate)
    }

    @MainActor
    func testNotificationIdentifiersAreNamespacedByServerConnection() {
        let primaryID = UUID()
        let secondaryID = UUID()

        XCTAssertNotEqual(
            NotificationManager.downAlertIdentifier(serverConnectionId: primaryID, monitorId: "api"),
            NotificationManager.downAlertIdentifier(serverConnectionId: secondaryID, monitorId: "api")
        )
        XCTAssertNotEqual(
            NotificationManager.recoveryAlertIdentifier(serverConnectionId: primaryID, monitorId: "api"),
            NotificationManager.recoveryAlertIdentifier(serverConnectionId: secondaryID, monitorId: "api")
        )
        XCTAssertNotEqual(
            NotificationManager.certExpiryIdentifier(serverConnectionId: primaryID, monitorId: "api", daysRemaining: 7),
            NotificationManager.certExpiryIdentifier(serverConnectionId: secondaryID, monitorId: "api", daysRemaining: 7)
        )
    }

    @MainActor
    func testNotificationManagerMapsAuthorizationStatusesFromSystemValues() async {
        let authorizedManager = NotificationManager(
            authorizationStatusHandler: { .authorized }
        )
        let notDeterminedManager = NotificationManager(
            authorizationStatusHandler: { .notDetermined }
        )
        let deniedManager = NotificationManager(
            authorizationStatusHandler: { .denied }
        )

        let authorizedStatus = await authorizedManager.notificationAuthorizationStatus()
        let notDeterminedStatus = await notDeterminedManager.notificationAuthorizationStatus()
        let deniedStatus = await deniedManager.notificationAuthorizationStatus()

        XCTAssertEqual(authorizedStatus, .authorized)
        XCTAssertEqual(notDeterminedStatus, .notDetermined)
        XCTAssertEqual(deniedStatus, .denied)
    }

    @MainActor
    func testNotificationManagerOpenSystemSettingsFallsBackWhenDeepLinkFails() async {
        let recorder = URLRecorder()
        let manager = NotificationManager(
            openURLHandler: { url in
                recorder.record(url)
                return recorder.urls.count > 1
            }
        )

        let didOpenSettings = await manager.openSystemNotificationSettings()
        XCTAssertTrue(didOpenSettings)
        XCTAssertEqual(recorder.urls.count, 2)
        XCTAssertEqual(recorder.urls.first?.scheme, "x-apple.systempreferences")
        XCTAssertEqual(recorder.urls.last?.path, "/System/Applications/System Settings.app")
    }

    @MainActor
    func testNotificationManagerSchedulesDownAlertWithExpectedMetadata() async {
        let recorder = NotificationRequestRecorder()
        let connectionID = UUID()
        let manager = NotificationManager(
            scheduleRequestHandler: { request in
                recorder.record(request)
            }
        )

        await manager.sendDownAlert(
            serverConnectionId: connectionID,
            monitorId: "api",
            monitorName: "API",
            serverName: "Primary",
            soundOption: .silent
        )

        let request = try? XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request?.identifier, NotificationManager.downAlertIdentifier(serverConnectionId: connectionID, monitorId: "api"))
        XCTAssertEqual(request?.content.title, String(localized: "Monitor Down"))
        XCTAssertEqual(request?.content.subtitle, "API")
        XCTAssertEqual(request?.content.categoryIdentifier, "MONITOR_DOWN")
        XCTAssertEqual(request?.content.interruptionLevel, .timeSensitive)
        XCTAssertNil(request?.content.sound)
    }

    @MainActor
    func testNotificationManagerUsesCustomEggCrackSoundForDownAlert() async throws {
        let recorder = NotificationRequestRecorder()
        let connectionID = UUID()
        let manager = NotificationManager(
            scheduleRequestHandler: { request in
                recorder.record(request)
            }
        )

        await manager.sendDownAlert(
            serverConnectionId: connectionID,
            monitorId: "web",
            monitorName: "Web",
            serverName: "Primary",
            soundOption: .system
        )

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertNotNil(request.content.sound)
    }

    @MainActor
    func testNetworkMonitorApplyPathUpdateTracksConnectivityAndInterface() {
        let monitor = NetworkMonitor()

        monitor.applyPathUpdate(status: .unsatisfied, isExpensive: true, connectionType: .cellular)
        XCTAssertFalse(monitor.isConnected)
        XCTAssertTrue(monitor.isExpensive)
        XCTAssertEqual(monitor.connectionType, .cellular)

        monitor.applyPathUpdate(status: .satisfied, isExpensive: false, connectionType: .wifi)
        XCTAssertTrue(monitor.isConnected)
        XCTAssertFalse(monitor.isExpensive)
        XCTAssertEqual(monitor.connectionType, .wifi)
    }

    func testPowerMonitorNormalizedPowerStateHandlesBatteryAndFallbackCases() {
        let acState = PowerMonitor.normalizedPowerState(from: nil)
        XCTAssertFalse(acState.isOnBattery)
        XCTAssertEqual(acState.batteryLevel, 1.0)

        let batteryState = PowerMonitor.normalizedPowerState(from: [
            kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue,
            kIOPSCurrentCapacityKey as String: 25,
            kIOPSMaxCapacityKey as String: 100
        ])
        XCTAssertTrue(batteryState.isOnBattery)
        XCTAssertEqual(batteryState.batteryLevel, 0.25)

        let unknownCapacityState = PowerMonitor.normalizedPowerState(from: [
            kIOPSPowerSourceStateKey as String: kIOPSACPowerValue
        ])
        XCTAssertFalse(unknownCapacityState.isOnBattery)
        XCTAssertEqual(unknownCapacityState.batteryLevel, 1.0)
    }

    @MainActor
    func testDashboardViewModelIgnoresStaleResultsForPreviousConnection() {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let primary = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        let secondary = ServerConnection(
            name: "Secondary",
            baseURL: URL(string: "https://secondary.example.com")!,
            statusPageSlug: "secondary",
            isDefault: false
        )
        let viewModel = DashboardViewModel(connection: primary, settingsStore: store)
        let staleResult = StatusPageResult(
            title: "Primary",
            groups: [
                UnifiedGroup(
                    id: "g1",
                    name: "Core",
                    weight: 0,
                    monitors: [
                        UnifiedMonitor(
                            id: "api",
                            name: "API",
                            type: "http",
                            currentStatus: .down,
                            latestPing: 120,
                            uptime24h: 1,
                            uptime7d: 1,
                            uptime30d: 1,
                            certExpiryDays: nil,
                            validCert: nil,
                            url: nil,
                            lastStatusChange: nil
                        )
                    ]
                )
            ],
            heartbeats: [:],
            incidents: [],
            maintenances: [],
            showCertExpiry: false
        )

        viewModel.switchConnection(secondary)
        viewModel.applyStatusPageResult(staleResult, for: primary.id)

        XCTAssertEqual(viewModel.connection.id, secondary.id)
        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertEqual(viewModel.summaryText, String(localized: "No data"))
    }

    func testHTTPClientPrioritizesPrivateRelayErrorsOverGenericConnectivity() {
        let failingURL = URL(string: "https://mask.icloud.com")!
        let error = URLError(
            .cannotConnectToHost,
            userInfo: [NSURLErrorFailingURLErrorKey: failingURL]
        )

        guard case .privateRelayBlocked? = HTTPClient.apiError(for: error) else {
            return XCTFail("Expected Private Relay mapping to win over generic connectivity errors")
        }
    }

    @MainActor
    func testDashboardViewModelCachesDerivedGroupsWhenFiltersChange() {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        let viewModel = DashboardViewModel(connection: connection, settingsStore: store)

        let api = UnifiedMonitor(
            id: "api",
            name: "API",
            type: "http",
            currentStatus: .up,
            latestPing: 120,
            uptime24h: 1,
            uptime7d: 1,
            uptime30d: 1,
            certExpiryDays: nil,
            validCert: nil,
            url: nil,
            lastStatusChange: nil
        )
        let worker = UnifiedMonitor(
            id: "worker",
            name: "Worker",
            type: "http",
            currentStatus: .down,
            latestPing: 80,
            uptime24h: 0.95,
            uptime7d: 0.95,
            uptime30d: 0.95,
            certExpiryDays: nil,
            validCert: nil,
            url: nil,
            lastStatusChange: nil
        )

        viewModel.groups = [
            UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: [api, worker])
        ]

        XCTAssertEqual(viewModel.serverLatency, 100)
        XCTAssertEqual(viewModel.filteredGroups.first?.monitors.count, 2)

        viewModel.statusFilter = .down
        XCTAssertEqual(viewModel.filteredGroups.first?.monitors.map(\.id), ["worker"])

        let pref = MonitorPreferenceSnapshot(
            monitorId: "worker",
            serverConnectionId: connection.id,
            isPinned: false,
            isHidden: true
        )
        viewModel.monitorPreferences = [pref.compositeKey: pref]
        XCTAssertTrue(viewModel.filteredGroups.isEmpty)
    }

    @MainActor
    func testDashboardViewModelUsesNeutralSummaryText() {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        let viewModel = DashboardViewModel(connection: connection, settingsStore: store)

        viewModel.groups = [
            UnifiedGroup(
                id: "g1",
                name: "Core",
                weight: 0,
                monitors: [
                    UnifiedMonitor(
                        id: "api",
                        name: "API",
                        type: "http",
                        currentStatus: .down,
                        latestPing: 120,
                        uptime24h: 1,
                        uptime7d: 1,
                        uptime30d: 1,
                        certExpiryDays: nil,
                        validCert: nil,
                        url: nil,
                        lastStatusChange: nil
                    )
                ]
            )
        ]

        XCTAssertTrue(viewModel.summaryText.contains(WidgetData.monitorSummaryLine(upCount: 0, totalCount: 1)))
        XCTAssertFalse(viewModel.summaryText.contains("OK"))
    }

    @MainActor
    func testMenuBarViewModelOnlyReloadsWidgetsWhenVisibleSnapshotChanges() async {
        let (suiteName, store) = makeSettingsStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://primary.example.com")!,
            statusPageSlug: "primary"
        )
        store.addConnection(connection)

        let networkMonitor = NetworkMonitor()
        networkMonitor.isConnected = true

        let monitor = UnifiedMonitor(
            id: "api",
            name: "API",
            type: "http",
            currentStatus: .up,
            latestPing: 90,
            uptime24h: 1,
            uptime7d: 1,
            uptime30d: 1,
            certExpiryDays: nil,
            validCert: nil,
            url: nil,
            lastStatusChange: nil
        )
        let result = StatusPageResult(
            title: "Primary",
            groups: [UnifiedGroup(id: "g1", name: "Core", weight: 0, monitors: [monitor])],
            heartbeats: [:],
            incidents: [],
            maintenances: [],
            showCertExpiry: false
        )
        let service = ScriptedMonitoringService { _ in result }

        var reloadCount = 0
        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: PollingEngine(),
            serviceFactory: { _ in service },
            networkMonitor: networkMonitor,
            reloadWidgets: { reloadCount += 1 },
            shouldStartMonitors: false
        )

        await viewModel.refresh()
        await viewModel.refresh()

        XCTAssertEqual(reloadCount, 1)
    }

    func testUptimeKumaServiceFetchStatusPageRequestsHeartbeatsBeforeStatusPageAndMapsCombinedResult() async throws {
        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://status.example.com")!,
            statusPageSlug: "primary"
        )
        let heartbeatResponse = UKHeartbeatResponse(
            heartbeatList: [
                "1": [
                    UKHeartbeat(
                        status: MonitorStatus.up.rawValue,
                        time: "2026-03-27 10:00:00",
                        msg: "ok",
                        ping: 123
                    )
                ]
            ],
            uptimeList: [
                "1_24": 99.5
            ]
        )
        let statusPageResponse = UKStatusPageResponse(
            config: UKConfig(
                slug: "primary",
                title: "Primary Status",
                description: nil,
                icon: nil,
                autoRefreshInterval: 60,
                theme: nil,
                published: true,
                showTags: false,
                showCertificateExpiry: true,
                showOnlyLastHeartbeat: false,
                footerText: nil,
                showPoweredBy: false
            ),
            incidents: [],
            publicGroupList: [
                UKPublicGroup(
                    id: 10,
                    name: "Core",
                    weight: 0,
                    monitorList: [
                        UKMonitor(
                            id: 1,
                            name: "API",
                            sendUrl: 0,
                            type: "http",
                            certExpiryDaysRemaining: 14,
                            validCert: true
                        )
                    ]
                )
            ],
            maintenanceList: []
        )
        let httpClient = ScriptedHTTPClient(
            statusPageResponse: statusPageResponse,
            heartbeatResponse: heartbeatResponse
        )
        let service = UptimeKumaService(httpClient: httpClient)

        let result = try await service.fetchStatusPage(connection: connection)
        let requestedURLs = await httpClient.requestedURLSnapshot()

        XCTAssertEqual(requestedURLs, [connection.heartbeatURL, connection.statusPageURL])
        XCTAssertEqual(result.title, "Primary Status")
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(result.groups[0].monitors.count, 1)
        XCTAssertEqual(result.groups[0].monitors[0].currentStatus, .up)
        XCTAssertEqual(result.groups[0].monitors[0].latestPing, 123)
        XCTAssertEqual(result.groups[0].monitors[0].uptime24h, 99.5)
        XCTAssertEqual(result.showCertExpiry, true)
        XCTAssertEqual(result.heartbeats["1"]?.count, 1)
    }

    func testUptimeKumaServiceValidateConnectionUsesSameEndpointsAsLiveStatusFetch() async throws {
        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://status.example.com")!,
            statusPageSlug: "primary"
        )
        let httpClient = ScriptedHTTPClient(
            statusPageResponse: UKStatusPageResponse(
                config: UKConfig(
                    slug: "primary",
                    title: "Primary Status",
                    description: nil,
                    icon: nil,
                    autoRefreshInterval: nil,
                    theme: nil,
                    published: true,
                    showTags: false,
                    showCertificateExpiry: false,
                    showOnlyLastHeartbeat: false,
                    footerText: nil,
                    showPoweredBy: false
                ),
                incidents: [],
                publicGroupList: [],
                maintenanceList: []
            ),
            heartbeatResponse: UKHeartbeatResponse(heartbeatList: [:], uptimeList: [:])
        )
        let service = UptimeKumaService(httpClient: httpClient)

        let isValid = try await service.validateConnection(connection)
        let requestedURLs = await httpClient.requestedURLSnapshot()

        XCTAssertTrue(isValid)
        XCTAssertEqual(requestedURLs, [connection.heartbeatURL, connection.statusPageURL])
    }

    func testUptimeKumaServiceFetchHeartbeatsOnlyHitsHeartbeatEndpoint() async throws {
        let connection = ServerConnection(
            name: "Primary",
            baseURL: URL(string: "https://status.example.com")!,
            statusPageSlug: "primary"
        )
        let httpClient = ScriptedHTTPClient(
            statusPageResponse: UKStatusPageResponse(
                config: UKConfig(
                    slug: "primary",
                    title: "Primary Status",
                    description: nil,
                    icon: nil,
                    autoRefreshInterval: nil,
                    theme: nil,
                    published: true,
                    showTags: false,
                    showCertificateExpiry: false,
                    showOnlyLastHeartbeat: false,
                    footerText: nil,
                    showPoweredBy: false
                ),
                incidents: [],
                publicGroupList: [],
                maintenanceList: []
            ),
            heartbeatResponse: UKHeartbeatResponse(
                heartbeatList: [
                    "42": [
                        UKHeartbeat(
                            status: MonitorStatus.down.rawValue,
                            time: "2026-03-27 11:00:00",
                            msg: "down",
                            ping: nil
                        )
                    ]
                ],
                uptimeList: ["42_24": 0.0]
            )
        )
        let service = UptimeKumaService(httpClient: httpClient)

        let result = try await service.fetchHeartbeats(connection: connection)
        let requestedURLs = await httpClient.requestedURLSnapshot()

        XCTAssertEqual(requestedURLs, [connection.heartbeatURL])
        XCTAssertEqual(result.heartbeats["42"]?.first?.status, .down)
        XCTAssertEqual(result.uptimes["42_24"], 0.0)
    }

    func testMonitoringServiceFactoryCreatesUptimeKumaService() {
        let service = MonitoringServiceFactory.create(for: .uptimeKuma)
        XCTAssertTrue(service is UptimeKumaService)
    }

    func testKumaNotifyAppLaunchBehaviorRestoresMonitoringWhenConnectionExists() {
        let behavior = KumaNotifyApp.launchBehavior(
            hasServerConnection: true,
            hasCompletedOnboarding: false
        )

        XCTAssertEqual(behavior, .restoreMonitoring)
    }

    func testKumaNotifyAppLaunchBehaviorShowsOnboardingOnlyWhenNoConnectionAndIncompleteSetup() {
        XCTAssertEqual(
            KumaNotifyApp.launchBehavior(
                hasServerConnection: false,
                hasCompletedOnboarding: false
            ),
            .emptyState(showOnboarding: true)
        )
        XCTAssertEqual(
            KumaNotifyApp.launchBehavior(
                hasServerConnection: false,
                hasCompletedOnboarding: true
            ),
            .emptyState(showOnboarding: false)
        )
    }

    func testKumaNotifyAppShouldPresentOnboardingRespectsUITestOverride() {
        XCTAssertTrue(KumaNotifyApp.shouldPresentOnboarding(
            showOnboarding: true,
            uiTestShowsOnboarding: false
        ))
        XCTAssertFalse(KumaNotifyApp.shouldPresentOnboarding(
            showOnboarding: false,
            uiTestShowsOnboarding: false
        ))
        XCTAssertFalse(KumaNotifyApp.shouldPresentOnboarding(
            showOnboarding: true,
            uiTestShowsOnboarding: true
        ))
    }

    func testKumaNotifyAppShouldSeedUITestServerConnectionOnlyWhenStoreIsEmpty() {
        XCTAssertTrue(KumaNotifyApp.shouldSeedUITestServerConnection(true, existingConnectionCount: 0))
        XCTAssertFalse(KumaNotifyApp.shouldSeedUITestServerConnection(true, existingConnectionCount: 1))
        XCTAssertFalse(KumaNotifyApp.shouldSeedUITestServerConnection(false, existingConnectionCount: 0))
    }

    func testKumaNotifyAppClearSharedWidgetDataRemovesSnapshotAndReloads() {
        let suiteName = "KumaNotifyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let snapshot = WidgetData(
            upCount: 3,
            totalCount: 3,
            downCount: 0,
            overallStatusRaw: OverallStatus.allUp.widgetKey,
            lastCheckTime: Date(),
            serverName: "Primary",
            hasActiveIncident: false
        )
        snapshot.write(to: defaults)

        var reloadCount = 0
        KumaNotifyApp.clearSharedWidgetData(
            defaults: defaults,
            reloadWidgets: { reloadCount += 1 }
        )

        XCTAssertNil(WidgetData.read(from: defaults))
        XCTAssertEqual(reloadCount, 1)
    }

    func testWidgetTimelineSupportReadsPersistedSnapshotFromDefaults() {
        let suiteName = "KumaNotifyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let referenceDate = Date(timeIntervalSince1970: 1_711_535_200)
        WidgetData(
            upCount: 4,
            totalCount: 5,
            downCount: 1,
            overallStatusRaw: "someDown",
            lastCheckTime: referenceDate,
            serverName: "Primary",
            hasActiveIncident: true
        ).write(to: defaults)

        let snapshot = WidgetTimelineSupport.readSnapshot(from: defaults)

        XCTAssertEqual(snapshot?.upCount, 4)
        XCTAssertEqual(snapshot?.downCount, 1)
        XCTAssertEqual(snapshot?.serverName, "Primary")
        XCTAssertEqual(snapshot?.overallStatusRaw, "someDown")
    }

    func testWidgetTimelineSupportReturnsNilSnapshotWhenNoDataExists() {
        let suiteName = "KumaNotifyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        XCTAssertNil(WidgetTimelineSupport.readSnapshot(from: defaults))
    }

    func testWidgetTimelineSupportRefreshesAfterFifteenMinutes() {
        let now = Date(timeIntervalSince1970: 1_711_535_200)
        let nextUpdate = WidgetTimelineSupport.nextRefreshDate(from: now)
        XCTAssertEqual(nextUpdate.timeIntervalSince(now), 900, accuracy: 1)
    }

    func testWidgetDataPresentationMapsVisibleStateBranches() {
        let allUp = WidgetData(
            upCount: 5,
            totalCount: 5,
            downCount: 0,
            overallStatusRaw: "allUp",
            lastCheckTime: nil,
            serverName: nil,
            hasActiveIncident: false
        )
        let degraded = WidgetData(
            upCount: 5,
            totalCount: 5,
            downCount: 0,
            overallStatusRaw: "degraded",
            lastCheckTime: nil,
            serverName: nil,
            hasActiveIncident: false
        )
        let someDown = WidgetData(
            upCount: 3,
            totalCount: 5,
            downCount: 2,
            overallStatusRaw: "someDown",
            lastCheckTime: nil,
            serverName: nil,
            hasActiveIncident: true
        )
        let offline = WidgetData(
            upCount: 0,
            totalCount: 0,
            downCount: 0,
            overallStatusRaw: "unreachable",
            lastCheckTime: nil,
            serverName: nil,
            hasActiveIncident: true
        )

        XCTAssertEqual(WidgetDataPresentation.statusColorKey(for: allUp.overallStatusRaw), "green")
        XCTAssertEqual(WidgetDataPresentation.statusColorKey(for: degraded.overallStatusRaw), "yellow")
        XCTAssertEqual(WidgetDataPresentation.statusColorKey(for: someDown.overallStatusRaw), "red")
        XCTAssertEqual(WidgetDataPresentation.statusColorKey(for: offline.overallStatusRaw), "gray")

        XCTAssertEqual(WidgetDataPresentation.statusLabel(for: allUp), String(localized: "All OK"))
        XCTAssertEqual(WidgetDataPresentation.statusLabel(for: degraded), String(localized: "Degraded"))
        XCTAssertEqual(
            WidgetDataPresentation.statusLabel(for: someDown),
            String.localizedStringWithFormat(String(localized: "%lld down"), Int64(2))
        )
        XCTAssertEqual(WidgetDataPresentation.statusLabel(for: offline), String(localized: "Offline"))

        XCTAssertTrue(WidgetDataPresentation.shouldShowSummary(for: allUp))
        XCTAssertFalse(WidgetDataPresentation.shouldShowSummary(for: offline))
    }

    func testProjectYAMLBundlesLocalizableCatalogIntoWidgetTarget() throws {
        let project = try projectYAMLContents()
        XCTAssertTrue(project.contains("KumaNotifyWidget:"))
        XCTAssertTrue(project.contains("- path: KumaNotify/Resources/Localizable.xcstrings"))
    }

    func testSettingsViewLogicGatesMultipleServersForFreeTier() {
        XCTAssertTrue(SettingsViewLogic.canAddServer(isPro: false, serverCount: 0))
        XCTAssertFalse(SettingsViewLogic.canAddServer(isPro: false, serverCount: 1))
        XCTAssertTrue(SettingsViewLogic.canAddServer(isPro: true, serverCount: 5))

        XCTAssertFalse(SettingsViewLogic.shouldShowMultiServerUpsell(isPro: false, serverCount: 0))
        XCTAssertTrue(SettingsViewLogic.shouldShowMultiServerUpsell(isPro: false, serverCount: 1))
        XCTAssertFalse(SettingsViewLogic.shouldShowMultiServerUpsell(isPro: true, serverCount: 3))
    }

    func testSettingsViewLogicMapsNotificationToggleFlowFromAuthorizationStatus() {
        XCTAssertEqual(
            SettingsViewLogic.notificationToggleDecision(
                enabling: false,
                authorizationStatus: .authorized
            ),
            .disable
        )
        XCTAssertEqual(
            SettingsViewLogic.notificationToggleDecision(
                enabling: true,
                authorizationStatus: .authorized
            ),
            .enableImmediately
        )
        XCTAssertEqual(
            SettingsViewLogic.notificationToggleDecision(
                enabling: true,
                authorizationStatus: .notDetermined
            ),
            .requestSystemPermission
        )
        XCTAssertEqual(
            SettingsViewLogic.notificationToggleDecision(
                enabling: true,
                authorizationStatus: .denied
            ),
            .showSystemSettingsHelp
        )

        XCTAssertTrue(SettingsViewLogic.shouldShowDeniedNotificationBanner(authorizationStatus: .denied))
        XCTAssertFalse(SettingsViewLogic.shouldShowDeniedNotificationBanner(authorizationStatus: .authorized))

        XCTAssertEqual(
            SettingsViewLogic.testNotificationDecision(authorizationStatus: .authorized),
            .sendTest
        )
        XCTAssertEqual(
            SettingsViewLogic.testNotificationDecision(authorizationStatus: .notDetermined),
            .requestSystemPermission
        )
        XCTAssertEqual(
            SettingsViewLogic.testNotificationDecision(authorizationStatus: .denied),
            .showSystemSettingsHelp
        )
    }

    func testOnboardingViewLogicBuildsNormalizedDraftConnection() {
        let connection = OnboardingViewLogic.draftConnection(
            serverURL: " https://status.example.com ",
            slug: " /primary/ ",
            serverName: "   "
        )

        XCTAssertEqual(connection?.baseURL.absoluteString, "https://status.example.com")
        XCTAssertEqual(connection?.statusPageSlug, "primary")
        XCTAssertEqual(connection?.name, String(localized: "My Kuma Server"))
        XCTAssertTrue(OnboardingViewLogic.canContinue(
            serverURL: "https://status.example.com",
            slug: "primary"
        ))
        XCTAssertFalse(OnboardingViewLogic.canContinue(
            serverURL: "notaurl",
            slug: "primary"
        ))
        XCTAssertNil(OnboardingViewLogic.draftConnection(
            serverURL: "https://status.example.com",
            slug: "nested/path",
            serverName: "Primary"
        ))
    }

    func testPaywallViewLogicMapsPurchasePresentationBranches() {
        XCTAssertEqual(
            PaywallViewLogic.purchasePresentation(
                isPurchased: true,
                productLoadErrorMessage: nil,
                hasProProduct: true,
                purchaseState: .idle
            ),
            .purchased
        )
        XCTAssertEqual(
            PaywallViewLogic.purchasePresentation(
                isPurchased: false,
                productLoadErrorMessage: "Store offline",
                hasProProduct: false,
                purchaseState: .idle
            ),
            .productLoadError("Store offline")
        )
        XCTAssertEqual(
            PaywallViewLogic.purchasePresentation(
                isPurchased: false,
                productLoadErrorMessage: nil,
                hasProProduct: true,
                purchaseState: .purchasing
            ),
            .purchasing
        )
        XCTAssertEqual(
            PaywallViewLogic.purchasePresentation(
                isPurchased: false,
                productLoadErrorMessage: nil,
                hasProProduct: true,
                purchaseState: .failed("Purchase failed")
            ),
            .purchaseFailure("Purchase failed")
        )
        XCTAssertEqual(
            PaywallViewLogic.purchasePresentation(
                isPurchased: false,
                productLoadErrorMessage: nil,
                hasProProduct: false,
                purchaseState: .idle
            ),
            .upgradeAvailable(isEnabled: false)
        )
    }

    func testDashboardViewLogicMapsSurfaceAndSectionVisibility() {
        XCTAssertEqual(
            DashboardViewLogic.currentSurface(showPaywall: true, showIncidentHistory: true),
            .paywall
        )
        XCTAssertEqual(
            DashboardViewLogic.currentSurface(showPaywall: false, showIncidentHistory: true),
            .incidentHistory
        )
        XCTAssertEqual(
            DashboardViewLogic.currentSurface(showPaywall: false, showIncidentHistory: false),
            .mainContent
        )

        XCTAssertFalse(DashboardViewLogic.shouldShowServerSelector(connectionCount: 1))
        XCTAssertTrue(DashboardViewLogic.shouldShowServerSelector(connectionCount: 2))
        XCTAssertFalse(DashboardViewLogic.shouldShowFilterBar(isPro: false))
        XCTAssertTrue(DashboardViewLogic.shouldShowFilterBar(isPro: true))
        XCTAssertFalse(DashboardViewLogic.shouldShowMaintenanceBanner(isPro: false, maintenanceCount: 2))
        XCTAssertFalse(DashboardViewLogic.shouldShowMaintenanceBanner(isPro: true, maintenanceCount: 0))
        XCTAssertTrue(DashboardViewLogic.shouldShowMaintenanceBanner(isPro: true, maintenanceCount: 1))
    }

    func testServerFormViewLogicBuildsDraftForEditAndCreateFlows() {
        let existing = ServerConnection(
            id: UUID(),
            name: "Existing",
            baseURL: URL(string: "https://old.example.com")!,
            statusPageSlug: "old",
            isDefault: true
        )

        let edited = ServerFormViewLogic.draftConnection(
            existingConnection: existing,
            serverURL: " https://new.example.com ",
            slug: " /prod/ ",
            serverName: "   "
        )
        let created = ServerFormViewLogic.draftConnection(
            existingConnection: nil,
            serverURL: "https://new.example.com",
            slug: "prod",
            serverName: "Primary"
        )

        XCTAssertTrue(ServerFormViewLogic.canSubmit(
            serverURL: "https://new.example.com",
            slug: "prod"
        ))
        XCTAssertFalse(ServerFormViewLogic.canSubmit(
            serverURL: "notaurl",
            slug: "prod"
        ))

        XCTAssertEqual(edited?.id, existing.id)
        XCTAssertEqual(edited?.isDefault, true)
        XCTAssertEqual(edited?.baseURL.absoluteString, "https://new.example.com")
        XCTAssertEqual(edited?.statusPageSlug, "prod")
        XCTAssertEqual(edited?.name, String(localized: "My Kuma Server"))

        XCTAssertEqual(created?.name, "Primary")
        XCTAssertEqual(created?.isDefault, false)
        XCTAssertNil(ServerFormViewLogic.draftConnection(
            existingConnection: nil,
            serverURL: "https://new.example.com",
            slug: "nested/path",
            serverName: "Primary"
        ))
    }

    func testMenuBarLabelLogicBuildsReachableAndUnreachableAccessibilityDescriptions() {
        XCTAssertEqual(
            MenuBarLabelLogic.accessibilityDescription(
                overallStatus: .unreachable,
                upCount: 0,
                totalCount: 0
            ),
            OverallStatus.unreachable.label
        )

        let reachableDescription = MenuBarLabelLogic.accessibilityDescription(
            overallStatus: .someDown(count: 1, total: 3),
            upCount: 2,
            totalCount: 3
        )
        XCTAssertTrue(reachableDescription.contains("2"))
        XCTAssertTrue(reachableDescription.contains("3"))
        XCTAssertTrue(reachableDescription.contains(OverallStatus.someDown(count: 1, total: 3).label))
    }

    func testSummaryAndMaintenanceViewLogicFormatsLeafPresentationText() {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let incidentText = SummaryHeaderViewLogic.lastIncidentText(referenceDate)
        let endTimeText = MaintenanceBannerViewLogic.endTimeText(referenceDate)

        XCTAssertEqual(SummaryHeaderViewLogic.latencyValueText(128), "128")
        XCTAssertFalse(incidentText.isEmpty)
        XCTAssertFalse(incidentText.contains("%@"))
        XCTAssertFalse(MaintenanceBannerViewLogic.shouldShowDescription(nil))
        XCTAssertFalse(MaintenanceBannerViewLogic.shouldShowDescription(""))
        XCTAssertTrue(MaintenanceBannerViewLogic.shouldShowDescription("Scheduled"))
        XCTAssertTrue(endTimeText.hasPrefix("→"))
    }

    func testCertExpiryBadgeLogicMapsSeverityAndAccessibilityText() {
        XCTAssertEqual(CertExpiryBadgeLogic.severity(for: 3), .urgent)
        XCTAssertEqual(CertExpiryBadgeLogic.severity(for: 10), .warning)
        XCTAssertEqual(CertExpiryBadgeLogic.severity(for: 20), .notice)
        XCTAssertEqual(CertExpiryBadgeLogic.compactText(daysRemaining: 12), "12d")
        XCTAssertTrue(CertExpiryBadgeLogic.accessibilityLabel(daysRemaining: 12).contains("12"))
    }

    func testUptimeBadgeLogicMapsDisplayTextColorTierAndAccessibilityValue() {
        let displayText = UptimeBadgeLogic.displayText(for: 0.999)
        XCTAssertTrue(displayText.contains("99"))
        XCTAssertTrue(displayText.contains("%"))
        XCTAssertEqual(UptimeBadgeLogic.colorTier(for: 0.999), .healthy)
        XCTAssertEqual(UptimeBadgeLogic.colorTier(for: 0.995), .healthySoft)
        XCTAssertEqual(UptimeBadgeLogic.colorTier(for: 0.97), .warning)
        XCTAssertEqual(UptimeBadgeLogic.colorTier(for: 0.8), .critical)

        let accessibilityValue = UptimeBadgeLogic.accessibilityValue(
            percentage: 0.995,
            period: .twentyFourHours
        )
        XCTAssertTrue(accessibilityValue.contains("%"))
        XCTAssertTrue(accessibilityValue.contains(UptimePeriod.twentyFourHours.rawValue))
    }
}
