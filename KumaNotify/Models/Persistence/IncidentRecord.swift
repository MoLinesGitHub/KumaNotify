import Foundation
import SwiftData

@Model
final class IncidentRecord {
    var monitorId: String
    var monitorName: String
    var serverConnectionId: UUID
    var serverName: String
    var transitionType: String
    var timestamp: Date
    var downDuration: TimeInterval?

    var transition: IncidentTransitionType {
        IncidentTransitionType(rawValue: transitionType) ?? .wentDown
    }

    init(
        monitorId: String,
        monitorName: String,
        serverConnectionId: UUID,
        serverName: String,
        transitionType: IncidentTransitionType,
        timestamp: Date = Date(),
        downDuration: TimeInterval? = nil
    ) {
        self.monitorId = monitorId
        self.monitorName = monitorName
        self.serverConnectionId = serverConnectionId
        self.serverName = serverName
        self.transitionType = transitionType.rawValue
        self.timestamp = timestamp
        self.downDuration = downDuration
    }
}
