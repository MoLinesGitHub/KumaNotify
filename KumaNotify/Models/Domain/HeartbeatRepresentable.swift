import Foundation

protocol HeartbeatRepresentable: Sendable {
    var status: MonitorStatus { get }
    var time: Date { get }
    var message: String { get }
    var ping: Int? { get }
}
