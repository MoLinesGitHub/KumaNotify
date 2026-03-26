import XCTest
@testable import KumaNotify

final class KumaNotifyTests: XCTestCase {
    @MainActor
    private func makeSettingsStore() -> (suiteName: String, store: SettingsStore) {
        let suiteName = "KumaNotifyTests.\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        return (suiteName, SettingsStore(suiteName: suiteName))
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
    func testPersistenceManagerDeduplicatesRepeatedIncidentsWithinWindow() throws {
        let manager = try PersistenceManager(isStoredInMemoryOnly: true)
        let timestamp = Date()
        let serverConnectionId = UUID()

        manager.recordIncident(IncidentRecord(
            monitorId: "api",
            monitorName: "API",
            serverConnectionId: serverConnectionId,
            serverName: "Prod",
            transitionType: .wentDown,
            timestamp: timestamp
        ))
        manager.recordIncident(IncidentRecord(
            monitorId: "api",
            monitorName: "API",
            serverConnectionId: serverConnectionId,
            serverName: "Prod",
            transitionType: .wentDown,
            timestamp: timestamp.addingTimeInterval(30)
        ))

        XCTAssertEqual(manager.fetchRecentIncidents(limit: 10).count, 1)
    }

    @MainActor
    func testPersistenceManagerPurgesOnlyExpiredIncidents() throws {
        let manager = try PersistenceManager(isStoredInMemoryOnly: true)

        manager.recordIncident(IncidentRecord(
            monitorId: "old",
            monitorName: "Old Monitor",
            serverConnectionId: UUID(),
            serverName: "Prod",
            transitionType: .wentDown,
            timestamp: Calendar.current.date(byAdding: .day, value: -91, to: Date())!
        ))
        manager.recordIncident(IncidentRecord(
            monitorId: "recent",
            monitorName: "Recent Monitor",
            serverConnectionId: UUID(),
            serverName: "Prod",
            transitionType: .recovered,
            timestamp: Date(),
            downDuration: 42
        ))

        manager.purgeOldIncidents(olderThan: 90)

        let incidents = manager.fetchRecentIncidents(limit: 10)
        XCTAssertEqual(incidents.count, 1)
        XCTAssertEqual(incidents.first?.monitorId, "recent")
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
        let viewModel = MenuBarViewModel(
            settingsStore: store,
            pollingEngine: PollingEngine(),
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
        XCTAssertEqual(reloadCount, 1)
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
        XCTAssertTrue(statusSummary.value.contains("3/5"))
        XCTAssertTrue(statusSummary.value.contains("2"))

        let monitorCounts = IntentStatusFormatter.monitorCountSummary(for: data)
        XCTAssertTrue(monitorCounts.contains("3"))
        XCTAssertTrue(monitorCounts.contains("2"))
        XCTAssertTrue(monitorCounts.contains("5"))
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

        let pref = MonitorPreference(
            monitorId: "worker",
            serverConnectionId: connection.id,
            isPinned: false,
            isHidden: true
        )
        viewModel.monitorPreferences = [pref.compositeKey: pref]
        XCTAssertTrue(viewModel.filteredGroups.isEmpty)
    }
}
