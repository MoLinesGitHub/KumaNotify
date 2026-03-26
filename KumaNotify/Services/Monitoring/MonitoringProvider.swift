import Foundation

enum MonitoringProvider: String, Codable, CaseIterable, Sendable, Identifiable {
    case uptimeKuma = "uptime_kuma"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .uptimeKuma: "Uptime Kuma"
        }
    }

    var iconName: String {
        switch self {
        case .uptimeKuma: "heart.circle.fill"
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .uptimeKuma: false
        }
    }
}
