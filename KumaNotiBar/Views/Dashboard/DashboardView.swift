import SwiftUI

struct DashboardView: View {
    @Bindable var menuBarVM: MenuBarViewModel
    @Bindable var dashboardVM: DashboardViewModel

    var body: some View {
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
                            onMonitorTap: nil
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }

            Divider()

            bottomToolbar
        }
        .frame(width: 340)
        .frame(minHeight: 300, maxHeight: 500)
        .task {
            await dashboardVM.fetchData()
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
                SettingsLink {
                    Text("Settings...")
                }
                Divider()
                Button("Quit Kuma NotiBar") {
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
