import Foundation

struct UKStatusPageResponse: Codable, Sendable {
    let config: UKConfig
    let incidents: [UKIncident]
    let publicGroupList: [UKPublicGroup]
    let maintenanceList: [UKMaintenance]
}

struct UKConfig: Codable, Sendable {
    let slug: String
    let title: String
    let description: String?
    let icon: String?
    let autoRefreshInterval: Int?
    let theme: String?
    let published: Bool
    let showTags: Bool
    let showCertificateExpiry: Bool
    let showOnlyLastHeartbeat: Bool
    let footerText: String?
    let showPoweredBy: Bool
}

struct UKPublicGroup: Codable, Sendable {
    let id: Int
    let name: String
    let weight: Int
    let monitorList: [UKMonitor]
}

struct UKMonitor: Codable, Sendable {
    let id: Int
    let name: String
    let sendUrl: Int
    let type: String
    let certExpiryDaysRemaining: Int?
    let validCert: Bool?
}

struct UKIncident: Codable, Sendable {
    let id: Int?
    let title: String?
    let content: String?
    let style: String?
    let createdDate: String?
    let lastUpdatedDate: String?
}

struct UKMaintenance: Codable, Sendable {
    let id: Int?
    let title: String?
    let description: String?
    let start: String?
    let end: String?
}
