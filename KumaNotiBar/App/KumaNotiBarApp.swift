import SwiftUI

@main
struct KumaNotiBarApp: App {
    @State private var settingsStore = SettingsStore()
    @State private var pollingEngine = PollingEngine()

    @State private var menuBarVM: MenuBarViewModel?
    @State private var dashboardVM: DashboardViewModel?
    @State private var showOnboarding = false

    var body: some Scene {
        MenuBarExtra {
            if let menuBarVM, let dashboardVM {
                DashboardView(
                    menuBarVM: menuBarVM,
                    dashboardVM: dashboardVM
                )
            } else {
                VStack(spacing: 12) {
                    Text("Kuma NotiBar")
                        .font(.headline)
                    Text("Configure a server in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Setup Wizard...") {
                        showOnboarding = true
                    }
                    Button("Open Settings...") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                    Divider()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                }
                .padding()
                .frame(width: 240)
            }
        } label: {
            if let menuBarVM {
                MenuBarLabel(viewModel: menuBarVM)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(.gray)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settingsStore: settingsStore) {
                setupViewModels()
            }
        }

        Window("Welcome to Kuma NotiBar", id: "onboarding") {
            OnboardingView(settingsStore: settingsStore) {
                showOnboarding = false
                setupViewModels()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    init() {
        let store = SettingsStore()
        _settingsStore = State(initialValue: store)
        _pollingEngine = State(initialValue: PollingEngine())

        if store.serverConnection != nil {
            let service = MonitoringServiceFactory.create(for: store.serverConnection!.provider)
            let engine = PollingEngine()
            _pollingEngine = State(initialValue: engine)
            _menuBarVM = State(initialValue: MenuBarViewModel(
                service: service,
                settingsStore: store,
                pollingEngine: engine
            ))
            _dashboardVM = State(initialValue: DashboardViewModel(
                service: service,
                settingsStore: store
            ))
        } else {
            _showOnboarding = State(initialValue: !store.hasCompletedOnboarding)
        }
    }

    private func setupViewModels() {
        guard let connection = settingsStore.serverConnection else { return }
        let service = MonitoringServiceFactory.create(for: connection.provider)

        let mbVM = MenuBarViewModel(
            service: service,
            settingsStore: settingsStore,
            pollingEngine: pollingEngine
        )
        let dbVM = DashboardViewModel(
            service: service,
            settingsStore: settingsStore
        )

        menuBarVM = mbVM
        dashboardVM = dbVM

        Task {
            _ = await NotificationManager.shared.requestPermission()
        }

        mbVM.startPolling()
    }
}
