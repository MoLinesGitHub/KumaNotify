import SwiftUI

struct WatchRootView: View {
    @Bindable var configurationStore: WatchConfigurationStore
    @Bindable var viewModel: WatchDashboardViewModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true
    @State private var isShowingSettings = false

    var body: some View {
        ZStack {
            if showSplash, configurationStore.connection != nil {
                WatchSplashView(
                    isDataLoaded: viewModel.result != nil || viewModel.errorMessage != nil
                ) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
            } else {
                mainContent
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active,
                  let connection = configurationStore.connection,
                  !isShowingSettings,
                  !showSplash
            else { return }
            Task {
                await viewModel.refresh(connection: connection)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let connection = configurationStore.connection {
            WatchDashboard(
                connection: connection,
                viewModel: viewModel,
                isShowingSettings: $isShowingSettings,
                onSave: handleSave(connection:),
                onDelete: {
                    configurationStore.clear()
                    viewModel.clearSnapshot()
                    isShowingSettings = false
                }
            )
        } else {
            NavigationStack {
                WatchConnectionWizard(onComplete: handleSave(connection:))
                    .navigationTitle(String(localized: "Setup"))
            }
        }
    }

    private func handleSave(connection: ServerConnection) {
        configurationStore.save(connection)
        Task {
            await viewModel.refresh(connection: connection)
        }
    }
}

// MARK: - Dashboard

private struct WatchDashboard: View {
    let connection: ServerConnection
    @Bindable var viewModel: WatchDashboardViewModel
    @Binding var isShowingSettings: Bool
    let onSave: (ServerConnection) -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Status orb hero
                    WatchStatusOrbView(summary: viewModel.summary)
                        .padding(.top, 4)

                    // Status label
                    Text(viewModel.summary.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(viewModel.summary.color)
                        .staggeredAppear(index: 0, baseDelay: 0.3)

                    // Server name + last refresh
                    VStack(spacing: 2) {
                        if let title = viewModel.result?.title, !title.isEmpty {
                            Text(title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        } else {
                            Text(connection.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        if let lastRefresh = viewModel.lastRefreshDate {
                            Text(lastRefresh, format: .relative(presentation: .named))
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .staggeredAppear(index: 1, baseDelay: 0.3)

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.appStatusDown)
                            .multilineTextAlignment(.center)
                            .glassCard(glowColor: .appStatusDown)
                    }

                    // Monitor cards
                    if !viewModel.monitors.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(
                                Array(viewModel.monitors.prefix(12).enumerated()),
                                id: \.element.id
                            ) { index, monitor in
                                NavigationLink {
                                    WatchMonitorDetailView(
                                        monitor: monitor,
                                        latestHeartbeat: viewModel.latestHeartbeat(for: monitor.id)
                                    )
                                } label: {
                                    WatchMonitorCardView(
                                        monitor: monitor,
                                        latestHeartbeat: viewModel.latestHeartbeat(for: monitor.id),
                                        index: index
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Maintenance section
                    if !viewModel.maintenances.isEmpty {
                        WatchSectionHeader(title: String(localized: "Maintenance"), index: 13)

                        ForEach(
                            Array(viewModel.maintenances.prefix(3).enumerated()),
                            id: \.element.id
                        ) { index, maintenance in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(maintenance.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                if let startDate = maintenance.startDate {
                                    Text(startDate, format: .relative(presentation: .named))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(glowColor: .blue.opacity(0.5))
                            .staggeredAppear(index: 14 + index)
                        }
                    }

                    // Incidents section
                    if !viewModel.recentIncidents.isEmpty {
                        WatchSectionHeader(title: String(localized: "Recent incidents"), index: 17)

                        ForEach(
                            Array(viewModel.recentIncidents.prefix(3).enumerated()),
                            id: \.element.id
                        ) { index, incident in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(incident.color)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 4)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(incident.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)

                                    if let detail = incident.detail, !detail.isEmpty {
                                        Text(detail)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.45))
                                            .lineLimit(2)
                                    }

                                    if let date = incident.date {
                                        Text(date, format: .relative(presentation: .named))
                                            .font(.system(size: 9))
                                            .foregroundStyle(.white.opacity(0.35))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(glowColor: incident.color)
                            .staggeredAppear(index: 18 + index)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 16)
            }
            .background(Color.black)
            .overlay {
                if viewModel.isLoading && viewModel.result != nil {
                    // Subtle refresh indicator (not blocking)
                    VStack {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.6)
                                .padding(4)
                        }
                        Spacer()
                    }
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
                            .foregroundStyle(.kumaGreen)
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
                                .foregroundStyle(.kumaGreen)
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                WatchConnectionSettings(
                    connection: connection,
                    onSave: { updated in
                        onSave(updated)
                        isShowingSettings = false
                    },
                    onDelete: onDelete
                )
            }
        }
    }
}

// MARK: - Connection Wizard (first time)

struct WatchConnectionWizard: View {
    let onComplete: (ServerConnection) -> Void

    @State private var step = 0
    @State private var selectedProtocol = "http"
    @State private var ipOctet1 = 192
    @State private var ipOctet2 = 168
    @State private var ipOctet3 = 1
    @State private var ipOctet4 = 1
    @State private var selectedPort = 3001
    @State private var statusPageSlug = ""
    @State private var serverName = ""
    @State private var isConnecting = false
    @State private var connectError: String?

    private let service: any MonitoringServiceProtocol

    private static let protocols = ["http", "https"]
    private static let portRange = 1000...19999

    init(
        service: any MonitoringServiceProtocol = UptimeKumaService(),
        onComplete: @escaping (ServerConnection) -> Void
    ) {
        self.service = service
        self.onComplete = onComplete
    }

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.kumaGreen : Color.white.opacity(0.2))
                        .frame(width: 5, height: 5)
                        .scaleEffect(i == step ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3), value: step)
                }
            }
            .padding(.bottom, 8)

            // Step content
            TabView(selection: $step) {
                wizardProtocol.tag(0)
                wizardIP.tag(1)
                wizardPort.tag(2)
                wizardSlug.tag(3)
                wizardConfirm.tag(4)
            }
            .tabViewStyle(.verticalPage)
        }
        .background(Color.black)
    }

    // Step 0: Protocol
    private var wizardProtocol: some View {
        VStack(spacing: 12) {
            WizardStepLabel(title: String(localized: "Protocol"))

            Picker(String(localized: "Protocol"), selection: $selectedProtocol) {
                ForEach(Self.protocols, id: \.self) { proto in
                    Text(proto.uppercased())
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .tag(proto)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 60)

            WizardNextButton { step = 1 }
        }
        .glassCard(glowColor: .kumaGreen)
    }

    // Step 1: IP Address
    private var wizardIP: some View {
        VStack(spacing: 8) {
            WizardStepLabel(title: String(localized: "IP Address"))

            HStack(spacing: 2) {
                wizardOctetPicker($ipOctet1)
                wizardDot
                wizardOctetPicker($ipOctet2)
                wizardDot
                wizardOctetPicker($ipOctet3)
                wizardDot
                wizardOctetPicker($ipOctet4)
            }

            Text("\(ipOctet1).\(ipOctet2).\(ipOctet3).\(ipOctet4)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.kumaGreen)

            WizardNextButton { step = 2 }
        }
        .glassCard(glowColor: .kumaGreen)
    }

    // Step 2: Port
    private var wizardPort: some View {
        VStack(spacing: 8) {
            WizardStepLabel(title: String(localized: "Port"))

            Picker(String(localized: "Port"), selection: $selectedPort) {
                ForEach(Self.portRange, id: \.self) { port in
                    Text(String(port))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .tag(port)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 60)

            Text(":\(selectedPort)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.kumaGreen)

            WizardNextButton { step = 3 }
        }
        .glassCard(glowColor: .kumaGreen)
    }

    // Step 3: Slug
    private var wizardSlug: some View {
        VStack(spacing: 8) {
            WizardStepLabel(title: String(localized: "Status Page Slug"))

            TextField(String(localized: "slug"), text: $statusPageSlug)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, design: .monospaced))

            WizardNextButton(disabled: statusPageSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                step = 4
            }
        }
        .glassCard(glowColor: .kumaGreen)
    }

    // Step 4: Confirm & Connect
    private var wizardConfirm: some View {
        VStack(spacing: 8) {
            WizardStepLabel(title: String(localized: "Confirm"))

            VStack(alignment: .leading, spacing: 4) {
                wizardSummaryRow(String(localized: "URL"), composedURLString)
                wizardSummaryRow(String(localized: "Slug"), statusPageSlug)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)

            if let error = connectError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.appStatusDown)
                    .lineLimit(3)
            }

            Button {
                Task { await connect() }
            } label: {
                if isConnecting {
                    ProgressView()
                } else {
                    Text(String(localized: "Connect"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.kumaGreen)
            .disabled(isConnecting)
        }
        .glassCard(glowColor: .kumaGreen)
    }

    private func wizardSummaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text(value)
                .lineLimit(1)
                .foregroundStyle(.kumaGreenLight)
        }
    }

    private func wizardOctetPicker(_ value: Binding<Int>) -> some View {
        Picker("", selection: value) {
            ForEach(0...255, id: \.self) { n in
                Text(String(n))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .tag(n)
            }
        }
        .pickerStyle(.wheel)
        .frame(width: 36, height: 50)
        .clipped()
    }

    private var wizardDot: some View {
        Text(".")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundStyle(.kumaGreen)
    }

    private var composedURLString: String {
        "\(selectedProtocol)://\(ipOctet1).\(ipOctet2).\(ipOctet3).\(ipOctet4):\(selectedPort)"
    }

    private func connect() async {
        connectError = nil
        guard let baseURL = ServerConnection.validatedBaseURL(from: composedURLString),
              let slug = ServerConnection.validatedStatusPageSlug(from: statusPageSlug)
        else {
            connectError = String(localized: "Invalid URL")
            return
        }

        let name = serverName.isEmpty ? String(localized: "My Kuma Server") : serverName
        let draft = ServerConnection(
            id: UUID(),
            name: ServerConnection.normalizedDisplayName(from: name),
            baseURL: baseURL,
            statusPageSlug: slug,
            isDefault: true
        )

        isConnecting = true
        defer { isConnecting = false }

        do {
            _ = try await service.validateConnection(draft)
            onComplete(draft)
        } catch {
            connectError = error.localizedDescription
        }
    }
}

// MARK: - Wizard Helpers

private struct WizardStepLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.kumaGreenLight)
            .textCase(.uppercase)
    }
}

private struct WizardNextButton: View {
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35)) {
                action()
            }
        } label: {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.kumaGreen)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

// MARK: - Connection Settings (after first time) — TabView pages

struct WatchConnectionSettings: View {
    let connection: ServerConnection
    let onSave: (ServerConnection) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedProtocol: String
    @State private var ipOctet1: Int
    @State private var ipOctet2: Int
    @State private var ipOctet3: Int
    @State private var ipOctet4: Int
    @State private var selectedPort: Int
    @State private var statusPageSlug: String
    @State private var name: String
    @State private var isConnecting = false
    @State private var connectError: String?
    @State private var selectedTab = 0

    private let service: any MonitoringServiceProtocol

    private static let protocols = ["http", "https"]
    private static let portRange = 1000...19999

    init(
        connection: ServerConnection,
        service: any MonitoringServiceProtocol = UptimeKumaService(),
        onSave: @escaping (ServerConnection) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.connection = connection
        self.service = service
        self.onSave = onSave
        self.onDelete = onDelete

        _name = State(initialValue: connection.name)
        _statusPageSlug = State(initialValue: connection.statusPageSlug)

        if let components = URLComponents(url: connection.baseURL, resolvingAgainstBaseURL: false) {
            let octets = (components.host ?? "").split(separator: ".").compactMap { Int($0) }
            _selectedProtocol = State(initialValue: components.scheme ?? "http")
            _ipOctet1 = State(initialValue: octets.count > 0 ? octets[0] : 192)
            _ipOctet2 = State(initialValue: octets.count > 1 ? octets[1] : 168)
            _ipOctet3 = State(initialValue: octets.count > 2 ? octets[2] : 1)
            _ipOctet4 = State(initialValue: octets.count > 3 ? octets[3] : 1)
            let port = components.port ?? 3001
            _selectedPort = State(initialValue: Self.portRange.contains(port) ? port : 3001)
        } else {
            _selectedProtocol = State(initialValue: "http")
            _ipOctet1 = State(initialValue: 192)
            _ipOctet2 = State(initialValue: 168)
            _ipOctet3 = State(initialValue: 1)
            _ipOctet4 = State(initialValue: 1)
            _selectedPort = State(initialValue: 3001)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 0) {
                    settingsTabButton(String(localized: "Server"), systemImage: "server.rack", tab: 0)
                    settingsTabButton(String(localized: "Network"), systemImage: "network", tab: 1)
                    settingsTabButton(String(localized: "Danger"), systemImage: "exclamationmark.triangle", tab: 2)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)

                TabView(selection: $selectedTab) {
                    // Tab 0: Server
                    serverTab.tag(0)
                    // Tab 1: Network
                    networkTab.tag(1)
                    // Tab 2: Danger zone
                    dangerTab.tag(2)
                }
                .tabViewStyle(.verticalPage)
            }
            .background(Color.black)
            .navigationTitle(String(localized: "Settings"))
        }
    }

    private func settingsTabButton(_ label: String, systemImage: String, tab: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? .kumaGreen : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // Tab 0: Server info
    private var serverTab: some View {
        ScrollView {
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Name"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.kumaGreenLight)
                    TextField(String(localized: "Server"), text: $name)
                        .font(.system(size: 13))
                }
                .glassCard(glowColor: .kumaGreenDim)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Status Page Slug"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.kumaGreenLight)
                    TextField(String(localized: "slug"), text: $statusPageSlug)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 13, design: .monospaced))
                }
                .glassCard(glowColor: .kumaGreenDim)

                saveButton
            }
            .padding(.horizontal, 4)
        }
    }

    // Tab 1: Network
    private var networkTab: some View {
        ScrollView {
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Protocol"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.kumaGreenLight)
                    Picker(String(localized: "Protocol"), selection: $selectedProtocol) {
                        ForEach(Self.protocols, id: \.self) { proto in
                            Text(proto.uppercased()).tag(proto)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 50)
                }
                .glassCard(glowColor: .kumaGreenDim)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "IP Address"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.kumaGreenLight)
                    HStack(spacing: 2) {
                        settingsOctetPicker($ipOctet1)
                        settingsDot
                        settingsOctetPicker($ipOctet2)
                        settingsDot
                        settingsOctetPicker($ipOctet3)
                        settingsDot
                        settingsOctetPicker($ipOctet4)
                    }
                    Text("\(ipOctet1).\(ipOctet2).\(ipOctet3).\(ipOctet4)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.kumaGreen)
                }
                .glassCard(glowColor: .kumaGreenDim)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Port"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.kumaGreenLight)
                    Picker(String(localized: "Port"), selection: $selectedPort) {
                        ForEach(Self.portRange, id: \.self) { port in
                            Text(String(port)).tag(port)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 50)
                    Text(":\(selectedPort)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.kumaGreen)
                }
                .glassCard(glowColor: .kumaGreenDim)

                saveButton
            }
            .padding(.horizontal, 4)
        }
    }

    // Tab 2: Danger zone
    private var dangerTab: some View {
        VStack(spacing: 12) {
            Spacer()

            Button(role: .destructive) {
                onDelete()
                dismiss()
            } label: {
                Label(String(localized: "Delete Server"), systemImage: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .glassCard(glowColor: .appStatusDown)

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var saveButton: some View {
        VStack(spacing: 4) {
            if let error = connectError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.appStatusDown)
                    .lineLimit(3)
            }

            Button {
                Task { await connect() }
            } label: {
                if isConnecting {
                    ProgressView()
                } else {
                    Text(String(localized: "Save"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.kumaGreen)
            .disabled(isConnecting || !hasMinimumInput)
        }
    }

    private func settingsOctetPicker(_ value: Binding<Int>) -> some View {
        Picker("", selection: value) {
            ForEach(0...255, id: \.self) { n in
                Text(String(n))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .tag(n)
            }
        }
        .pickerStyle(.wheel)
        .frame(width: 36, height: 50)
        .clipped()
    }

    private var settingsDot: some View {
        Text(".")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundStyle(.kumaGreen)
    }

    private var hasMinimumInput: Bool {
        !statusPageSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var composedURLString: String {
        "\(selectedProtocol)://\(ipOctet1).\(ipOctet2).\(ipOctet3).\(ipOctet4):\(selectedPort)"
    }

    private func connect() async {
        connectError = nil
        guard let baseURL = ServerConnection.validatedBaseURL(from: composedURLString),
              let slug = ServerConnection.validatedStatusPageSlug(from: statusPageSlug)
        else {
            connectError = String(localized: "Invalid URL")
            return
        }

        let draft = ServerConnection(
            id: connection.id,
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
        } catch {
            connectError = error.localizedDescription
        }
    }
}
