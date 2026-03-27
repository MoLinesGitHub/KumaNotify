import Foundation

enum WatchWidgetState {
    case healthy
    case degraded
    case down
    case incident
    case offline
}

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

    static func watchWidgetState(for data: WidgetData) -> WatchWidgetState {
        if data.overallStatusRaw == "someDown" {
            return .down
        }
        if data.activeIncidentCount > 0 {
            return .incident
        }
        if data.overallStatusRaw == "degraded" {
            return .degraded
        }
        if data.overallStatusRaw == "allUp" {
            return .healthy
        }
        return .offline
    }

    static func watchCount(for data: WidgetData) -> Int {
        switch watchWidgetState(for: data) {
        case .down:
            return data.downCount
        case .incident:
            if data.activeIncidentCount > 0 {
                return data.activeIncidentCount
            }
            return data.hasActiveIncident ? 1 : 0
        default:
            return 0
        }
    }

    static func watchStatusLabel(for data: WidgetData) -> String {
        switch watchWidgetState(for: data) {
        case .down:
            return statusLabel(for: data)
        case .incident:
            return String.localizedStringWithFormat(
                String(localized: "%lld incidents"),
                Int64(watchCount(for: data))
            )
        case .degraded, .healthy, .offline:
            return statusLabel(for: data)
        }
    }

    static func watchStatusColorKey(for data: WidgetData) -> String {
        switch watchWidgetState(for: data) {
        case .healthy:
            return "green"
        case .degraded:
            return "yellow"
        case .down, .incident:
            return "red"
        case .offline:
            return "gray"
        }
    }

    static func watchSymbolName(for data: WidgetData) -> String {
        switch watchWidgetState(for: data) {
        case .healthy:
            return "checkmark"
        case .degraded:
            return "exclamationmark.circle.fill"
        case .down:
            return "exclamationmark.triangle.fill"
        case .incident:
            return "number.circle.fill"
        case .offline:
            return "antenna.radiowaves.left.and.right.slash"
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
