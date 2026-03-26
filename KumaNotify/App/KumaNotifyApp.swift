import SwiftUI
import SwiftData
import os

@main
struct KumaNotifyApp: App {
    @State private var settingsStore: SettingsStore
    @State private var pollingEngine: PollingEngine
    @State private var persistence: PersistenceManager?

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
                    Text("Kuma Notify")
                        .font(.headline)
                    Text("Configure a server in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Setup Wizard...") {
                        showOnboarding = true
                    }
                    SettingsLink {
                        Text("Open Settings...")
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

        Window("Welcome to Kuma Notify", id: "onboarding") {
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
        let engine = PollingEngine()
        _settingsStore = State(initialValue: store)
        _pollingEngine = State(initialValue: engine)

        do {
            let pm = try PersistenceManager()
            _persistence = State(initialValue: pm)
        } catch {
            Logger.app.error("PersistenceManager failed to initialize: \(error.localizedDescription)")
            _persistence = State(initialValue: nil)
        }

        if let connection = store.serverConnection {
            let service = MonitoringServiceFactory.create(for: connection.provider)
            _menuBarVM = State(initialValue: MenuBarViewModel(
                service: service,
                settingsStore: store,
                pollingEngine: engine,
                persistence: _persistence.wrappedValue
            ))
            _dashboardVM = State(initialValue: DashboardViewModel(
                service: service,
                settingsStore: store,
                persistence: _persistence.wrappedValue
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
            pollingEngine: pollingEngine,
            persistence: persistence
        )
        let dbVM = DashboardViewModel(
            service: service,
            settingsStore: settingsStore,
            persistence: persistence
        )

        menuBarVM = mbVM
        dashboardVM = dbVM

        persistence?.purgeOldIncidents()

        Task {
            let granted = await NotificationManager.shared.requestPermission()
            if !granted {
                Logger.app.warning("Notification permission not granted")
            }
        }

        mbVM.startPolling()
    }
}
