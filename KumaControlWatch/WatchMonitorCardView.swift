import SwiftUI

struct WatchMonitorCardView: View {
    let monitor: UnifiedMonitor
    let latestHeartbeat: UnifiedHeartbeat?
    let index: Int

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Status icon + name row
            HStack(spacing: 8) {
                // Animated status icon
                ZStack {
                    Circle()
                        .fill(monitor.currentStatus.color.opacity(0.2))
                        .frame(width: 28, height: 28)

                    Image(systemName: monitor.currentStatus.sfSymbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(monitor.currentStatus.color)
                        .symbolEffect(
                            .pulse,
                            options: .repeating,
                            isActive: monitor.currentStatus == .down
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(monitor.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(monitor.currentStatus.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(monitor.currentStatus.color.opacity(0.85))
                }

                Spacer(minLength: 0)
            }

            // Secondary data row
            HStack(spacing: 12) {
                if let ping = monitor.latestPing {
                    Label {
                        Text("\(ping)ms")
                    } icon: {
                        Image(systemName: "bolt.fill")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                }

                if let uptime = monitor.uptime24h {
                    Label {
                        Text(uptime, format: .percent.precision(.fractionLength(1)))
                    } icon: {
                        Image(systemName: "chart.bar.fill")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 0)
            }
        }
        .glassCard(glowColor: monitor.currentStatus.color, intensity: cardGlowIntensity)
        .staggeredAppear(index: index, baseDelay: 0.15)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.25), value: isPressed)
    }

    private var cardGlowIntensity: CGFloat {
        switch monitor.currentStatus {
        case .down: 1.2
        case .pending: 0.8
        case .up: 0.5
        case .maintenance: 0.4
        }
    }
}
