import SwiftUI

enum MonitorStatus: Int, Codable, Sendable, CaseIterable {
    case down = 0
    case up = 1
    case pending = 2
    case maintenance = 3

    var color: Color {
        switch self {
        case .up: .appStatusUp
        case .down: .appStatusDown
        case .pending: .appStatusDegraded
        case .maintenance: .blue
        }
    }

    var label: String {
        switch self {
        case .up: String(localized: "Up")
        case .down: String(localized: "Down")
        case .pending: String(localized: "Pending")
        case .maintenance: String(localized: "Maintenance")
        }
    }

    var sfSymbol: String {
        switch self {
        case .up: "checkmark.circle.fill"
        case .down: "xmark.circle.fill"
        case .pending: "clock.circle.fill"
        case .maintenance: "wrench.and.screwdriver.fill"
        }
    }
}
