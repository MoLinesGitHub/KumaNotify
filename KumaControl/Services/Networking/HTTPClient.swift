import Foundation

protocol HTTPClientProtocol: Sendable {
    func get<T: Decodable & Sendable>(url: URL) async throws -> T
}

final class HTTPClient: HTTPClientProtocol, Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        // Bypass iCloud Private Relay / proxy for local network connections
        config.connectionProxyDictionary = [:]
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    func get<T: Decodable & Sendable>(url: URL) async throws -> T {
        let request = URLRequest(url: url)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if let mappedError = Self.apiError(for: error) {
                throw mappedError
            }
            throw APIError.networkError(error)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverUnreachable
        }

        // Detect Private Relay proxy blocking local network (returns 503)
        if httpResponse.statusCode == 503,
           let requestHost = request.url?.host(),
           Self.isPrivateLANHost(requestHost) {
            throw APIError.privateRelayBlocked
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private static func isPrivateLANHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".local") {
            return true
        }

        let octets = host.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4 else { return false }

        switch (octets[0], octets[1]) {
        case (10, _):
            return true
        case (192, 168):
            return true
        case (172, 16...31):
            return true
        default:
            return false
        }
    }

    static func apiError(for error: URLError) -> APIError? {
        if isPrivateRelayHost(error.failingURL?.host()) {
            return .privateRelayBlocked
        }

        switch error.code {
        case .timedOut:
            return .timeout
        case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
            return .serverUnreachable
        default:
            return nil
        }
    }

    private static func isPrivateRelayHost(_ host: String?) -> Bool {
        guard let host else { return false }
        let normalizedHost = host.lowercased()
        return normalizedHost.contains("icloud") || normalizedHost.contains("mask")
    }
}
