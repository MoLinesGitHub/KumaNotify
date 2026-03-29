import Foundation

enum APIError: LocalizedError, Sendable {
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int)
    case decodingError(Error)
    case timeout
    case serverUnreachable
    case privateRelayBlocked

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(localized: "Invalid URL")
        case .networkError(let error):
            String(format: String(localized: "Network error: %@"), error.localizedDescription)
        case .httpError(let code):
            String(format: String(localized: "HTTP error: %lld"), Int64(code))
        case .decodingError(let error):
            String(format: String(localized: "Decoding error: %@"), error.localizedDescription)
        case .timeout:
            String(localized: "Request timed out")
        case .serverUnreachable:
            String(localized: "Server unreachable")
        case .privateRelayBlocked:
            String(localized: "iCloud Private Relay is blocking local network access. Disable it in System Settings → iCloud → Private Relay.")
        }
    }
}
