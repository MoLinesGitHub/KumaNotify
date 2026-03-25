import Foundation

struct UKHeartbeatResponse: Codable, Sendable {
    let heartbeatList: [String: [UKHeartbeat]]
    let uptimeList: [String: Double]
}

struct UKHeartbeat: Codable, Sendable {
    let status: Int
    let time: String
    let msg: String
    let ping: Int?
}
