import SwiftUI

struct MonitorRowView: View {
    let monitor: UnifiedMonitor
    let heartbeats: [UnifiedHeartbeat]?
    var uptimePeriod: UptimePeriod = .twentyFourHours
    var isPinned: Bool = false
    var isHidden: Bool = false
    var showProFeatures: Bool = true
    var isAcknowledged: Bool = false
    var onTogglePin: (() -> Void)?
    var onToggleHidden: (() -> Void)?
    var onToggleAcknowledge: (() -> Void)?

    private var uptimeForPeriod: Double? {
        switch uptimePeriod {
        case .twentyFourHours: monitor.uptime24h
        case .sevenDays: monitor.uptime7d ?? monitor.uptime24h
        case .thirtyDays: monitor.uptime30d ?? monitor.uptime24h
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(status: monitor.currentStatus, animated: monitor.currentStatus == .down)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                    }
                    Text(monitor.name)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    if let ping = monitor.latestPing {
                        Text("\(ping)ms")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if showProFeatures, let uptime = uptimeForPeriod {
                        UptimeBadge(percentage: uptime, period: uptimePeriod)
                    }
                    if let days = monitor.certExpiryDays, days < AppConstants.certExpiryWarningDays {
                        CertExpiryBadge(daysRemaining: days)
                    }
                }
            }

            Spacer()

            if showProFeatures, let beats = heartbeats, beats.count >= 2 {
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
        .opacity(isHidden ? 0.5 : 1.0)
        .contextMenu {
            Button {
                onTogglePin?()
            } label: {
                Label(
                    isPinned ? String(localized: "Unpin") : String(localized: "Pin to Top"),
                    systemImage: isPinned ? "pin.slash" : "pin"
                )
            }
            Button {
                onToggleHidden?()
            } label: {
                Label(
                    isHidden ? String(localized: "Show") : String(localized: "Hide"),
                    systemImage: isHidden ? "eye" : "eye.slash"
                )
            }
            if monitor.currentStatus == .down {
                Divider()
                Button {
                    onToggleAcknowledge?()
                } label: {
                    Label(
                        isAcknowledged ? String(localized: "Unacknowledge") : String(localized: "Acknowledge"),
                        systemImage: isAcknowledged ? "bell" : "bell.slash"
                    )
                }
            }
        }
    }
}
