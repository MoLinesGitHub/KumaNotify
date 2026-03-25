import SwiftUI

enum OverallStatus: Sendable {
    case allUp
    case degraded(reason: DegradedReason)
    case someDown(count: Int, total: Int)
    case unreachable

    enum DegradedReason: Sendable {
        case highPing(monitorName: String, pingMs: Int)
        case lowUptime(monitorName: String, uptimePercent: Double)
        case certExpiringSoon(monitorName: String, daysRemaining: Int)
    }

    var color: Color {
        switch self {
        case .allUp: .green
        case .degraded: .yellow
        case .someDown: .red
        case .unreachable: .gray
        }
    }

    var sfSymbol: String {
        switch self {
        case .allUp: "antenna.radiowaves.left.and.right"
        case .degraded: "antenna.radiowaves.left.and.right"
        case .someDown: "antenna.radiowaves.left.and.right.slash"
        case .unreachable: "antenna.radiowaves.left.and.right.slash"
        }
    }

    var label: String {
        switch self {
        case .allUp: "All systems operational"
        case .degraded: "Degraded performance"
        case .someDown(let count, _): "\(count) monitor\(count == 1 ? "" : "s") down"
        case .unreachable: "Server unreachable"
        }
    }
}
