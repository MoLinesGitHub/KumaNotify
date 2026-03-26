import Foundation

final class UptimeKumaService: MonitoringServiceProtocol, Sendable {
    private let httpClient: HTTPClientProtocol
    private let mapper = UptimeKumaMapper()

    init(httpClient: HTTPClientProtocol = HTTPClient()) {
        self.httpClient = httpClient
    }

    func fetchStatusPage(connection: ServerConnection) async throws -> StatusPageResult {
        let heartbeatResult = try await fetchHeartbeats(connection: connection)

        let response: UKStatusPageResponse = try await httpClient.get(url: connection.statusPageURL)
        return mapper.mapStatusPage(response, heartbeatResult: heartbeatResult)
    }

    func fetchHeartbeats(connection: ServerConnection) async throws -> HeartbeatResult {
        let response: UKHeartbeatResponse = try await httpClient.get(url: connection.heartbeatURL)
        return mapper.mapHeartbeats(response)
    }

    func validateConnection(_ connection: ServerConnection) async throws -> Bool {
        let _: UKStatusPageResponse = try await httpClient.get(url: connection.statusPageURL)
        return true
    }
}
