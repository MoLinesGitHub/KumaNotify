import Foundation

struct ServerConnection: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var provider: MonitoringProvider
    var baseURL: URL
    var statusPageSlug: String
    var isDefault: Bool

    var statusPageURL: URL {
        baseURL.appending(path: "api/status-page/\(statusPageSlug)")
    }

    var heartbeatURL: URL {
        baseURL.appending(path: "api/status-page/heartbeat/\(statusPageSlug)")
    }

    init(
        id: UUID = UUID(),
        name: String,
        provider: MonitoringProvider = .uptimeKuma,
        baseURL: URL,
        statusPageSlug: String,
        isDefault: Bool = true
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.baseURL = baseURL
        self.statusPageSlug = statusPageSlug
        self.isDefault = isDefault
    }
}
