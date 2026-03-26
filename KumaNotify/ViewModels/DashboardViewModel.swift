import SwiftUI
import AppKit

@Observable
@MainActor
final class DashboardViewModel {
    private let settingsStore: SettingsStore
    private let persistence: PersistenceManager?
    private(set) var connection: ServerConnection

    var groups: [UnifiedGroup] = []
    var heartbeats: [String: [UnifiedHeartbeat]] = [:]
    var incidents: [UKIncident] = []
    var maintenances: [UnifiedMaintenance] = []
    var statusFilter: MonitorStatus?
    var searchText = ""
    var uptimePeriod: UptimePeriod = .twentyFourHours
    var isLoading = false
    var errorMessage: String?

    // Phase 3: Persistence state
    var monitorPreferences: [String: MonitorPreference] = [:]
    var showHiddenMonitors = false
    var incidentRecords: [IncidentRecord] = []
    var showIncidentHistory = false
    var lastIncidentDate: Date?

    var summaryText: String {
        let allMonitors = groups.flatMap(\.monitors)
        let up = allMonitors.filter { $0.currentStatus == .up }.count
        let total = allMonitors.count
        let timeAgo = relativeTimeString
        return String(localized: "\(up)/\(total) OK — \(timeAgo)")
    }

    var serverLatency: Int? {
        let allPings = groups.flatMap(\.monitors).compactMap(\.latestPing)
        guard !allPings.isEmpty else { return nil }
        return allPings.reduce(0, +) / allPings.count
    }

    private var lastFetchTime: Date?

    private var relativeTimeString: String {
        guard let lastFetchTime else { return String(localized: "never") }
        return lastFetchTime.formatted(.relative(presentation: .numeric))
    }

    var filteredGroups: [UnifiedGroup] {
        groups.map { group in
            let filtered = group.monitors
                .filter { monitor in
                    let matchesStatus = statusFilter == nil || monitor.currentStatus == statusFilter
                    let matchesSearch = searchText.isEmpty
                        || monitor.name.localizedCaseInsensitiveContains(searchText)
                    let pref = monitorPreferences[monitor.id]
                    let passesHidden = showHiddenMonitors || !(pref?.isHidden ?? false)
                    return matchesStatus && matchesSearch && passesHidden
                }
                .sorted { a, b in
                    let aPinned = monitorPreferences[a.id]?.isPinned ?? false
                    let bPinned = monitorPreferences[b.id]?.isPinned ?? false
                    if aPinned != bPinned { return aPinned }
                    return false
                }
            return UnifiedGroup(
                id: group.id,
                name: group.name,
                weight: group.weight,
                monitors: filtered
            )
        }.filter { !$0.monitors.isEmpty }
    }

    init(
        connection: ServerConnection,
        settingsStore: SettingsStore,
        persistence: PersistenceManager? = nil
    ) {
        self.connection = connection
        self.settingsStore = settingsStore
        self.persistence = persistence
    }

    func fetchData() async {
        let service = MonitoringServiceFactory.create(for: connection.provider)
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await service.fetchStatusPage(connection: connection)
            groups = result.groups
            incidents = result.incidents
            maintenances = result.maintenances

            let hbResult = try await service.fetchHeartbeats(connection: connection)
            heartbeats = hbResult.heartbeats

            lastFetchTime = Date()
            errorMessage = nil

            loadPreferences()
            loadLastIncidentDate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func switchConnection(_ newConnection: ServerConnection) {
        connection = newConnection
        groups = []
        heartbeats = [:]
        incidents = []
        maintenances = []
        errorMessage = nil
    }

    func refresh() async {
        await fetchData()
    }

    // MARK: - Persistence

    func loadPreferences() {
        monitorPreferences = persistence?.fetchAllPreferences() ?? [:]
    }

    func loadIncidentHistory() {
        incidentRecords = persistence?.fetchRecentIncidents() ?? []
    }

    func loadLastIncidentDate() {
        let recent = persistence?.fetchRecentIncidents(limit: 1) ?? []
        lastIncidentDate = recent.first?.timestamp
    }

    func togglePin(for monitor: UnifiedMonitor) {
        let connectionId = connection.id
        persistence?.togglePin(for: monitor.id, serverConnectionId: connectionId)
        loadPreferences()
    }

    func toggleHidden(for monitor: UnifiedMonitor) {
        let connectionId = connection.id
        persistence?.toggleHidden(for: monitor.id, serverConnectionId: connectionId)
        loadPreferences()
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

    func exportIncidentsCSV() -> URL? {
        let records = persistence?.fetchRecentIncidents() ?? []
        guard !records.isEmpty else { return nil }

        var csv = "Timestamp,Monitor,Server,Type,Duration (s)\n"
        let isoFormatter = ISO8601DateFormatter()
        for record in records {
            let ts = isoFormatter.string(from: record.timestamp)
            let type = record.transitionType.rawValue
            let duration = record.downDuration.map { String(Int($0)) } ?? ""
            csv += "\(ts),\(record.monitorName),\(record.serverName),\(type),\(duration)\n"
        }
        return writeToTempFile(content: csv, filename: "kuma-incidents.csv")
    }

    func exportIncidentsJSON() -> URL? {
        let records = persistence?.fetchRecentIncidents() ?? []
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
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:?subject=\(subjectEncoded)&body=\(encoded)")
    }

    // MARK: - Helpers

    private func buildSummaryText() -> String {
        var text = "\(summaryText)\n\n"
        for group in groups {
            text += "[\(group.name)]\n"
            for monitor in group.monitors {
                let ping = monitor.latestPing.map { "\($0)ms" } ?? "-"
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
}
