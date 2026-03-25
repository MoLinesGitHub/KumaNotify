import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore
    var onSave: (() -> Void)?

    var body: some View {
        TabView {
            serverTab
                .tabItem { Label("Server", systemImage: "server.rack") }
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 420, height: 320)
    }

    // MARK: - Server Tab

    private var serverTab: some View {
        Form {
            Section("Connection") {
                TextField("Server URL", text: serverURLBinding)
                    .textFieldStyle(.roundedBorder)
                TextField("Status Page Slug", text: slugBinding)
                    .textFieldStyle(.roundedBorder)
                TextField("Display Name", text: nameBinding)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                Button("Test Connection") {
                    // TODO: Phase 2
                }
                .disabled(serverURLBinding.wrappedValue.isEmpty)
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

    // MARK: - Bindings

    private var serverURLBinding: Binding<String> {
        Binding(
            get: { settingsStore.serverConnection?.baseURL.absoluteString ?? "" },
            set: { newValue in
                updateServerConnection { conn in
                    if let url = URL(string: newValue) {
                        conn.baseURL = url
                    }
                }
            }
        )
    }

    private var slugBinding: Binding<String> {
        Binding(
            get: { settingsStore.serverConnection?.statusPageSlug ?? "" },
            set: { newValue in
                updateServerConnection { conn in
                    conn.statusPageSlug = newValue
                }
            }
        )
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { settingsStore.serverConnection?.name ?? "" },
            set: { newValue in
                updateServerConnection { conn in
                    conn.name = newValue
                }
            }
        )
    }

    private func updateServerConnection(_ update: (inout ServerConnection) -> Void) {
        var conn = settingsStore.serverConnection ?? ServerConnection(
            name: "",
            baseURL: URL(string: "http://localhost:3025")!,
            statusPageSlug: ""
        )
        update(&conn)
        settingsStore.serverConnection = conn
    }
}
