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

    var menuBarAssetName: String {
        switch self {
        case .allUp: "MenuBarIconUp"
        case .degraded: "MenuBarIconDegraded"
        case .someDown: "MenuBarIconDown"
        case .unreachable: "MenuBarIconOffline"
        }
    }

    var widgetKey: String {
        switch self {
        case .allUp: "allUp"
        case .degraded: "degraded"
        case .someDown: "someDown"
        case .unreachable: "unreachable"
        }
    }

    var label: String {
        switch self {
        case .allUp: String(localized: "All systems operational")
        case .degraded: String(localized: "Degraded performance")
        case .someDown(let count, _):
            String.localizedStringWithFormat(String(localized: "%lld monitors down"), count)
        case .unreachable: String(localized: "Server unreachable")
        }
    }
}
