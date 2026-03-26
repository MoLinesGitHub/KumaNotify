import Foundation

struct UnifiedMonitor: MonitorRepresentable, Hashable {
    let id: String
    let name: String
    let type: String
    var currentStatus: MonitorStatus
    var latestPing: Int?
    var uptime24h: Double?
    var uptime7d: Double?
    var uptime30d: Double?
    var certExpiryDays: Int?
    var validCert: Bool?
    var url: URL?
    var lastStatusChange: Date?

    static func == (lhs: UnifiedMonitor, rhs: UnifiedMonitor) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct UnifiedGroup: MonitorGroupRepresentable {
    let id: String
    let name: String
    let weight: Int
    let monitors: [UnifiedMonitor]
}

struct UnifiedHeartbeat: HeartbeatRepresentable {
    let status: MonitorStatus
    let time: Date
    let message: String
    let ping: Int?
}

struct UnifiedMaintenance: Sendable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let startDate: Date?
    let endDate: Date?
}

struct StatusPageResult: Sendable {
    let title: String
    let groups: [UnifiedGroup]
    let incidents: [UKIncident]
    let maintenances: [UnifiedMaintenance]
    let showCertExpiry: Bool
}

struct HeartbeatResult: Sendable {
    let heartbeats: [String: [UnifiedHeartbeat]]
    let uptimes: [String: Double]
}
