import Foundation
import SwiftData

struct IncidentRecordSnapshot: Identifiable, Sendable, Equatable {
    let id: String
    let monitorId: String
    let monitorName: String
    let serverConnectionId: UUID
    let serverName: String
    let transitionType: IncidentTransitionType
    let timestamp: Date
    let downDuration: TimeInterval?

    init(
        id: String = UUID().uuidString,
        monitorId: String,
        monitorName: String,
        serverConnectionId: UUID,
        serverName: String,
        transitionType: IncidentTransitionType,
        timestamp: Date = Date(),
        downDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.monitorId = monitorId
        self.monitorName = monitorName
        self.serverConnectionId = serverConnectionId
        self.serverName = serverName
        self.transitionType = transitionType
        self.timestamp = timestamp
        self.downDuration = transitionType == .recovered ? downDuration : nil
    }

    init(_ record: IncidentRecord) {
        self.init(
            id: String(describing: record.persistentModelID),
            monitorId: record.monitorId,
            monitorName: record.monitorName,
            serverConnectionId: record.serverConnectionId,
            serverName: record.serverName,
            transitionType: record.transitionType,
            timestamp: record.timestamp,
            downDuration: record.downDuration
        )
    }
}

@Model
final class IncidentRecord {
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

    convenience init(snapshot: IncidentRecordSnapshot) {
        self.init(
            monitorId: snapshot.monitorId,
            monitorName: snapshot.monitorName,
            serverConnectionId: snapshot.serverConnectionId,
            serverName: snapshot.serverName,
            transitionType: snapshot.transitionType,
            timestamp: snapshot.timestamp,
            downDuration: snapshot.downDuration
        )
    }
}
