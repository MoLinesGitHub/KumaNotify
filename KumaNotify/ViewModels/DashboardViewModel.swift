import SwiftUI
import AppKit

@Observable
@MainActor
final class DashboardViewModel {
    private let service: any MonitoringServiceProtocol
    private let settingsStore: SettingsStore
    private let persistence: PersistenceManager?

    var groups: [UnifiedGroup] = []
    var heartbeats: [String: [UnifiedHeartbeat]] = [:]
    var incidents: [UKIncident] = []
    var maintenances: [UKMaintenance] = []
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

    var summaryText: String {
        let allMonitors = groups.flatMap(\.monitors)
        let up = allMonitors.filter { $0.currentStatus == .up }.count
        let total = allMonitors.count
        let timeAgo = relativeTimeString
        return "\(up)/\(total) OK — \(timeAgo)"
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
        service: any MonitoringServiceProtocol,
        settingsStore: SettingsStore,
        persistence: PersistenceManager? = nil
    ) {
        self.service = service
        self.settingsStore = settingsStore
        self.persistence = persistence
    }

    func fetchData() async {
        guard let connection = settingsStore.serverConnection else { return }
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
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func togglePin(for monitor: UnifiedMonitor) {
        guard let connectionId = settingsStore.serverConnection?.id else { return }
        persistence?.togglePin(for: monitor.id, serverConnectionId: connectionId)
        loadPreferences()
    }

    func toggleHidden(for monitor: UnifiedMonitor) {
        guard let connectionId = settingsStore.serverConnection?.id else { return }
        persistence?.toggleHidden(for: monitor.id, serverConnectionId: connectionId)
        loadPreferences()
    }

    // MARK: - Actions

    func openStatusPage() {
        guard let connection = settingsStore.serverConnection else { return }
        let url = connection.baseURL.appending(path: "status/\(connection.statusPageSlug)")
        NSWorkspace.shared.open(url)
    }

    func openDashboard() {
        guard let connection = settingsStore.serverConnection else { return }
        NSWorkspace.shared.open(connection.baseURL)
    }

    func copySummary() {
        var text = "Status: \(summaryText)\n\n"
        for group in groups {
            text += "[\(group.name)]\n"
            for monitor in group.monitors {
                let status = monitor.currentStatus == .up ? "UP" : "DOWN"
                let ping = monitor.latestPing.map { "\($0)ms" } ?? "-"
                text += "  \(status) \(monitor.name) (\(ping))\n"
            }
            text += "\n"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
