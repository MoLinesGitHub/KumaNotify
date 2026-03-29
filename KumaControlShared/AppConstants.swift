import Foundation

enum AppConstants {
    static let appGroupId = "group.com.molinesdesigns.kuma-control"
    static let watchConnectionDefaultsKey = "watchServerConnection"
    static let proProductId = "com.molinesdesigns.kumanotify.pro"
    static let widgetKind = "com.molinesdesigns.kumanotify.widget"
    static let watchWidgetKind = "com.molinesdesigns.kumanotify.watch.widget"
    static let defaultPollingInterval: TimeInterval = 60
    static let minimumPollingBasic: TimeInterval = 60
    static let minimumPollingPro: TimeInterval = 10
    static let maximumPollingInterval: TimeInterval = 300
    static let degradedPingThreshold = 500
    static let certExpiryWarningDays = 30
    static let downAlertSoundCooldown: TimeInterval = 30
    static let incidentRetentionDays = 90
    static let maxIncidentHistoryDisplay = 50
}
