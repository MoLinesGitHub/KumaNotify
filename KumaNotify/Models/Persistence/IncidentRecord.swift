import Foundation
import SwiftData

@Model
final class IncidentRecord: @unchecked Sendable {
    var monitorId: String
    var monitorName: String
    var serverConnectionId: UUID
    var serverName: String
    var transitionType: IncidentTransitionType
    var timestamp: Date
    var downDuration: TimeInterval?

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
        self.transitionType = transitionType
        self.timestamp = timestamp
        // downDuration only meaningful for recovery events
        self.downDuration = transitionType == .recovered ? downDuration : nil
    }
}
