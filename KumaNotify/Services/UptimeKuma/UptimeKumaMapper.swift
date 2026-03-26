import Foundation

struct UptimeKumaMapper: Sendable {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    func mapStatusPage(
        _ response: UKStatusPageResponse,
        heartbeatResult: HeartbeatResult?
    ) -> StatusPageResult {
        let groups = response.publicGroupList
            .sorted { $0.weight < $1.weight }
            .map { group in
                UnifiedGroup(
                    id: String(group.id),
                    name: group.name,
                    weight: group.weight,
                    monitors: group.monitorList.map { monitor in
                        mapMonitor(monitor, heartbeatResult: heartbeatResult)
                    }
                )
            }

        return StatusPageResult(
            title: response.config.title,
            groups: groups,
            incidents: response.incidents,
            maintenances: response.maintenanceList,
            showCertExpiry: response.config.showCertificateExpiry
        )
    }

    func mapHeartbeats(_ response: UKHeartbeatResponse) -> HeartbeatResult {
        var heartbeats: [String: [UnifiedHeartbeat]] = [:]

        for (monitorId, beats) in response.heartbeatList {
            heartbeats[monitorId] = beats.map { beat in
                UnifiedHeartbeat(
                    status: MonitorStatus(rawValue: beat.status) ?? .pending,
                    time: Self.dateFormatter.date(from: beat.time) ?? Date(),
                    message: beat.msg,
                    ping: beat.ping
                )
            }
        }

        return HeartbeatResult(
            heartbeats: heartbeats,
            uptimes: response.uptimeList
        )
    }

    private func mapMonitor(
        _ monitor: UKMonitor,
        heartbeatResult: HeartbeatResult?
    ) -> UnifiedMonitor {
        let monitorId = String(monitor.id)
        let beats = heartbeatResult?.heartbeats[monitorId]
        let lastBeat = beats?.last
        let uptimeKey = "\(monitor.id)_24"

        return UnifiedMonitor(
            id: monitorId,
            name: monitor.name,
            type: monitor.type,
            currentStatus: lastBeat?.status ?? .pending,
            latestPing: lastBeat?.ping,
            uptime24h: heartbeatResult?.uptimes[uptimeKey],
            certExpiryDays: monitor.certExpiryDaysRemaining,
            validCert: monitor.validCert,
            url: nil,
            lastStatusChange: nil
        )
    }
}
