import SwiftUI
import AppKit

@Observable
@MainActor
final class DashboardViewModel {
    private let settingsStore: SettingsStore
    private let persistence: PersistenceManager?
    private let serviceFactory: (MonitoringProvider) -> any MonitoringServiceProtocol
    private(set) var connection: ServerConnection {
        didSet { recomputeFilteredGroups() }
    }

    var groups: [UnifiedGroup] = [] {
        didSet { recomputeDerivedState() }
    }
    var heartbeats: [String: [UnifiedHeartbeat]] = [:]
    var incidents: [UKIncident] = []
    var maintenances: [UnifiedMaintenance] = []
    var statusFilter: MonitorStatus? {
        didSet { recomputeFilteredGroups() }
    }
    var searchText = "" {
        didSet { recomputeFilteredGroups() }
    }
    var uptimePeriod: UptimePeriod = .twentyFourHours
    var isLoading = false
    var errorMessage: String?

    // Phase 3: Persistence state
    var monitorPreferences: [String: MonitorPreferenceSnapshot] = [:] {
        didSet { recomputeFilteredGroups() }
    }
    var showHiddenMonitors = false {
        didSet { recomputeFilteredGroups() }
    }
    var incidentRecords: [IncidentRecordSnapshot] = []
    var showIncidentHistory = false
    var lastIncidentDate: Date?
    private(set) var summaryText = ""
    private(set) var serverLatency: Int?
    private(set) var filteredGroups: [UnifiedGroup] = []
    private(set) var overallStatus: OverallStatus = .unreachable

    private var lastFetchTime: Date? {
        didSet { recomputeSummary() }
    }

    init(
        connection: ServerConnection,
        settingsStore: SettingsStore,
        persistence: PersistenceManager? = nil,
        serviceFactory: @escaping (MonitoringProvider) -> any MonitoringServiceProtocol = MonitoringServiceFactory.create
    ) {
        self.connection = connection
        self.settingsStore = settingsStore
        self.persistence = persistence
        self.serviceFactory = serviceFactory
        recomputeDerivedState()
    }

    func fetchData() async {
        let service = serviceFactory(connection.provider)
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await service.fetchStatusPage(connection: connection)
            applyStatusPageResult(result)
        } catch {
            applyErrorState(error.localizedDescription)
        }
    }

    func switchConnection(_ newConnection: ServerConnection) {
        connection = newConnection
        groups = []
        heartbeats = [:]
        incidents = []
        maintenances = []
        incidentRecords = []
        lastIncidentDate = nil
        errorMessage = nil
    }

    func refresh() async {
        await fetchData()
    }

    func applyStatusPageResult(_ result: StatusPageResult) {
        groups = result.groups
        heartbeats = result.heartbeats
        incidents = result.incidents
        maintenances = result.maintenances
        lastFetchTime = Date()
        errorMessage = nil
        Task {
            await loadPreferences()
            await loadLastIncidentDate()
        }
    }

    func applyStatusPageResult(_ result: StatusPageResult, for connectionId: UUID) {
        guard connection.id == connectionId else { return }
        applyStatusPageResult(result)
    }

    func applyErrorState(_ message: String) {
        groups = []
        heartbeats = [:]
        incidents = []
        maintenances = []
        incidentRecords = []
        lastIncidentDate = nil
        lastFetchTime = nil
        errorMessage = message
    }

    func applyErrorState(_ message: String, for connectionId: UUID) {
        guard connection.id == connectionId else { return }
        applyErrorState(message)
    }

    // MARK: - Persistence

    func loadPreferences() async {
        if let persistence {
            monitorPreferences = await persistence.fetchAllPreferences()
        }
    }

    func loadIncidentHistory() async {
        if let persistence {
            incidentRecords = await persistence.fetchRecentIncidents(serverConnectionId: connection.id)
        }
    }

    func loadLastIncidentDate() async {
        if let persistence {
            let recent = await persistence.fetchRecentIncidents(serverConnectionId: connection.id, limit: 1)
            lastIncidentDate = recent.first?.timestamp
        }
    }

    func togglePin(for monitor: UnifiedMonitor) {
        let connectionId = connection.id
        Task {
            await persistence?.togglePin(for: monitor.id, serverConnectionId: connectionId)
            await loadPreferences()
        }
    }

    func toggleHidden(for monitor: UnifiedMonitor) {
        let connectionId = connection.id
        Task {
            await persistence?.toggleHidden(for: monitor.id, serverConnectionId: connectionId)
            await loadPreferences()
        }
    }

    func toggleAcknowledge(for monitor: UnifiedMonitor) {
        let connectionId = connection.id
        if settingsStore.isMonitorAcknowledged(connectionId: connectionId, monitorId: monitor.id) {
            settingsStore.unacknowledgeMonitor(connectionId: connectionId, monitorId: monitor.id)
        } else {
            settingsStore.acknowledgeMonitor(connectionId: connectionId, monitorId: monitor.id)
        }
    }

    // MARK: - Actions

    func openStatusPage() {
        let connection = self.connection
        let url = connection.baseURL.appending(path: "status/\(connection.statusPageSlug)")
        NSWorkspace.shared.open(url)
    }

    func openDashboard() {
        let connection = self.connection
        NSWorkspace.shared.open(connection.baseURL)
    }

    func openMonitor(_ monitor: UnifiedMonitor) {
        let connection = self.connection
        if let monitorUrl = monitor.url {
            NSWorkspace.shared.open(monitorUrl)
        } else {
            // Uptime Kuma public API doesn't expose per-monitor URLs;
            // open the status page which shows all monitors
            let url = connection.baseURL.appending(path: "status/\(connection.statusPageSlug)")
            NSWorkspace.shared.open(url)
        }
    }

    func copySummary() {
        let text = buildSummaryText()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Export

    func exportIncidentsCSV() async -> URL? {
        guard let persistence else { return nil }
        let records = await persistence.fetchRecentIncidents(serverConnectionId: connection.id)
        guard !records.isEmpty else { return nil }

        var csv = "Timestamp,Monitor,Server,Type,Duration (s)\n"
        let isoFormatter = ISO8601DateFormatter()
        for record in records {
            let ts = isoFormatter.string(from: record.timestamp)
            let type = record.transitionType.rawValue
            let duration = record.downDuration.map { String(Int($0)) } ?? ""
            let fields = [
                ts,
                record.monitorName,
                record.serverName,
                type,
                duration
            ].map(Self.csvEscapedField)
            csv += fields.joined(separator: ",") + "\n"
        }
        return writeToTempFile(content: csv, filename: "kuma-incidents.csv")
    }

    func exportIncidentsJSON() async -> URL? {
        guard let persistence else { return nil }
        let records = await persistence.fetchRecentIncidents(serverConnectionId: connection.id)
        guard !records.isEmpty else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        let items: [[String: Any]] = records.map { record in
            var dict: [String: Any] = [
                "timestamp": isoFormatter.string(from: record.timestamp),
                "monitorId": record.monitorId,
                "monitorName": record.monitorName,
                "serverName": record.serverName,
                "type": record.transitionType.rawValue
            ]
            if let duration = record.downDuration {
                dict["downDurationSeconds"] = Int(duration)
            }
            return dict
        }

        guard let data = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys]) else { return nil }
        return writeToTempFile(data: data, filename: "kuma-incidents.json")
    }


    // MARK: - Share

    func shareItems() -> [Any] {
        [buildSummaryText()]
    }

    func buildEmailReport() -> URL? {
        let text = buildSummaryText()
        let subject = String(localized: "Kuma Notify — Status Report")
        var components = URLComponents()
        components.scheme = "mailto"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: text)
        ]
        return components.url
    }

    // MARK: - Helpers

    private func buildSummaryText() -> String {
        var text = "\(summaryText)\n\n"
        for group in groups {
            text += "[\(group.name)]\n"
            for monitor in group.monitors {
                let ping = monitor.latestPing.map {
                    String.localizedStringWithFormat(String(localized: "%@ms"), String($0))
                } ?? "-"
                text += "  \(monitor.currentStatus.label) \(monitor.name) (\(ping))\n"
            }
            text += "\n"
        }
        return text
    }

    private func writeToTempFile(content: String, filename: String) -> URL? {
        writeToTempFile(data: Data(content.utf8), filename: filename)
    }

    private func writeToTempFile(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func csvEscapedField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }

        let escapedQuotes = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapedQuotes)\""
    }

    private func recomputeDerivedState() {
        recomputeSummary()
        recomputeServerLatency()
        recomputeFilteredGroups()
        recomputeOverallStatus()
    }

    private func recomputeSummary() {
        let allMonitors = groups.flatMap(\.monitors)
        guard !allMonitors.isEmpty else {
            summaryText = String(localized: "No data")
            return
        }

        let up = allMonitors.filter { $0.currentStatus == .up }.count
        let total = allMonitors.count
        let timeAgo: String

        if let lastFetchTime {
            timeAgo = lastFetchTime.formatted(.relative(presentation: .numeric))
        } else {
            timeAgo = String(localized: "No data")
        }

        summaryText = String.localizedStringWithFormat(
            String(localized: "%@ — %@"),
            WidgetData.monitorSummaryLine(upCount: up, totalCount: total),
            timeAgo
        )
    }

    private func recomputeServerLatency() {
        let allPings = groups.flatMap(\.monitors).compactMap(\.latestPing)
        guard !allPings.isEmpty else {
            serverLatency = nil
            return
        }

        serverLatency = allPings.reduce(0, +) / allPings.count
    }

    private func recomputeFilteredGroups() {
        filteredGroups = groups.map { group in
            let filtered = group.monitors
                .enumerated()
                .filter { monitor in
                    let monitor = monitor.element
                    let matchesStatus = statusFilter == nil || monitor.currentStatus == statusFilter
                    let matchesSearch = searchText.isEmpty
                        || monitor.name.localizedCaseInsensitiveContains(searchText)
                    let prefKey = MonitorPreference.makeCompositeKey(
                        monitorId: monitor.id,
                        serverConnectionId: connection.id
                    )
                    let pref = monitorPreferences[prefKey]
                    let passesHidden = showHiddenMonitors || !(pref?.isHidden ?? false)
                    return matchesStatus && matchesSearch && passesHidden
                }
                .sorted { a, b in
                    let aKey = MonitorPreference.makeCompositeKey(
                        monitorId: a.element.id,
                        serverConnectionId: connection.id
                    )
                    let bKey = MonitorPreference.makeCompositeKey(
                        monitorId: b.element.id,
                        serverConnectionId: connection.id
                    )
                    let aPinned = monitorPreferences[aKey]?.isPinned ?? false
                    let bPinned = monitorPreferences[bKey]?.isPinned ?? false
                    if aPinned != bPinned { return aPinned }
                    return a.offset < b.offset
                }
                .map(\.element)

            return UnifiedGroup(
                id: group.id,
                name: group.name,
                weight: group.weight,
                monitors: filtered
            )
        }
        .filter { !$0.monitors.isEmpty }
    }

    private func recomputeOverallStatus() {
        let allMonitors = groups.flatMap(\.monitors)
        guard !allMonitors.isEmpty else {
            overallStatus = .unreachable
            return
        }

        let downCount = allMonitors.filter { $0.currentStatus == .down }.count
        if downCount > 0 {
            overallStatus = .someDown(count: downCount, total: allMonitors.count)
            return
        }

        if let reason = findDegradedReason(monitors: allMonitors) {
            overallStatus = .degraded(reason: reason)
            return
        }

        overallStatus = .allUp
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
