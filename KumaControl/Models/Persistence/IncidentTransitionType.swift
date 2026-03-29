import SwiftUI

enum IncidentTransitionType: String, Codable, Sendable {
    case wentDown = "went_down"
    case recovered = "recovered"

    var label: String {
        switch self {
        case .wentDown: String(localized: "Went Down")
        case .recovered: String(localized: "Recovered")
        }
    }

    var sfSymbol: String {
        switch self {
        case .wentDown: "arrow.down.circle.fill"
        case .recovered: "arrow.up.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .wentDown: .red
        case .recovered: .green
        }
    }
}
