import SwiftUI
import SwiftData
import WidgetKit

enum KumaNotifyAppLaunchBehavior: Equatable {
    case restoreMonitoring
    case emptyState(showOnboarding: Bool)

    static func determine(
        hasServerConnection: Bool,
        hasCompletedOnboarding: Bool
    ) -> Self {
        if hasServerConnection {
            return .restoreMonitoring
        }
        return .emptyState(showOnboarding: !hasCompletedOnboarding)
    }
}

@MainActor
@main
struct KumaNotifyApp: App {
    private let uiTestShowsOnboarding: Bool
    private let uiTestShowsSettings: Bool
    private let uiTestShowsPaywall: Bool
    private let uiTestShowsDashboard: Bool
    private let uiTestOpensRestoredDashboard: Bool
    private let uiTestShowsPaywallFromRestoredDashboard: Bool
    private let uiTestSeedsServerConnection: Bool
    private let uiTestForcesPro: Bool
    private let uiTestUsesStubMonitoring: Bool
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
                    .task(id: showOnboarding) {
                        presentOnboardingIfNeeded()
                    }
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
        let settingsSuiteName = environment["KUMA_SETTINGS_SUITE_NAME"]
        self.uiTestShowsOnboarding = environment["KUMA_UI_TEST_SHOW_ONBOARDING"] == "1"
        self.uiTestShowsSettings = environment["KUMA_UI_TEST_SHOW_SETTINGS"] == "1"
        self.uiTestShowsPaywall = environment["KUMA_UI_TEST_SHOW_PAYWALL"] == "1"
        self.uiTestShowsDashboard = environment["KUMA_UI_TEST_SHOW_DASHBOARD"] == "1"
        self.uiTestOpensRestoredDashboard = environment["KUMA_UI_TEST_OPEN_RESTORED_DASHBOARD"] == "1"
        self.uiTestShowsPaywallFromRestoredDashboard = environment["KUMA_UI_TEST_SHOW_PAYWALL_FROM_DASHBOARD"] == "1"
        self.uiTestSeedsServerConnection = environment["KUMA_UI_TEST_SEED_SERVER"] == "1"
        self.uiTestForcesPro = environment["KUMA_UI_TEST_FORCE_PRO"] == "1"
        self.uiTestUsesStubMonitoring = environment["KUMA_UI_TEST_USE_STUB_MONITORING"] == "1"

        let store = SettingsStore(suiteName: settingsSuiteName)
        let engine = PollingEngine()
        let sm = StoreManager()
        #if DEBUG
        if uiTestForcesPro || uiTestShowsSettings || uiTestShowsDashboard {
            sm.debugProOverride = true
        }
        #endif

        if Self.shouldSeedUITestServerConnection(
            uiTestSeedsServerConnection,
            existingConnectionCount: store.serverConnections.count
        ) {
            store.addConnection(ServerConnection(
                name: "Primary",
                baseURL: URL(string: "https://primary.example.com")!,
                statusPageSlug: "primary"
            ))
            store.hasCompletedOnboarding = true
        }

        _settingsStore = State(initialValue: store)
        _pollingEngine = State(initialValue: engine)
        _storeManager = State(initialValue: sm)

        do {
            let pm = try PersistenceManager()
            _persistence = State(initialValue: pm)
        } catch {
            print("App: PersistenceManager failed to initialize: \(error.localizedDescription)")
            _persistence = State(initialValue: nil)
        }

        switch Self.launchBehavior(
            hasServerConnection: store.serverConnection != nil,
            hasCompletedOnboarding: store.hasCompletedOnboarding
        ) {
        case .restoreMonitoring:
            let connection = store.serverConnection!
            let monitoringServiceFactory: (MonitoringProvider) -> any MonitoringServiceProtocol
            if uiTestUsesStubMonitoring {
                let service = UITestDashboardMonitoringService()
                monitoringServiceFactory = { _ in service }
            } else {
                monitoringServiceFactory = MonitoringServiceFactory.create
            }
            let menuBarVM = MenuBarViewModel(
                settingsStore: store,
                pollingEngine: engine,
                serviceFactory: monitoringServiceFactory,
                persistence: _persistence.wrappedValue,
                storeManager: sm
            )
            let dashboardVM = DashboardViewModel(
                connection: connection,
                settingsStore: store,
                persistence: _persistence.wrappedValue,
                serviceFactory: monitoringServiceFactory
            )
            _menuBarVM = State(initialValue: menuBarVM)
            _dashboardVM = State(initialValue: dashboardVM)
            bootstrapMonitoring(menuBarVM)
            if uiTestOpensRestoredDashboard {
                let shouldShowPaywall = uiTestShowsPaywallFromRestoredDashboard
                Task { @MainActor in
                    UITestDashboardWindow.show(
                        menuBarVM: menuBarVM,
                        dashboardVM: dashboardVM,
                        storeManager: sm,
                        settingsStore: store,
                        initialShowPaywall: shouldShowPaywall
                    )
                }
            }
        case .emptyState(let shouldShowOnboarding):
            Self.clearSharedWidgetData()
            _showOnboarding = State(initialValue: shouldShowOnboarding)
        }

        Task { @MainActor in
            store.notificationAuthorizationStatus = await NotificationManager.shared.notificationAuthorizationStatus()
        }

        if uiTestShowsOnboarding {
            Task { @MainActor in
                UITestOnboardingWindow.show(settingsStore: store)
            }
        }
        if uiTestShowsSettings {
            Task { @MainActor in
                UITestSettingsWindow.show(settingsStore: store, storeManager: sm)
            }
        }
        if uiTestShowsPaywall {
            Task { @MainActor in
                UITestPaywallWindow.show(storeManager: sm)
            }
        }
        if uiTestShowsDashboard {
            let primary = ServerConnection(
                name: "Primary",
                baseURL: URL(string: "https://primary.example.com")!,
                statusPageSlug: "primary"
            )
            let secondary = ServerConnection(
                name: "Secondary",
                baseURL: URL(string: "https://secondary.example.com")!,
                statusPageSlug: "secondary",
                isDefault: false
            )
            if store.serverConnections.isEmpty {
                store.addConnection(primary)
                store.addConnection(secondary)
            }
            let service = UITestDashboardMonitoringService()
            let menuBarVM = MenuBarViewModel(
                settingsStore: store,
                pollingEngine: engine,
                serviceFactory: { _ in service },
                shouldStartMonitors: false
            )
            let dashboardVM = DashboardViewModel(
                connection: primary,
                settingsStore: store,
                serviceFactory: { _ in service }
            )
            _menuBarVM = State(initialValue: menuBarVM)
            _dashboardVM = State(initialValue: dashboardVM)
            Task { @MainActor in
                UITestDashboardWindow.show(
                    menuBarVM: menuBarVM,
                    dashboardVM: dashboardVM,
                    storeManager: sm,
                    settingsStore: store
                )
            }
        }
    }

    private func setupViewModels() {
        // Stop old monitors before creating new VMs
        menuBarVM?.stopPolling()

        guard let connection = settingsStore.serverConnection else {
            menuBarVM = nil
            dashboardVM = nil
            Self.clearSharedWidgetData()
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

        bootstrapMonitoring(mbVM)
    }

    private func bootstrapMonitoring(_ menuBarVM: MenuBarViewModel) {
        Task {
            await persistence?.purgeOldIncidents()
        }
        menuBarVM.startPolling()
    }

    private func presentOnboardingIfNeeded() {
        guard Self.shouldPresentOnboarding(
            showOnboarding: showOnboarding,
            uiTestShowsOnboarding: uiTestShowsOnboarding
        ) else { return }
        showOnboarding = false
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "onboarding")
    }

    private static func clearSharedWidgetData() {
        clearSharedWidgetData(
            defaults: UserDefaults(suiteName: AppConstants.appGroupId),
            reloadWidgets: { WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind) }
        )
    }

    nonisolated static func launchBehavior(
        hasServerConnection: Bool,
        hasCompletedOnboarding: Bool
    ) -> KumaNotifyAppLaunchBehavior {
        KumaNotifyAppLaunchBehavior.determine(
            hasServerConnection: hasServerConnection,
            hasCompletedOnboarding: hasCompletedOnboarding
        )
    }

    nonisolated static func shouldSeedUITestServerConnection(
        _ uiTestSeedsServerConnection: Bool,
        existingConnectionCount: Int
    ) -> Bool {
        uiTestSeedsServerConnection && existingConnectionCount == 0
    }

    nonisolated static func shouldPresentOnboarding(
        showOnboarding: Bool,
        uiTestShowsOnboarding: Bool
    ) -> Bool {
        showOnboarding && !uiTestShowsOnboarding
    }

    nonisolated static func clearSharedWidgetData(
        defaults: UserDefaults?,
        reloadWidgets: () -> Void
    ) {
        guard let defaults else { return }
        WidgetData.clear(from: defaults)
        reloadWidgets()
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

@MainActor
private enum UITestSettingsWindow {
    private static var window: NSWindow?

    static func show(settingsStore: SettingsStore, storeManager: StoreManager) {
        let hostingView = NSHostingView(
            rootView: SettingsView(settingsStore: settingsStore, storeManager: storeManager)
                .frame(width: 440, height: 380)
        )

        let window = makeWindow(title: "Settings UI Tests", width: 440, height: 380)
        window.contentView = hostingView
        self.window = window
        present(window)
    }
}

@MainActor
private enum UITestPaywallWindow {
    private static var window: NSWindow?

    static func show(storeManager: StoreManager) {
        let hostingView = NSHostingView(
            rootView: PaywallView(storeManager: storeManager, onDismiss: {})
                .frame(width: 320, height: 320)
        )

        let window = makeWindow(title: "Paywall UI Tests", width: 320, height: 320)
        window.contentView = hostingView
        self.window = window
        present(window)
    }
}

@MainActor
private enum UITestDashboardWindow {
    private static var window: NSWindow?

    static func show(
        menuBarVM: MenuBarViewModel,
        dashboardVM: DashboardViewModel,
        storeManager: StoreManager,
        settingsStore: SettingsStore,
        initialShowPaywall: Bool = false
    ) {
        let hostingView = NSHostingView(
            rootView: DashboardView(
                menuBarVM: menuBarVM,
                dashboardVM: dashboardVM,
                storeManager: storeManager,
                settingsStore: settingsStore,
                persistence: nil,
                initialShowPaywall: initialShowPaywall
            )
            .frame(width: 380, height: 520)
        )

        let window = makeWindow(title: "Dashboard UI Tests", width: 380, height: 520)
        window.contentView = hostingView
        self.window = window
        present(window)
    }
}

@MainActor
private func makeWindow(title: String, width: CGFloat, height: CGFloat) -> NSWindow {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.title = title
    window.center()
    window.isReleasedWhenClosed = false
    return window
}

@MainActor
private func present(_ window: NSWindow) {
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}

private struct UITestDashboardMonitoringService: MonitoringServiceProtocol {
    func fetchStatusPage(connection: ServerConnection) async throws -> StatusPageResult {
        StatusPageResult(
            title: connection.name,
            groups: [
                UnifiedGroup(
                    id: "group-\(connection.statusPageSlug)",
                    name: connection.name,
                    weight: 0,
                    monitors: [
                        UnifiedMonitor(
                            id: "\(connection.statusPageSlug)-api",
                            name: "\(connection.name) API",
                            type: "http",
                            currentStatus: connection.statusPageSlug == "secondary" ? .down : .up,
                            latestPing: connection.statusPageSlug == "secondary" ? 180 : 60,
                            uptime24h: connection.statusPageSlug == "secondary" ? 0.97 : 1.0,
                            uptime7d: connection.statusPageSlug == "secondary" ? 0.97 : 1.0,
                            uptime30d: connection.statusPageSlug == "secondary" ? 0.97 : 1.0,
                            certExpiryDays: nil,
                            validCert: nil,
                            url: nil,
                            lastStatusChange: nil
                        ),
                        UnifiedMonitor(
                            id: "\(connection.statusPageSlug)-db",
                            name: "\(connection.name) DB",
                            type: "tcp",
                            currentStatus: .pending,
                            latestPing: 95,
                            uptime24h: 0.995,
                            uptime7d: 0.995,
                            uptime30d: 0.995,
                            certExpiryDays: nil,
                            validCert: nil,
                            url: nil,
                            lastStatusChange: nil
                        )
                    ]
                )
            ],
            heartbeats: [:],
            incidents: [],
            maintenances: [],
            showCertExpiry: false
        )
    }

    func fetchHeartbeats(connection: ServerConnection) async throws -> HeartbeatResult {
        HeartbeatResult(heartbeats: [:], uptimes: [:])
    }

    func validateConnection(_ connection: ServerConnection) async throws -> Bool {
        true
    }
}
