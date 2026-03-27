import SwiftUI
import SwiftData
import os

@MainActor
@main
struct KumaNotifyApp: App {
    private let uiTestShowsOnboarding: Bool
    @State private var settingsStore: SettingsStore
    @State private var pollingEngine: PollingEngine
    @State private var persistence: PersistenceManager?
    @State private var storeManager: StoreManager

    @State private var menuBarVM: MenuBarViewModel?
    @State private var dashboardVM: DashboardViewModel?
    @State private var showOnboarding = false
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        menuBarScene
        settingsScene
        onboardingScene
    }

    @SceneBuilder
    private var menuBarScene: some Scene {
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
    }

    @SceneBuilder
    private var settingsScene: some Scene {
        Settings {
            SettingsView(settingsStore: settingsStore, storeManager: storeManager) {
                setupViewModels()
            }
        }
    }

    @SceneBuilder
    private var onboardingScene: some Scene {
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
        let environment = ProcessInfo.processInfo.environment
        let settingsSuiteName = environment["KUMA_SETTINGS_SUITE_NAME"] ?? AppConstants.appGroupId
        self.uiTestShowsOnboarding = environment["KUMA_UI_TEST_SHOW_ONBOARDING"] == "1"

        let store = SettingsStore(suiteName: settingsSuiteName)
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

        if uiTestShowsOnboarding {
            Task { @MainActor in
                UITestOnboardingWindow.show(settingsStore: store)
            }
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

@MainActor
private enum UITestOnboardingWindow {
    private static var window: NSWindow?

    static func show(settingsStore: SettingsStore) {
        let hostingView = NSHostingView(
            rootView: OnboardingView(settingsStore: settingsStore) { }
                .frame(width: 440, height: 360)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Onboarding UI Tests"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
