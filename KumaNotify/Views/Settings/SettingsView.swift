import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore
    var storeManager: StoreManager?
    var onSave: (() -> Void)?

    @State private var editingConnection: ServerConnection?
    @State private var isAddingNew = false

    private var isPro: Bool { storeManager?.proUnlocked ?? false }

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
                    Text("Pro unlocks polling from \(Int(AppConstants.minimumPollingPro))s")
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
                    set: { settingsStore.notificationsEnabled = $0 }
                ))

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
                        NotificationManager.shared.sendTestNotification(
                            soundOption: settingsStore.notificationSound
                        )
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

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Server" : "Add Server")
                .font(.headline)

            Form {
                TextField("Server URL", text: $serverURL, prompt: Text("http://192.168.1.100:3001"))
                    .textFieldStyle(.roundedBorder)
                TextField("Status Page Slug", text: $slug, prompt: Text("e.g. cortes"))
                    .textFieldStyle(.roundedBorder)
                TextField("Display Name", text: $serverName, prompt: Text("My Kuma Server"))
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Test Connection") {
                    Task { await testConnection() }
                }
                .disabled(serverURL.isEmpty || slug.isEmpty || isTesting)

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

                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(serverURL.isEmpty || slug.isEmpty)
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
        guard let url = URL(string: serverURL) else { return }
        let conn = ServerConnection(
            id: connection?.id ?? UUID(),
            name: serverName.isEmpty ? String(localized: "My Kuma Server") : serverName,
            baseURL: url,
            statusPageSlug: slug,
            isDefault: connection?.isDefault ?? false
        )
        onSave(conn)
    }

    private func testConnection() async {
        guard let url = URL(string: serverURL) else {
            testResult = (false, "Invalid URL")
            return
        }
        let conn = ServerConnection(
            name: serverName,
            baseURL: url,
            statusPageSlug: slug
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
