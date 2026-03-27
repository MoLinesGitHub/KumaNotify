import AppIntents

struct CheckStatusIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Check Monitor Status"
    nonisolated static let description: IntentDescription = "Returns the current status of your monitored services."
    nonisolated static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupId)
        let payload = IntentStatusFormatter.statusSummary(for: defaults.flatMap { WidgetData.read(from: $0) })
        return .result(value: payload.value, dialog: IntentDialog(stringLiteral: payload.dialog))
    }
}

struct GetMonitorCountIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Get Monitor Count"
    nonisolated static let description: IntentDescription = "Returns how many monitors are up and total."
    nonisolated static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupId)
        return .result(value: IntentStatusFormatter.monitorCountSummary(for: defaults.flatMap { WidgetData.read(from: $0) }))
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

enum IntentStatusFormatter {
    static func statusSummary(for data: WidgetData?) -> (value: String, dialog: String) {
        guard let data else {
            let noData = String(localized: "No data")
            let prompt = String(localized: "Open Kuma Notify to start monitoring")
            return (value: noData, dialog: prompt)
        }

        let status: String
        switch data.overallStatusRaw {
        case "allUp":
            status = OverallStatus.allUp.label
        case "degraded":
            status = String(localized: "Degraded performance")
        case "someDown":
            status = OverallStatus.someDown(count: data.downCount, total: data.totalCount).label
        default:
            status = OverallStatus.unreachable.label
        }

        if data.overallStatusRaw == "unreachable" {
            return (value: status, dialog: status)
        }

        let summary = String.localizedStringWithFormat(
            String(localized: "%@ — %@"),
            data.monitorSummaryLine,
            status
        )
        return (value: summary, dialog: summary)
    }

    static func monitorCountSummary(for data: WidgetData?) -> String {
        guard let data else {
            return String(localized: "No data")
        }

        if data.overallStatusRaw == "unreachable" {
            return OverallStatus.unreachable.label
        }

        return String.localizedStringWithFormat(
            String(localized: "%lld up, %lld down, %lld total"),
            Int64(data.upCount),
            Int64(data.downCount),
            Int64(data.totalCount)
        )
    }
}
