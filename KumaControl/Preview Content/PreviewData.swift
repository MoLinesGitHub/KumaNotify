import Foundation

#if DEBUG
enum PreviewData {
    static let monitor = UnifiedMonitor(
        id: "6",
        name: "API Backend",
        type: "http",
        currentStatus: .up,
        latestPing: 108,
        uptime24h: 0.9944,
        certExpiryDays: 79,
        validCert: true,
        url: nil,
        lastStatusChange: nil
    )

    static let downMonitor = UnifiedMonitor(
        id: "9",
        name: "Servidor Web",
        type: "http",
        currentStatus: .down,
        latestPing: nil,
        uptime24h: 0.965,
        certExpiryDays: 79,
        validCert: true,
        url: nil,
        lastStatusChange: nil
    )

    static let group = UnifiedGroup(
        id: "1",
        name: "Cortes",
        weight: 1,
        monitors: [monitor, downMonitor]
    )

    static let heartbeats: [String: [UnifiedHeartbeat]] = [
        "6": (0..<20).map { i in
            UnifiedHeartbeat(
                status: .up,
                time: Date().addingTimeInterval(Double(-i * 60)),
                message: "",
                ping: Int.random(in: 100...200)
            )
        }
    ]

    static let sampleConnection = ServerConnection(
        name: "MoLines Kuma",
        baseURL: URL(string: "http://192.168.3.33:3025")!,
        statusPageSlug: "cortes"
    )

    static var sampleIncidents: [IncidentRecordSnapshot] { [
        IncidentRecordSnapshot(
            monitorId: "9",
            monitorName: "Servidor Web",
            serverConnectionId: UUID(),
            serverName: "MoLines Kuma",
            transitionType: .wentDown,
            timestamp: Date().addingTimeInterval(-3600)
        ),
        IncidentRecordSnapshot(
            monitorId: "9",
            monitorName: "Servidor Web",
            serverConnectionId: UUID(),
            serverName: "MoLines Kuma",
            transitionType: .recovered,
            timestamp: Date().addingTimeInterval(-1800),
            downDuration: 1800
        ),
        IncidentRecordSnapshot(
            monitorId: "6",
            monitorName: "API Backend",
            serverConnectionId: UUID(),
            serverName: "MoLines Kuma",
            transitionType: .wentDown,
            timestamp: Date().addingTimeInterval(-86400 - 7200)
        ),
        IncidentRecordSnapshot(
            monitorId: "6",
            monitorName: "API Backend",
            serverConnectionId: UUID(),
            serverName: "MoLines Kuma",
            transitionType: .recovered,
            timestamp: Date().addingTimeInterval(-86400 - 3600),
            downDuration: 3600
        ),
    ] }
}
#endif
