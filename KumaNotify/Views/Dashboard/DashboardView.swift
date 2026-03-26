import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DashboardView: View {
    @Bindable var menuBarVM: MenuBarViewModel
    @Bindable var dashboardVM: DashboardViewModel
    var storeManager: StoreManager
    var settingsStore: SettingsStore
    var persistence: PersistenceManager?

    @State private var showPaywall = false

    private var isPro: Bool { storeManager.proUnlocked }
    private var connections: [ServerConnection] { settingsStore.serverConnections }
    private var hasMultipleServers: Bool { connections.count > 1 }

    var body: some View {
        VStack(spacing: 0) {
            if showPaywall {
                PaywallView(storeManager: storeManager) {
                    showPaywall = false
                }
            } else if dashboardVM.showIncidentHistory {
                IncidentHistoryView(
                    incidents: dashboardVM.incidentRecords,
                    onDismiss: { dashboardVM.showIncidentHistory = false }
                )
            } else {
                mainContent
            }
        }
        .frame(width: 340)
        .frame(minHeight: 300, maxHeight: 500)
        .task {
            await dashboardVM.fetchData()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Server selector (only when multiple servers exist)
            if hasMultipleServers {
                serverSelector
                Divider()
            }

            SummaryHeaderView(
                summary: dashboardVM.summaryText,
                latency: dashboardVM.serverLatency,
                overallStatus: menuBarVM.overallStatus,
                lastIncidentDate: dashboardVM.lastIncidentDate
            )

            Divider()

            if isPro {
                FilterBarView(
                    statusFilter: $dashboardVM.statusFilter,
                    searchText: $dashboardVM.searchText,
                    uptimePeriod: $dashboardVM.uptimePeriod
                )
                Divider()
            }

            if let error = dashboardVM.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                Divider()
            }

            if isPro, !dashboardVM.maintenances.isEmpty {
                MaintenanceBannerView(maintenances: dashboardVM.maintenances)
                Divider()
            }

            ScrollView {
                LazyVStack(spacing: 8, pinnedViews: .sectionHeaders) {
                    ForEach(dashboardVM.filteredGroups, id: \.id) { group in
                        MonitorGroupSection(
                            group: group,
                            heartbeats: dashboardVM.heartbeats,
                            uptimePeriod: dashboardVM.uptimePeriod,
                            monitorPreferences: dashboardVM.monitorPreferences,
                            showProFeatures: isPro,
                            acknowledgedMonitors: isPro ? settingsStore.acknowledgedMonitors : [],
                            connectionId: dashboardVM.connection.id,
                            onMonitorTap: { dashboardVM.openMonitor($0) },
                            onTogglePin: isPro ? { dashboardVM.togglePin(for: $0) } : { _ in showPaywall = true },
                            onToggleHidden: isPro ? { dashboardVM.toggleHidden(for: $0) } : { _ in showPaywall = true },
                            onToggleAcknowledge: isPro ? { dashboardVM.toggleAcknowledge(for: $0) } : { _ in showPaywall = true }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }

            Divider()

            bottomToolbar
        }
    }

    // MARK: - Server Selector

    private var serverSelector: some View {
        HStack(spacing: 6) {
            Image(systemName: "server.rack")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: Binding(
                get: { dashboardVM.connection.id },
                set: { newId in switchServer(to: newId) }
            )) {
                ForEach(connections) { conn in
                    Text(conn.name).tag(conn.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func exportFile(_ url: URL?) {
        guard let url else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.allowedContentTypes = [.data]
        panel.begin { response in
            if response == .OK, let dest = panel.url {
                do {
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.copyItem(at: url, to: dest)
                } catch {
                    // NSSavePanel already handles overwrite confirmation
                }
            }
        }
    }

    private func showShareSheet() {
        let items = dashboardVM.shareItems()
        let picker = NSSharingServicePicker(items: items)
        guard let contentView = NSApp.keyWindow?.contentView else { return }
        picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
    }

    private func switchServer(to id: UUID) {
        guard let conn = connections.first(where: { $0.id == id }) else { return }
        dashboardVM.switchConnection(conn)
        Task { await dashboardVM.fetchData() }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await dashboardVM.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(menuBarVM.pollingEngine.isPolling)
            .accessibilityLabel(String(localized: "Refresh"))

            Button {
                if isPro {
                    dashboardVM.loadIncidentHistory()
                    dashboardVM.showIncidentHistory = true
                } else {
                    showPaywall = true
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "Incident History"))

            Button {
                dashboardVM.copySummary()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "Copy Summary"))

            Spacer()

            Menu {
                Button("Open Status Page") { dashboardVM.openStatusPage() }
                Button("Open Dashboard") { dashboardVM.openDashboard() }
                Divider()
                if isPro {
                    Toggle("Show Hidden Monitors", isOn: $dashboardVM.showHiddenMonitors)
                    Menu("Export Incidents") {
                        Button(String(localized: "CSV")) { exportFile(dashboardVM.exportIncidentsCSV()) }
                        Button(String(localized: "JSON")) { exportFile(dashboardVM.exportIncidentsJSON()) }
                    }
                    Button("Share Status...") { showShareSheet() }
                    Button("Email Report") {
                        if let url = dashboardVM.buildEmailReport() {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                if !isPro {
                    Button("Upgrade to Pro...") { showPaywall = true }
                }
                Divider()
                SettingsLink {
                    Text("Settings...")
                }
                Divider()
                Button("Quit Kuma Notify") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .accessibilityLabel(String(localized: "More Options"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
