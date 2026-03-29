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

    private static let bubbleSize: CGFloat = 88
    @State private var isHovered = false

    private var pingText: String? {
        guard let ping = monitor.latestPing else { return nil }
        return String.localizedStringWithFormat(String(localized: "%@ms"), String(ping))
    }

    private var uptimeText: String? {
        guard let uptime = uptimeForPeriod else { return nil }
        let formatted = uptime.formatted(.percent.precision(.fractionLength(1)))
        return String.localizedStringWithFormat(String(localized: "Uptime %@"), formatted)
    }

    private var accessibilityDescription: String {
        var parts = [monitor.name, monitor.currentStatus.label]
        if let pingText { parts.append(pingText) }
        if let uptimeText { parts.append(uptimeText) }
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
                // Outer glow pulse
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                statusColor.opacity(0.15),
                                statusColor.opacity(0.03),
                                .clear,
                            ],
                            center: .center,
                            startRadius: Self.bubbleSize * 0.2,
                            endRadius: Self.bubbleSize * 0.6
                        )
                    )
                    .frame(width: Self.bubbleSize + 10, height: Self.bubbleSize + 10)

                // Glass orb body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                statusColor.opacity(0.55),
                                statusColor.opacity(0.25),
                                statusColor.opacity(0.08),
                            ],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 0,
                            endRadius: Self.bubbleSize * 0.5
                        )
                    )
                    .frame(width: Self.bubbleSize, height: Self.bubbleSize)

                // Glass highlight (top-left reflection)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.30),
                                Color.white.opacity(0.05),
                                .clear,
                            ],
                            center: UnitPoint(x: 0.3, y: 0.25),
                            startRadius: 0,
                            endRadius: Self.bubbleSize * 0.3
                        )
                    )
                    .frame(width: Self.bubbleSize, height: Self.bubbleSize)

                // Glass border
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.05),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
                    .frame(width: Self.bubbleSize, height: Self.bubbleSize)

                // Content
                VStack(spacing: 2) {
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.orange)
                    }

                    Text(shortName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 8)
                        .foregroundStyle(.white)

                    if let pingText {
                        Text(pingText)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
            }
            .shadow(color: statusColor.opacity(monitor.currentStatus == .down ? 0.6 : 0.25), radius: monitor.currentStatus == .down ? 10 : 4)
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
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
