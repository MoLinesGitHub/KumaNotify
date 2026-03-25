import Foundation

enum APIError: LocalizedError, Sendable {
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int)
    case decodingError(Error)
    case timeout
    case serverUnreachable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        case .httpError(let code):
            "HTTP error: \(code)"
        case .decodingError(let error):
            "Decoding error: \(error.localizedDescription)"
        case .timeout:
            "Request timed out"
        case .serverUnreachable:
            "Server unreachable"
        }
    }
}
