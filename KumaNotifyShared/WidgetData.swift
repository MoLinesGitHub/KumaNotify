import Foundation

/// Data structure shared between main app and widget via App Group UserDefaults.
struct WidgetData: Codable {
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

    func write(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }
    }
}
