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

    static func normalizedDisplayName(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return String(localized: "My Kuma Server")
        }
        return trimmed
    }

    static func validatedBaseURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty
        else {
            return nil
        }

        return components.url
    }
}
