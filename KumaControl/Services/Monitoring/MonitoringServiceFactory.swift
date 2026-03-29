import Foundation

enum MonitoringServiceFactory {
    static func create(for provider: MonitoringProvider) -> any MonitoringServiceProtocol {
        switch provider {
        case .uptimeKuma:
            UptimeKumaService()
        }
    }
}
