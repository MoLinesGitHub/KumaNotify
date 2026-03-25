import SwiftUI

enum MonitorStatus: Int, Codable, Sendable, CaseIterable {
    case down = 0
    case up = 1
    case pending = 2
    case maintenance = 3

    var color: Color {
        switch self {
        case .up: .green
        case .down: .red
        case .pending: .yellow
        case .maintenance: .blue
        }
    }

    var label: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .pending: "Pending"
        case .maintenance: "Maintenance"
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
