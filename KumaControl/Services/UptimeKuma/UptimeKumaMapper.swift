import Foundation

struct UptimeKumaMapper: Sendable {
    private static let timestampFormatterLock = NSLock()
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
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

        let maintenances = response.maintenanceList.map { m in
            UnifiedMaintenance(
                id: String(m.id ?? 0),
                title: m.title ?? String(localized: "Scheduled Maintenance"),
                description: m.description,
                startDate: m.start.flatMap(parseTimestamp(_:)),
                endDate: m.end.flatMap(parseTimestamp(_:))
            )
        }

        return StatusPageResult(
            title: response.config.title,
            groups: groups,
            heartbeats: heartbeatResult?.heartbeats ?? [:],
            incidents: response.incidents,
            maintenances: maintenances,
            showCertExpiry: response.config.showCertificateExpiry
        )
    }

    func mapHeartbeats(_ response: UKHeartbeatResponse) -> HeartbeatResult {
        var heartbeats: [String: [UnifiedHeartbeat]] = [:]

        for (monitorId, beats) in response.heartbeatList {
            heartbeats[monitorId] = beats.map { beat in
                UnifiedHeartbeat(
                    status: MonitorStatus(rawValue: beat.status) ?? .pending,
                    time: parseTimestamp(beat.time) ?? Date(),
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

        return UnifiedMonitor(
            id: monitorId,
            name: monitor.name,
            type: monitor.type,
            currentStatus: lastBeat?.status ?? .pending,
            latestPing: lastBeat?.ping,
            uptime24h: heartbeatResult?.uptimes["\(monitor.id)_24"],
            uptime7d: heartbeatResult?.uptimes["\(monitor.id)_720"],
            uptime30d: heartbeatResult?.uptimes["\(monitor.id)_43200"],
            certExpiryDays: monitor.certExpiryDaysRemaining,
            validCert: monitor.validCert,
            url: nil,
            lastStatusChange: nil
        )
    }

    private func parseTimestamp(_ value: String) -> Date? {
        Self.timestampFormatterLock.lock()
        defer { Self.timestampFormatterLock.unlock() }
        return Self.timestampFormatter.date(from: value)
    }
}
