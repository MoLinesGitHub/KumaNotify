import SwiftUI

struct MonitorRowView: View {
    let monitor: UnifiedMonitor
    let heartbeats: [UnifiedHeartbeat]?
    var uptimePeriod: UptimePeriod = .twentyFourHours

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(status: monitor.currentStatus, animated: monitor.currentStatus == .down)

            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let ping = monitor.latestPing {
                        Text("\(ping)ms")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if let uptime = monitor.uptime24h {
                        UptimeBadge(percentage: uptime, period: uptimePeriod)
                    }
                    if let days = monitor.certExpiryDays, days < AppConstants.certExpiryWarningDays {
                        CertExpiryBadge(daysRemaining: days)
                    }
                }
            }

            Spacer()

            if let beats = heartbeats, beats.count >= 2 {
                SparklineView(
                    dataPoints: beats.compactMap(\.ping).suffix(20).map { $0 },
                    color: monitor.currentStatus.color
                )
                .frame(width: 50, height: 18)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}
