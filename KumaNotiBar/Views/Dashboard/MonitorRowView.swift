import SwiftUI

struct MonitorRowView: View {
    let monitor: UnifiedMonitor
    let heartbeats: [UnifiedHeartbeat]?

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(status: monitor.currentStatus, animated: monitor.currentStatus == .down)

            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let ping = monitor.latestPing {
                        Text("\(ping)ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let uptime = monitor.uptime24h {
                        Text(String(format: "%.1f%%", uptime * 100))
                            .font(.caption)
                            .foregroundStyle(uptime >= 0.99 ? .green : .yellow)
                    }
                    if let days = monitor.certExpiryDays, days < 30 {
                        HStack(spacing: 2) {
                            Image(systemName: "lock.shield")
                                .font(.caption2)
                            Text("\(days)d")
                                .font(.caption)
                        }
                        .foregroundStyle(days < 7 ? .red : .yellow)
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
