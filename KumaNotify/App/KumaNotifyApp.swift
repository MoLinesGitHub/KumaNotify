import SwiftUI
import SwiftData
import os

@main
struct KumaNotifyApp: App {
    @State private var settingsStore: SettingsStore
    @State private var pollingEngine: PollingEngine
    @State private var persistence: PersistenceManager?
    @State private var storeManager: StoreManager

    @State private var menuBarVM: MenuBarViewModel?
    @State private var dashboardVM: DashboardViewModel?
    @State private var showOnboarding = false
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            if let menuBarVM, let dashboardVM {
                DashboardView(
                    menuBarVM: menuBarVM,
                    dashboardVM: dashboardVM,
                    storeManager: storeManager,
                    settingsStore: settingsStore,
                    persistence: persistence
                )
            } else {
                EmptyStateView(
                    onOpenWizard: {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "onboarding")
                    },
                    onQuit: {
                        NSApplication.shared.terminate(nil)
                    }
                )
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
        .onChange(of: storeManager.proUnlocked) {
            menuBarVM?.refreshPollingInterval()
        }
        .onChange(of: settingsStore.pollingInterval) {
            menuBarVM?.refreshPollingInterval()
        }

        Settings {
            SettingsView(settingsStore: settingsStore, storeManager: storeManager) {
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
        let store = SettingsStore(suiteName: AppConstants.appGroupId)
        let engine = PollingEngine()
        let sm = StoreManager()
        _settingsStore = State(initialValue: store)
        _pollingEngine = State(initialValue: engine)
        _storeManager = State(initialValue: sm)

        do {
            let pm = try PersistenceManager()
            _persistence = State(initialValue: pm)
        } catch {
            Logger.app.error("PersistenceManager failed to initialize: \(error.localizedDescription)")
            _persistence = State(initialValue: nil)
        }

        if let connection = store.serverConnection {
            _menuBarVM = State(initialValue: MenuBarViewModel(
                settingsStore: store,
                pollingEngine: engine,
                persistence: _persistence.wrappedValue,
                storeManager: sm
            ))
            _dashboardVM = State(initialValue: DashboardViewModel(
                connection: connection,
                settingsStore: store,
                persistence: _persistence.wrappedValue
            ))
        } else {
            _showOnboarding = State(initialValue: !store.hasCompletedOnboarding)
        }
    }

    private func setupViewModels() {
        // Stop old monitors before creating new VMs
        menuBarVM?.stopPolling()

        guard let connection = settingsStore.serverConnection else {
            menuBarVM = nil
            dashboardVM = nil
            return
        }

        let mbVM = MenuBarViewModel(
            settingsStore: settingsStore,
            pollingEngine: pollingEngine,
            persistence: persistence,
            storeManager: storeManager
        )
        let dbVM = DashboardViewModel(
            connection: connection,
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
