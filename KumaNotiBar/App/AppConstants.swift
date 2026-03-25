import Foundation

enum AppConstants {
    static let appGroupId = "group.com.molinesdesigns.kuma-notibar"
    static let proProductId = "com.molinesdesigns.kumanotibar.pro"
    static let defaultPollingInterval: TimeInterval = 60
    static let minimumPollingBasic: TimeInterval = 60
    static let minimumPollingPro: TimeInterval = 10
    static let maximumPollingInterval: TimeInterval = 300
    static let degradedPingThreshold = 500
    static let degradedUptimeThreshold = 0.99
    static let certExpiryWarningDays = 30
}
