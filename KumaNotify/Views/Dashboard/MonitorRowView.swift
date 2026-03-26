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

    private static let bubbleSize: CGFloat = 82
    @State private var isHovered = false

    private var accessibilityDescription: String {
        var parts = [monitor.name, monitor.currentStatus.label]
        if let ping = monitor.latestPing {
            parts.append(String(format: String(localized: "%@ms"), "\(ping)"))
        }
        if let uptime = uptimeForPeriod {
            parts.append(String(format: "%.1f%% \(String(localized: "Uptime"))", uptime * 100))
        }
        if let days = monitor.certExpiryDays, days < AppConstants.certExpiryWarningDays {
            parts.append(String(format: String(localized: "Certificate expires in %lld days"), Int64(days)))
        }
        if isPinned { parts.append(String(localized: "Pin to Top")) }
        if isAcknowledged { parts.append(String(localized: "Acknowledge")) }
        return parts.joined(separator: ", ")
    }

    private var uptimeForPeriod: Double? {
        switch uptimePeriod {
        case .twentyFourHours: monitor.uptime24h
        case .sevenDays: monitor.uptime7d ?? monitor.uptime24h
        case .thirtyDays: monitor.uptime30d ?? monitor.uptime24h
        }
    }

    private var statusColor: Color { monitor.currentStatus.color }

    private var shortName: String {
        monitor.name
            .replacingOccurrences(of: "EXT - ", with: "")
            .replacingOccurrences(of: "INT - ", with: "")
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(statusColor.opacity(0.08))
                    .frame(width: Self.bubbleSize + 6, height: Self.bubbleSize + 6)

                // Filled bubble with status color
                Circle()
                    .fill(statusColor.opacity(0.6))
                    .frame(width: Self.bubbleSize, height: Self.bubbleSize)

                // Inner ring
                Circle()
                    .strokeBorder(statusColor.opacity(0.6), lineWidth: 2)
                    .frame(width: Self.bubbleSize, height: Self.bubbleSize)

                // Highlight arc (glass refraction)
                Circle()
                    .trim(from: 0.0, to: 0.3)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: Self.bubbleSize - 4, height: Self.bubbleSize - 4)
                    .rotationEffect(.degrees(-60))

                // Content
                VStack(spacing: 1) {
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.orange)
                    }

                    Text(shortName)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 8)

                    if let ping = monitor.latestPing {
                        Text("\(ping)ms")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .shadow(color: statusColor.opacity(monitor.currentStatus == .down ? 0.5 : 0.2), radius: monitor.currentStatus == .down ? 8 : 3)
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .opacity(isHidden ? 0.35 : 1.0)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .contentShape(Circle())
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
