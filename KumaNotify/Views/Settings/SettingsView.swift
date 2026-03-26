import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore
    var onSave: (() -> Void)?

    @State private var serverURL: String = ""
    @State private var slug: String = ""
    @State private var serverName: String = ""
    @State private var isTesting = false
    @State private var testResult: (success: Bool, message: String)?
    @State private var didLoad = false

    var body: some View {
        TabView {
            serverTab
                .tabItem { Label("Server", systemImage: "server.rack") }
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 420, height: 340)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let conn = settingsStore.serverConnection {
                serverURL = conn.baseURL.absoluteString
                slug = conn.statusPageSlug
                serverName = conn.name
            }
        }
    }

    // MARK: - Server Tab

    private var serverTab: some View {
        Form {
            Section("Connection") {
                TextField("Server URL", text: $serverURL, prompt: Text("http://192.168.1.100:3001"))
                    .textFieldStyle(.roundedBorder)
                TextField("Status Page Slug", text: $slug, prompt: Text("e.g. cortes"))
                    .textFieldStyle(.roundedBorder)
                TextField("Display Name", text: $serverName, prompt: Text("My Server"))
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                HStack {
                    Button("Test Connection") {
                        Task { await testConnection() }
                    }
                    .disabled(serverURL.isEmpty || slug.isEmpty || isTesting)

                    if let testResult {
                        Label(
                            testResult.success ? "Connected" : "Failed",
                            systemImage: testResult.success ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundStyle(testResult.success ? .green : .red)
                        .font(.caption)
                    }

                    Spacer()

                    Button("Save & Connect") {
                        saveConnection()
                        onSave?()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(serverURL.isEmpty || slug.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
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
                        in: 60...300,
                        step: 10
                    )
                    Text("\(Int(settingsStore.pollingInterval))s")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }

            Section("Notifications") {
                Toggle("Enable notifications", isOn: Binding(
                    get: { settingsStore.notificationsEnabled },
                    set: { settingsStore.notificationsEnabled = $0 }
                ))
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Actions

    private func saveConnection() {
        guard let url = URL(string: serverURL) else { return }
        settingsStore.serverConnection = ServerConnection(
            name: serverName.isEmpty ? "Server" : serverName,
            baseURL: url,
            statusPageSlug: slug
        )
    }

    private func testConnection() async {
        saveConnection()
        guard let connection = settingsStore.serverConnection else {
            testResult = (false, "Invalid URL")
            return
        }
        isTesting = true
        defer { isTesting = false }

        let service = UptimeKumaService()
        do {
            _ = try await service.validateConnection(connection)
            testResult = (true, "Connected")
        } catch {
            testResult = (false, error.localizedDescription)
        }
    }
}
