import SwiftUI

@main
struct KumaNotifyWatchApp: App {
    @State private var configurationStore = WatchConfigurationStore()
    @State private var viewModel = WatchDashboardViewModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView(
                configurationStore: configurationStore,
                viewModel: viewModel
            )
        }
    }
}
