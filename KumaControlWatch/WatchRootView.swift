import SwiftUI

struct WatchRootView: View {
    @Bindable var configurationStore: WatchConfigurationStore
    @Bindable var viewModel: WatchDashboardViewModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true
    @State private var isShowingSettings = false

    var body: some View {
        ZStack {
            if showSplash {
                let hasConnection = configurationStore.connection != nil
                WatchSplashView(
                    isDataLoaded: !hasConnection || viewModel.result != nil || viewModel.errorMessage != nil
                ) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
                .task {
                    if let connection = configurationStore.connection {
                        await viewModel.refresh(connection: connection)
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
                    .navigationTitle(String(localized: "Configuración"))
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

                    // Error message + WiFi tip
                    if let error = viewModel.errorMessage {
                        VStack(spacing: 6) {
                            Text(error)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.appStatusDown)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 4) {
                                Image(systemName: "wifi.exclamationmark")
                                    .font(.system(size: 9))
                                Text(String(localized: "El Apple Watch debe estar en la misma red WiFi que el servidor"))
                                    .font(.system(size: 9))
                            }
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                        }
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
                            .foregroundStyle(Color.kumaGreen)
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
                                .foregroundStyle(Color.kumaGreen)
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

            // Step content — no TabView to avoid crown conflicts with pickers
            Group {
                switch step {
                case 0: wizardProtocol
                case 1: wizardIP
                case 2: wizardPort
                case 3: wizardSlug
                default: wizardConfirm
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        if horizontal > 50, step > 0 {
                            withAnimation(.spring(response: 0.35)) { step -= 1 }
                        } else if horizontal < -50, step < totalSteps - 1 {
                            withAnimation(.spring(response: 0.35)) { step += 1 }
                        }
                    }
            )
            .animation(.spring(response: 0.35), value: step)
        }
        .background(Color.black)
    }

    // Step 0: Protocol
    private var wizardProtocol: some View {
        VStack(spacing: 12) {
            WizardStepLabel(title: String(localized: "Protocolo"))

            Picker("", selection: $selectedProtocol) {
                ForEach(Self.protocols, id: \.self) { proto in
                    Text(proto.uppercased())
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .tag(proto)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 60)

            WizardNavButtons(showBack: false) { step = 1 }
        }
        .glassCard(glowColor: .kumaGreen)
    }

    // Step 1: IP Address
    private var wizardIP: some View {
        VStack(spacing: 8) {
            WizardStepLabel(title: String(localized: "Dirección IP"))

            HStack(spacing: 3) {
                OctetButton(value: $ipOctet1)
                octetDotView
                OctetButton(value: $ipOctet2)
                octetDotView
                OctetButton(value: $ipOctet3)
                octetDotView
                OctetButton(value: $ipOctet4)
            }

            WizardNavButtons(onBack: { step = 0 }) { step = 2 }
        }
        .glassCard(glowColor: .kumaGreen)
    }

    // Step 2: Port
    private var wizardPort: some View {
        VStack(spacing: 8) {
            WizardStepLabel(title: String(localized: "Puerto"))

            Picker("", selection: $selectedPort) {
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
                .foregroundStyle(Color.kumaGreen)

            WizardNavButtons(onBack: { step = 1 }) { step = 3 }
        }
        .glassCard(glowColor: .kumaGreen)
    }

    // Step 3: Slug
    private var wizardSlug: some View {
        VStack(spacing: 8) {
            WizardStepLabel(title: String(localized: "Slug de la página"))

            TextField(String(localized: "slug"), text: $statusPageSlug)
                .autocorrectionDisabled()
                .font(.system(size: 14, design: .monospaced))

            WizardNavButtons(
                disableNext: statusPageSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                onBack: { step = 2 }
            ) {
                step = 4
            }
        }
        .glassCard(glowColor: .kumaGreen)
    }

    // Step 4: Confirm & Connect
    private var wizardConfirm: some View {
        VStack(spacing: 8) {
            WizardStepLabel(title: String(localized: "Confirmar"))

            VStack(alignment: .leading, spacing: 4) {
                wizardSummaryRow(String(localized: "URL"), composedURLString)
                wizardSummaryRow(String(localized: "Slug"), statusPageSlug)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)

            if let error = connectError {
                VStack(spacing: 4) {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appStatusDown)
                        .lineLimit(3)
                    HStack(spacing: 3) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 8))
                        Text(String(localized: "El Watch debe estar en la misma WiFi que el servidor"))
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
            }

            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.35)) { step = 3 }
                } label: {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await connect() }
                } label: {
                    if isConnecting {
                        ProgressView()
                    } else {
                        Text(String(localized: "Conectar"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.kumaGreen)
                .disabled(isConnecting)
            }
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
                .foregroundStyle(Color.kumaGreenLight)
        }
    }

    private var octetDotView: some View {
        Text(".")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.kumaGreen)
    }

    private var composedURLString: String {
        "\(selectedProtocol)://\(ipOctet1).\(ipOctet2).\(ipOctet3).\(ipOctet4):\(selectedPort)"
    }

    private func connect() async {
        connectError = nil
        guard let baseURL = ServerConnection.validatedBaseURL(from: composedURLString),
              let slug = ServerConnection.validatedStatusPageSlug(from: statusPageSlug)
        else {
            connectError = String(localized: "URL no válida")
            return
        }

        let name = serverName.isEmpty ? String(localized: "Mi servidor Kuma") : serverName
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
            .foregroundStyle(Color.kumaGreenLight)
            .textCase(.uppercase)
    }
}

private struct WizardNavButtons: View {
    var showBack: Bool = true
    var disableNext: Bool = false
    let onBack: (() -> Void)?
    let onNext: () -> Void

    init(
        showBack: Bool = true,
        disableNext: Bool = false,
        onBack: (() -> Void)? = nil,
        onNext: @escaping () -> Void
    ) {
        self.showBack = showBack
        self.disableNext = disableNext
        self.onBack = onBack
        self.onNext = onNext
    }

    var body: some View {
        HStack(spacing: 32) {
            if showBack, let onBack {
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        onBack()
                    }
                } label: {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation(.spring(response: 0.35)) {
                    onNext()
                }
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.kumaGreen)
            }
            .buttonStyle(.plain)
            .disabled(disableNext)
            .opacity(disableNext ? 0.4 : 1)
        }
    }
}

// MARK: - Octet Button (tap to edit in dedicated sheet)

private struct OctetButton: View {
    @Binding var value: Int
    @State private var isEditing = false

    var body: some View {
        Button {
            isEditing = true
        } label: {
            Text(String(value))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(minWidth: 32, minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.kumaGreen.opacity(0.3), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isEditing) {
            OctetPickerSheet(value: $value)
        }
    }
}

private struct OctetPickerSheet: View {
    @Binding var value: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            Text(String(value))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.kumaGreen)

            Picker("", selection: $value) {
                ForEach(0...255, id: \.self) { n in
                    Text(String(n))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .tag(n)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 80)

            Button {
                dismiss()
            } label: {
                Text("OK")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.kumaGreen)
        }
        .padding()
        .background(Color.black)
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
                    settingsTabButton(String(localized: "Red"), systemImage: "network", tab: 1)
                    settingsTabButton(String(localized: "Zona de riesgo"), systemImage: "exclamationmark.triangle", tab: 2)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)

                Group {
                    switch selectedTab {
                    case 0: serverTab
                    case 1: networkTab
                    default: dangerTab
                    }
                }
                .animation(.spring(response: 0.3), value: selectedTab)
            }
            .background(Color.black)
            .navigationTitle(String(localized: "Ajustes"))
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
            .foregroundStyle(selectedTab == tab ? Color.kumaGreen : Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // Tab 0: Server info
    private var serverTab: some View {
        ScrollView {
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Nombre"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kumaGreenLight)
                    TextField(String(localized: "Server"), text: $name)
                        .font(.system(size: 13))
                }
                .glassCard(glowColor: .kumaGreenDim)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Slug de la página"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kumaGreenLight)
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
                    Text(String(localized: "Protocolo"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kumaGreenLight)
                    Picker("", selection: $selectedProtocol) {
                        ForEach(Self.protocols, id: \.self) { proto in
                            Text(proto.uppercased()).tag(proto)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 50)
                }
                .glassCard(glowColor: .kumaGreenDim)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Dirección IP"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kumaGreenLight)
                    HStack(spacing: 3) {
                        OctetButton(value: $ipOctet1)
                        settingsDot
                        OctetButton(value: $ipOctet2)
                        settingsDot
                        OctetButton(value: $ipOctet3)
                        settingsDot
                        OctetButton(value: $ipOctet4)
                    }
                }
                .glassCard(glowColor: .kumaGreenDim)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Puerto"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kumaGreenLight)
                    Picker("", selection: $selectedPort) {
                        ForEach(Self.portRange, id: \.self) { port in
                            Text(String(port)).tag(port)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 50)
                    Text(":\(selectedPort)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.kumaGreen)
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
                Label(String(localized: "Eliminar servidor"), systemImage: "trash")
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
                VStack(spacing: 4) {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appStatusDown)
                        .lineLimit(3)
                    HStack(spacing: 3) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 8))
                        Text(String(localized: "El Watch debe estar en la misma WiFi que el servidor"))
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
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

    private var settingsDot: some View {
        Text(".")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.kumaGreen)
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
            connectError = String(localized: "URL no válida")
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
