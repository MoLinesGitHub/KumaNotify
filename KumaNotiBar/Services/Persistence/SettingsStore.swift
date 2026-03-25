import Foundation
import SwiftUI

@Observable
final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults

    init() {
        self.defaults = UserDefaults.standard
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            "pollingInterval": AppConstants.defaultPollingInterval,
            "iconStyle": MenuBarIconStyle.sfSymbol.rawValue,
            "notificationsEnabled": true,
        ])
    }

    // MARK: - Polling

    var pollingInterval: TimeInterval {
        get { defaults.double(forKey: "pollingInterval") }
        set { defaults.set(newValue, forKey: "pollingInterval") }
    }

    // MARK: - Appearance

    var menuBarIconStyle: MenuBarIconStyle {
        get { MenuBarIconStyle(rawValue: defaults.string(forKey: "iconStyle") ?? "") ?? .sfSymbol }
        set { defaults.set(newValue.rawValue, forKey: "iconStyle") }
    }

    // MARK: - Notifications

    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: "notificationsEnabled") }
        set { defaults.set(newValue, forKey: "notificationsEnabled") }
    }

    // MARK: - Server Connection

    var serverConnection: ServerConnection? {
        get {
            guard let data = defaults.data(forKey: "serverConnection") else { return nil }
            return try? JSONDecoder().decode(ServerConnection.self, from: data)
        }
        set {
            if let newValue {
                let data = try? JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "serverConnection")
            } else {
                defaults.removeObject(forKey: "serverConnection")
            }
        }
    }

    // MARK: - First Launch

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }
}

enum MenuBarIconStyle: String, Codable, CaseIterable, Sendable {
    case sfSymbol = "sf_symbol"
    case colorDot = "color_dot"
    case textAndIcon = "text_and_icon"

    var label: String {
        switch self {
        case .sfSymbol: "Antenna Icon"
        case .colorDot: "Color Dot"
        case .textAndIcon: "Text + Icon"
        }
    }
}
