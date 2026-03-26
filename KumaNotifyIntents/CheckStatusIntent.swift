import AppIntents

struct CheckStatusIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Check Monitor Status"
    nonisolated static let description: IntentDescription = "Returns the current status of your monitored services."
    nonisolated static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.molinesdesigns.kuma-notify")
        guard let defaults, let data = WidgetData.read(from: defaults) else {
            return .result(value: "No data", dialog: "Kuma Notify has no status data. Open the app first.")
        }

        let status: String
        switch data.overallStatusRaw {
        case "allUp": status = "All systems operational"
        case "degraded": status = "Degraded performance"
        case "someDown": status = "\(data.downCount) monitors down"
        default: status = "Server unreachable"
        }

        let summary = "\(data.upCount)/\(data.totalCount) OK — \(status)"
        return .result(value: summary, dialog: "\(summary)")
    }
}

struct GetMonitorCountIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Get Monitor Count"
    nonisolated static let description: IntentDescription = "Returns how many monitors are up and total."
    nonisolated static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let defaults = UserDefaults(suiteName: "group.com.molinesdesigns.kuma-notify")
        guard let defaults, let data = WidgetData.read(from: defaults) else {
            return .result(value: "No data")
        }
        return .result(value: "\(data.upCount) up, \(data.downCount) down, \(data.totalCount) total")
    }
}

struct KumaNotifyShortcuts: AppShortcutsProvider {
    nonisolated static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckStatusIntent(),
            phrases: [
                "Check \(.applicationName) status",
                "How are my monitors in \(.applicationName)?",
                "Are my servers up in \(.applicationName)?"
            ],
            shortTitle: "Check Status",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
    }
}
