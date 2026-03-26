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

    private var isPro: Bool {
        #if DEBUG
        storeManager.effectiveProUnlocked
        #else
        storeManager.proUnlocked
        #endif
    }
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
        .frame(width: 380)
        .frame(minHeight: 400, maxHeight: 700)
        .task {
            await dashboardVM.fetchData()
        }
        .onChange(of: storeManager.proUnlocked) {
            if storeManager.proUnlocked { showPaywall = false }
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
                LazyVStack(spacing: 12, pinnedViews: .sectionHeaders) {
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
        // MenuBarExtra panels may not be keyWindow; find the frontmost panel
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.className.contains("StatusBarWindow") })
                ?? NSApp.keyWindow,
              let contentView = window.contentView else { return }
        picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
    }

    private func switchServer(to id: UUID) {
        guard let conn = connections.first(where: { $0.id == id }) else { return }
        dashboardVM.switchConnection(conn)
        Task { await dashboardVM.fetchData() }
    }

    // MARK: - Bottom Toolbar

    private func toolbarIcon(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        ToolbarButton(systemName: systemName, action: action)
            .accessibilityLabel(label)
    }

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            toolbarIcon("arrow.clockwise", label: String(localized: "Refresh")) {
                Task {
                    await dashboardVM.refresh()
                    await menuBarVM.refresh()
                }
            }
            .opacity(menuBarVM.pollingEngine.isPolling ? 0.3 : 1)

            toolbarIcon("clock.arrow.circlepath", label: String(localized: "Incident History")) {
                if isPro {
                    dashboardVM.loadIncidentHistory()
                    dashboardVM.showIncidentHistory = true
                } else {
                    showPaywall = true
                }
            }

            toolbarIcon("doc.on.doc", label: String(localized: "Copy Summary")) {
                dashboardVM.copySummary()
            }

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
                    .font(.body)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel(String(localized: "More Options"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        #if DEBUG
        .overlay(alignment: .bottom) {
            debugProToggle
                .padding(.top, 4)
                .offset(y: 28)
        }
        #endif
    }

    #if DEBUG
    private var debugProToggle: some View {
        HStack(spacing: 6) {
            Text("Free")
                .font(.caption2)
                .foregroundStyle(isPro ? .secondary : .primary)
            Toggle("", isOn: Binding(
                get: { storeManager.debugProOverride ?? storeManager.proUnlocked },
                set: { storeManager.debugProOverride = $0 }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            Text("Pro")
                .font(.caption2)
                .foregroundStyle(isPro ? .yellow : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
    }
    #endif
}
