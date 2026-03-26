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
    func testPersistenceManagerDeduplicatesRepeatedIncidentsWithinWindow() throws {
        let manager = try PersistenceManager(isStoredInMemoryOnly: true)
        let timestamp = Date()

        manager.recordIncident(IncidentRecord(
            monitorId: "api",
            monitorName: "API",
            serverConnectionId: UUID(),
            serverName: "Prod",
            transitionType: .wentDown,
            timestamp: timestamp
        ))
        manager.recordIncident(IncidentRecord(
            monitorId: "api",
            monitorName: "API",
            serverConnectionId: UUID(),
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
}
