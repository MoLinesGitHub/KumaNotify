import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore
    var storeManager: StoreManager?
    var onSave: (() -> Void)?

    @State private var editingConnection: ServerConnection?
    @State private var isAddingNew = false
    @State private var showNotificationSettingsHelp = false

    private var isPro: Bool {
        #if DEBUG
        storeManager?.effectiveProUnlocked ?? false
        #else
        storeManager?.proUnlocked ?? false
        #endif
    }

    var body: some View {
        TabView {
            serverTab
                .tabItem { Label("Server", systemImage: "server.rack") }
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 440, height: 380)
        .task {
            await refreshNotificationAuthorizationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { @MainActor in
                await refreshNotificationAuthorizationStatus()
            }
        }
        .sheet(item: $editingConnection) { connection in
            ServerFormView(
                connection: connection,
                onSave: { updated in
                    settingsStore.updateConnection(updated)
                    editingConnection = nil
                    onSave?()
                },
                onCancel: { editingConnection = nil }
            )
        }
        .sheet(isPresented: $isAddingNew) {
            ServerFormView(
                connection: nil,
                onSave: { newConn in
                    settingsStore.addConnection(newConn)
                    isAddingNew = false
                    onSave?()
                },
                onCancel: { isAddingNew = false }
            )
        }
        .alert(String(localized: "Notifications Disabled in System Settings"), isPresented: $showNotificationSettingsHelp) {
            Button(String(localized: "Open System Settings")) {
                NotificationManager.shared.openSystemNotificationSettings()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("Allow notifications for Kuma Notify in System Settings, then enable them again here.")
        }
    }

    @MainActor
    private func refreshNotificationAuthorizationStatus() async {
        settingsStore.notificationAuthorizationStatus = await NotificationManager.shared.notificationAuthorizationStatus()
    }

    // MARK: - Server Tab

    private var serverTab: some View {
        Form {
            Section("Servers") {
                if settingsStore.serverConnections.isEmpty {
                    Text("No servers configured")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(settingsStore.serverConnections) { conn in
                        serverRow(conn)
                    }
                }
            }

            Section {
                HStack {
                    Button("Add Server") {
                        if !isPro && settingsStore.serverConnections.count >= 1 {
                            // Pro required for 2+ servers — handled by disabled state
                        } else {
                            isAddingNew = true
                        }
                    }
                    .disabled(!isPro && settingsStore.serverConnections.count >= 1)
                    .accessibilityIdentifier("settings.addServerButton")

                    if !isPro && !settingsStore.serverConnections.isEmpty {
                        Text("Pro required for multiple servers")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func serverRow(_ conn: ServerConnection) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(conn.name)
                        .font(.system(.body, weight: .medium))
                    if conn.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                Text(conn.baseURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button("Edit") { editingConnection = conn }
                if !conn.isDefault {
                    Button("Set as Default") {
                        settingsStore.setDefaultConnection(id: conn.id)
                        onSave?()
                    }
                }
                Divider()
                Button("Remove", role: .destructive) {
                    settingsStore.removeConnection(id: conn.id)
                    onSave?()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
        }
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        Form {
            Section("Menu Bar Icon") {
                Picker("Style", selection: Binding(
                    get: { settingsStore.menuBarIconStyle },
                    set: { settingsStore.menuBarIconStyle = $0 }
                )) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - General Tab

    private var minimumPolling: TimeInterval {
        isPro ? AppConstants.minimumPollingPro : AppConstants.minimumPollingBasic
    }

    private var generalTab: some View {
        Form {
            Section("Polling") {
                HStack {
                    Text("Interval")
                    Slider(
                        value: Binding(
                            get: { settingsStore.pollingInterval },
                            set: { settingsStore.pollingInterval = $0 }
                        ),
                        in: minimumPolling...AppConstants.maximumPollingInterval,
                        step: 10
                    )
                    Text("\(Int(settingsStore.pollingInterval))s")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                if !isPro {
                    Text(String(format: String(localized: "Pro unlocks polling from %@s"), "\(Int(AppConstants.minimumPollingPro))"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if isPro {
                    Toggle("Battery saver", isOn: Binding(
                        get: { settingsStore.batterySaverEnabled },
                        set: { settingsStore.batterySaverEnabled = $0 }
                    ))
                    Text("Reduces polling frequency on battery power")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notifications") {
                Toggle("Enable notifications", isOn: Binding(
                    get: { settingsStore.notificationsEnabled },
                    set: { newValue in
                        guard newValue else {
                            settingsStore.notificationsEnabled = false
                            return
                        }

                        Task { @MainActor in
                            switch settingsStore.notificationAuthorizationStatus {
                            case .authorized:
                                settingsStore.notificationsEnabled = true
                            case .notDetermined:
                                let status = await NotificationManager.shared.requestPermission()
                                settingsStore.notificationAuthorizationStatus = status
                                settingsStore.notificationsEnabled = (status == .authorized)
                                showNotificationSettingsHelp = (status == .denied)
                            case .denied:
                                settingsStore.notificationsEnabled = false
                                showNotificationSettingsHelp = true
                            }
                        }
                    }
                ))

                if settingsStore.notificationAuthorizationStatus == .denied {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications are currently blocked by System Settings.")
                                .font(.caption)
                            Button("Open System Settings") {
                                NotificationManager.shared.openSystemNotificationSettings()
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                        Spacer()
                    }
                }

                if isPro {
                    Picker("Sound", selection: Binding(
                        get: { settingsStore.notificationSound },
                        set: { settingsStore.notificationSound = $0 }
                    )) {
                        ForEach(NotificationSoundOption.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    Button("Test Notification") {
                        Task { @MainActor in
                            var status = settingsStore.notificationAuthorizationStatus
                            if status == .notDetermined {
                                status = await NotificationManager.shared.requestPermission()
                                settingsStore.notificationAuthorizationStatus = status
                            }

                            guard status == .authorized else {
                                showNotificationSettingsHelp = (status == .denied)
                                return
                            }

                            settingsStore.notificationsEnabled = true
                            NotificationManager.shared.sendTestNotification(
                                soundOption: settingsStore.notificationSound
                            )
                        }
                    }
                }
            }

            if isPro {
                Section("Do Not Disturb") {
                    if settingsStore.isDndActive {
                        HStack {
                            Label("DND active", systemImage: "moon.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Spacer()
                            Button("Turn Off") {
                                settingsStore.dndUntil = nil
                            }
                        }
                    } else {
                        HStack {
                            ForEach(DndPreset.allCases) { preset in
                                Button(preset.label) {
                                    settingsStore.dndUntil = preset.endDate
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settingsStore.launchAtLogin },
                    set: { settingsStore.launchAtLogin = $0 }
                ))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Server Form (Add / Edit)

struct ServerFormView: View {
    let connection: ServerConnection?
    let onSave: (ServerConnection) -> Void
    let onCancel: () -> Void

    @State private var serverURL: String = ""
    @State private var slug: String = ""
    @State private var serverName: String = ""
    @State private var isTesting = false
    @State private var testResult: (success: Bool, message: String)?

    private var isEditing: Bool { connection != nil }
    private var normalizedSlug: String { ServerConnection.normalizedStatusPageSlug(from: slug) }
    private var normalizedServerName: String { ServerConnection.normalizedDisplayName(from: serverName) }
    private var validatedServerURL: URL? { ServerConnection.validatedBaseURL(from: serverURL) }
    private var validatedSlug: String? { ServerConnection.validatedStatusPageSlug(from: slug) }
    private var canSubmit: Bool { validatedServerURL != nil && validatedSlug != nil }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Server" : "Add Server")
                .font(.headline)

            Form {
                TextField("Server URL", text: $serverURL, prompt: Text("http://192.168.1.100:3001"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("settings.serverURLField")
                TextField("Status Page Slug", text: $slug, prompt: Text("e.g. cortes"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("settings.statusPageSlugField")
                TextField("Display Name", text: $serverName, prompt: Text("My Kuma Server"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("settings.displayNameField")
            }

            HStack {
                Button("Test Connection") {
                    Task { await testConnection() }
                }
                .disabled(!canSubmit || isTesting)
                .accessibilityIdentifier("settings.testConnectionButton")

                if let testResult {
                    Label(
                        testResult.success ? String(localized: "Connected") : String(localized: "Failed"),
                        systemImage: testResult.success ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(testResult.success ? .green : .red)
                    .font(.caption)
                }

                Spacer()

                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("settings.cancelButton")

                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("settings.saveButton")
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            if let connection {
                serverURL = connection.baseURL.absoluteString
                slug = connection.statusPageSlug
                serverName = connection.name
            }
        }
    }

    private func save() {
        guard let url = validatedServerURL, let validatedSlug else { return }
        let conn = ServerConnection(
            id: connection?.id ?? UUID(),
            name: normalizedServerName,
            baseURL: url,
            statusPageSlug: validatedSlug,
            isDefault: connection?.isDefault ?? false
        )
        onSave(conn)
    }

    private func testConnection() async {
        guard let url = validatedServerURL else {
            testResult = (false, String(localized: "Invalid URL"))
            return
        }
        guard let validatedSlug else {
            testResult = (false, String(localized: "Invalid status page slug"))
            return
        }
        let conn = ServerConnection(
            name: normalizedServerName,
            baseURL: url,
            statusPageSlug: validatedSlug
        )
        isTesting = true
        defer { isTesting = false }

        let service = MonitoringServiceFactory.create(for: conn.provider)
        do {
            _ = try await service.validateConnection(conn)
            testResult = (true, String(localized: "Connected"))
        } catch {
            testResult = (false, error.localizedDescription)
        }
    }
}
