import Foundation

enum WidgetDataPresentation {
    static func shouldShowSummary(for data: WidgetData) -> Bool {
        data.overallStatusRaw != "unreachable"
    }

    static func statusColorKey(for overallStatusRaw: String) -> String {
        switch overallStatusRaw {
        case "allUp": "green"
        case "degraded": "yellow"
        case "someDown": "red"
        default: "gray"
        }
    }

    static func statusLabel(for data: WidgetData) -> String {
        switch data.overallStatusRaw {
        case "allUp": String(localized: "All OK")
        case "degraded": String(localized: "Degraded")
        case "someDown": String.localizedStringWithFormat(
            String(localized: "%lld down"),
            Int64(data.downCount)
        )
        default: String(localized: "Offline")
        }
    }
}

enum WidgetTimelineSupport {
    static func readSnapshot(from defaults: UserDefaults?) -> WidgetData? {
        defaults.flatMap { WidgetData.read(from: $0) }
    }

    static func nextRefreshDate(from now: Date) -> Date {
        Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now
    }
}

/// Data structure shared between main app and widget via App Group UserDefaults.
struct WidgetData: Codable {
    static let freshnessReloadInterval: TimeInterval = 300

    let upCount: Int
    let totalCount: Int
    let downCount: Int
    let overallStatusRaw: String
    let lastCheckTime: Date?
    let serverName: String?
    let hasActiveIncident: Bool

    static let userDefaultsKey = "widgetData"

    static func read(from defaults: UserDefaults) -> WidgetData? {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(WidgetData.self, from: data)
    }

    static func clear(from defaults: UserDefaults) {
        defaults.removeObject(forKey: Self.userDefaultsKey)
    }

    func write(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }
    }

    var monitorSummaryLine: String {
        Self.monitorSummaryLine(upCount: upCount, totalCount: totalCount)
    }

    static func monitorSummaryLine(upCount: Int, totalCount: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "%lld up / %lld total"),
            Int64(upCount),
            Int64(totalCount)
        )
    }

    var reloadSignature: String {
        [
            String(upCount),
            String(totalCount),
            String(downCount),
            overallStatusRaw,
            serverName ?? "",
            hasActiveIncident ? "1" : "0",
            lastCheckTime.map {
                String(Int($0.timeIntervalSince1970 / Self.freshnessReloadInterval))
            } ?? ""
        ].joined(separator: "|")
    }
}
