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
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch let error as URLError where error.code == .cannotConnectToHost
            || error.code == .networkConnectionLost
            || error.code == .notConnectedToInternet {
            throw APIError.serverUnreachable
        } catch let error as URLError where error.failingURL?.host()?.contains("icloud") == true
            || error.failingURL?.host()?.contains("mask") == true {
            throw APIError.privateRelayBlocked
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverUnreachable
        }

        // Detect Private Relay proxy blocking local network (returns 503)
        if httpResponse.statusCode == 503,
           let requestHost = request.url?.host(),
           requestHost.hasPrefix("192.168.") || requestHost.hasPrefix("10.") || requestHost.hasPrefix("172.") {
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
}
