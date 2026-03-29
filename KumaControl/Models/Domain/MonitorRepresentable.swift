import Foundation

protocol MonitorRepresentable: Identifiable, Sendable {
    var id: String { get }
    var name: String { get }
    var type: String { get }
    var currentStatus: MonitorStatus { get }
    var latestPing: Int? { get }
    var uptime24h: Double? { get }
    var certExpiryDays: Int? { get }
    var validCert: Bool? { get }
    var url: URL? { get }
    var lastStatusChange: Date? { get }
}
