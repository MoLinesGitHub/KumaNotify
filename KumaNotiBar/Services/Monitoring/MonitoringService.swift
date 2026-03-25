import Foundation

protocol MonitoringServiceProtocol: Sendable {
    func fetchStatusPage(connection: ServerConnection) async throws -> StatusPageResult
    func fetchHeartbeats(connection: ServerConnection) async throws -> HeartbeatResult
    func validateConnection(_ connection: ServerConnection) async throws -> Bool
}
