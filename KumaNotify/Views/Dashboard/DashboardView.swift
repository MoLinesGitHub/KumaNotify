import SwiftUI

struct DashboardView: View {
    @Bindable var menuBarVM: MenuBarViewModel
    @Bindable var dashboardVM: DashboardViewModel

    var body: some View {
        VStack(spacing: 0) {
            if dashboardVM.showIncidentHistory {
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
            SummaryHeaderView(
                summary: dashboardVM.summaryText,
                latency: dashboardVM.serverLatency,
                overallStatus: menuBarVM.overallStatus
            )

            Divider()

            FilterBarView(
                statusFilter: $dashboardVM.statusFilter,
                searchText: $dashboardVM.searchText,
                uptimePeriod: $dashboardVM.uptimePeriod
            )

            Divider()

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

            ScrollView {
                LazyVStack(spacing: 8, pinnedViews: .sectionHeaders) {
                    ForEach(dashboardVM.filteredGroups, id: \.id) { group in
                        MonitorGroupSection(
                            group: group,
                            heartbeats: dashboardVM.heartbeats,
                            uptimePeriod: dashboardVM.uptimePeriod,
                            monitorPreferences: dashboardVM.monitorPreferences,
                            onMonitorTap: nil,
                            onTogglePin: { dashboardVM.togglePin(for: $0) },
                            onToggleHidden: { dashboardVM.toggleHidden(for: $0) }
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

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await dashboardVM.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(menuBarVM.pollingEngine.isPolling)

            Button {
                dashboardVM.loadIncidentHistory()
                dashboardVM.showIncidentHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .buttonStyle(.borderless)

            Button {
                dashboardVM.copySummary()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)

            Spacer()

            Menu {
                Button("Open Status Page") { dashboardVM.openStatusPage() }
                Button("Open Dashboard") { dashboardVM.openDashboard() }
                Divider()
                Toggle("Show Hidden Monitors", isOn: $dashboardVM.showHiddenMonitors)
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
