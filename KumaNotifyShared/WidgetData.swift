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

    static func criticalEventCount(for data: WidgetData) -> Int {
        if data.downCount > 0 {
            return data.downCount
        }
        if data.activeIncidentCount > 0 {
            return data.activeIncidentCount
        }
        return data.hasActiveIncident ? 1 : 0
    }

    static func watchStatusLabel(for data: WidgetData) -> String {
        if data.overallStatusRaw == "someDown" {
            return statusLabel(for: data)
        }

        let incidentCount = criticalEventCount(for: data)
        if data.hasActiveIncident && incidentCount > 0 {
            return String.localizedStringWithFormat(
                String(localized: "%lld incidents"),
                Int64(incidentCount)
            )
        }

        return statusLabel(for: data)
    }

    static func watchStatusColorKey(for data: WidgetData) -> String {
        if data.overallStatusRaw == "someDown" || data.hasActiveIncident {
            return "red"
        }
        return statusColorKey(for: data.overallStatusRaw)
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
    let activeIncidentCount: Int

    static let userDefaultsKey = "widgetData"

    init(
        upCount: Int,
        totalCount: Int,
        downCount: Int,
        overallStatusRaw: String,
        lastCheckTime: Date?,
        serverName: String?,
        hasActiveIncident: Bool,
        activeIncidentCount: Int = 0
    ) {
        self.upCount = upCount
        self.totalCount = totalCount
        self.downCount = downCount
        self.overallStatusRaw = overallStatusRaw
        self.lastCheckTime = lastCheckTime
        self.serverName = serverName
        self.hasActiveIncident = hasActiveIncident
        self.activeIncidentCount = activeIncidentCount
    }

    private enum CodingKeys: String, CodingKey {
        case upCount
        case totalCount
        case downCount
        case overallStatusRaw
        case lastCheckTime
        case serverName
        case hasActiveIncident
        case activeIncidentCount
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        upCount = try container.decode(Int.self, forKey: .upCount)
        totalCount = try container.decode(Int.self, forKey: .totalCount)
        downCount = try container.decode(Int.self, forKey: .downCount)
        overallStatusRaw = try container.decode(String.self, forKey: .overallStatusRaw)
        lastCheckTime = try container.decodeIfPresent(Date.self, forKey: .lastCheckTime)
        serverName = try container.decodeIfPresent(String.self, forKey: .serverName)
        hasActiveIncident = try container.decode(Bool.self, forKey: .hasActiveIncident)
        activeIncidentCount = try container.decodeIfPresent(Int.self, forKey: .activeIncidentCount) ?? 0
    }

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
            String(activeIncidentCount),
            lastCheckTime.map {
                String(Int($0.timeIntervalSince1970 / Self.freshnessReloadInterval))
            } ?? ""
        ].joined(separator: "|")
    }
}
