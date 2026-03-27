import SwiftUI

struct WatchRootView: View {
    @Bindable var configurationStore: WatchConfigurationStore
    @Bindable var viewModel: WatchDashboardViewModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if let connection = configurationStore.connection {
                    dashboard(connection: connection)
                } else {
                    WatchConnectionForm(
                        initialConnection: nil,
                        onSave: handleSave(connection:)
                    )
                }
            }
            .navigationTitle(String(localized: "Server"))
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active,
                  let connection = configurationStore.connection,
                  !isShowingSettings
            else { return }

            Task {
                await viewModel.refresh(connection: connection)
            }
        }
    }

    @ViewBuilder
    private func dashboard(connection: ServerConnection) -> some View {
        let summary = viewModel.summary

        List {
            Section {
                HStack(spacing: 8) {
                    Circle()
                        .fill(summary.color)
                        .frame(width: 10, height: 10)
                    Text(summary.label)
                        .font(.headline)
                }

                if summary.totalCount > 0 {
                    Text(WidgetData.monitorSummaryLine(
                        upCount: summary.upCount,
                        totalCount: summary.totalCount
                    ))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                if let title = viewModel.result?.title, !title.isEmpty {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(connection.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                if let lastRefreshDate = viewModel.lastRefreshDate {
                    Text(lastRefreshDate, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if !viewModel.monitors.isEmpty {
                Section {
                    ForEach(viewModel.monitors.prefix(12)) { monitor in
                        NavigationLink {
                            WatchMonitorDetailView(
                                monitor: monitor,
                                latestHeartbeat: viewModel.latestHeartbeat(for: monitor.id)
                            )
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: monitor.currentStatus.sfSymbol)
                                    .foregroundStyle(monitor.currentStatus.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(monitor.name)
                                        .lineLimit(1)
                                    Text(monitor.currentStatus.label)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if !viewModel.maintenances.isEmpty {
                Section(String(localized: "Maintenance")) {
                    ForEach(viewModel.maintenances.prefix(3)) { maintenance in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(maintenance.title)
                                .lineLimit(2)
                            if let startDate = maintenance.startDate {
                                Text(startDate, format: .relative(presentation: .named))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !viewModel.recentIncidents.isEmpty {
                Section(String(localized: "Recent incidents")) {
                    ForEach(viewModel.recentIncidents.prefix(3)) { incident in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Circle()
                                    .fill(incident.color)
                                    .frame(width: 6, height: 6)
                                Text(incident.title)
                                    .lineLimit(2)
                            }

                            if let detail = incident.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            if let date = incident.date {
                                Text(date, format: .relative(presentation: .named))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task(id: connection.id) {
            if viewModel.result == nil && !viewModel.isLoading {
                await viewModel.refresh(connection: connection)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh(connection: connection) }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            WatchConnectionForm(
                initialConnection: connection,
                onSave: { updatedConnection in
                    handleSave(connection: updatedConnection)
                    isShowingSettings = false
                },
                onDelete: {
                    configurationStore.clear()
                    viewModel.clearSnapshot()
                    isShowingSettings = false
                }
            )
        }
    }

    private func handleSave(connection: ServerConnection) {
        configurationStore.save(connection)
        Task {
            await viewModel.refresh(connection: connection)
        }
    }
}

private struct WatchConnectionForm: View {
    let initialConnection: ServerConnection?
    let onSave: (ServerConnection) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var baseURLString: String
    @State private var statusPageSlug: String
    @State private var isConnecting = false
    @State private var connectError: String?

    private let service: any MonitoringServiceProtocol

    init(
        initialConnection: ServerConnection?,
        service: any MonitoringServiceProtocol = UptimeKumaService(),
        onSave: @escaping (ServerConnection) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.initialConnection = initialConnection
        self.service = service
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: initialConnection?.name ?? String(localized: "My Kuma Server"))
        _baseURLString = State(initialValue: initialConnection?.baseURL.absoluteString ?? "")
        _statusPageSlug = State(initialValue: initialConnection?.statusPageSlug ?? "")
    }

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Server"), text: $name)
                TextField(String(localized: "Server URL"), text: $baseURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField(String(localized: "Status Page Slug"), text: $statusPageSlug)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if let connectError {
                Section {
                    Text(connectError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await connect() }
                } label: {
                    if isConnecting {
                        ProgressView()
                    } else {
                        Text(String(localized: "Save"))
                    }
                }
                .disabled(isConnecting || !hasMinimumInput)

                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private var hasMinimumInput: Bool {
        !baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !statusPageSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func connect() async {
        connectError = nil

        guard let baseURL = ServerConnection.validatedBaseURL(from: baseURLString),
              let slug = ServerConnection.validatedStatusPageSlug(from: statusPageSlug)
        else {
            connectError = String(localized: "Invalid URL")
            return
        }

        let draft = ServerConnection(
            id: initialConnection?.id ?? UUID(),
            name: ServerConnection.normalizedDisplayName(from: name),
            baseURL: baseURL,
            statusPageSlug: slug,
            isDefault: true
        )

        isConnecting = true
        defer { isConnecting = false }

        do {
            _ = try await service.validateConnection(draft)
            onSave(draft)
            dismiss()
        } catch {
            connectError = error.localizedDescription
        }
    }
}
