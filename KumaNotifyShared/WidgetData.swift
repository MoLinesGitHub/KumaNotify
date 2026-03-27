import Foundation

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
