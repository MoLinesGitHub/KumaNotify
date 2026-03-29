import SwiftUI

struct WatchMonitorDetailView: View {
    let monitor: UnifiedMonitor
    let latestHeartbeat: UnifiedHeartbeat?

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Hero header
                detailHeader
                    .staggeredAppear(index: 0)

                // Status card
                detailCard(index: 1) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(monitor.currentStatus.color.opacity(0.2))
                                .frame(width: 36, height: 36)
                            Image(systemName: monitor.currentStatus.sfSymbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(monitor.currentStatus.color)
                                .symbolEffect(
                                    .pulse,
                                    options: .repeating,
                                    isActive: monitor.currentStatus == .down
                                )
                        }
                        .pulseGlow(color: monitor.currentStatus.color, radius: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(monitor.currentStatus.label)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(monitor.currentStatus.color)
                            if let lastChange = monitor.lastStatusChange {
                                Text(lastChange, format: .relative(presentation: .named))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        Spacer()
                    }
                }

                // Metrics cards
                if let ping = monitor.latestPing {
                    metricCard(
                        icon: "bolt.fill",
                        title: String(localized: "Ping"),
                        value: "\(ping) ms",
                        color: pingColor(ping),
                        index: 2
                    )
                }

                if let uptime = monitor.uptime24h {
                    metricCard(
                        icon: "chart.bar.fill",
                        title: String(localized: "Uptime 24h"),
                        value: String(format: "%.1f%%", uptime * 100),
                        color: uptimeColor(uptime),
                        index: 3
                    )
                }

                metricCard(
                    icon: "antenna.radiowaves.left.and.right",
                    title: String(localized: "Type"),
                    value: monitor.type,
                    color: .kumaGreen,
                    index: 4
                )

                // Certificate section
                if let validCert = monitor.validCert {
                    metricCard(
                        icon: validCert ? "lock.shield.fill" : "lock.trianglebadge.exclamationmark.fill",
                        title: String(localized: "Certificado"),
                        value: validCert ? String(localized: "Válido") : String(localized: "No válido"),
                        color: validCert ? .kumaGreen : .appStatusDown,
                        index: 5
                    )
                }

                if let certDays = monitor.certExpiryDays {
                    metricCard(
                        icon: "calendar.badge.clock",
                        title: String(localized: "Vencimiento cert."),
                        value: String.localizedStringWithFormat(
                            String(localized: "%lld días"),
                            Int64(certDays)
                        ),
                        color: certDays < 30 ? .appStatusDegraded : .kumaGreen,
                        index: 6
                    )
                }

                // Latest heartbeat section
                if let hb = latestHeartbeat {
                    WatchSectionHeader(title: String(localized: "Último heartbeat"), index: 7)

                    detailCard(index: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Circle()
                                    .fill(hb.status == .up ? Color.kumaGreen : .appStatusDown)
                                    .frame(width: 6, height: 6)
                                Text(hb.status.label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(hb.time, format: .relative(presentation: .named))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.45))
                            }

                            if let ping = hb.ping {
                                HStack {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.kumaGreen.opacity(0.7))
                                    Text("\(ping) ms")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }

                            if !hb.message.isEmpty {
                                Text(hb.message)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .lineLimit(3)
                            }
                        }
                    }
                }

                // URL link
                if let url = monitor.url {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "link")
                                .font(.system(size: 11))
                            Text(String(localized: "Abrir URL"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color.kumaGreen)
                        .frame(maxWidth: .infinity)
                    }
                    .glassCard(glowColor: .kumaGreenDim)
                    .staggeredAppear(index: 9)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 16)
        }
        .background(Color.black)
        .navigationTitle(monitor.name)
    }

    // MARK: - Sub-views

    private var detailHeader: some View {
        Text(monitor.name)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func detailCard<Content: View>(
        index: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(glowColor: monitor.currentStatus.color, intensity: 0.3)
            .staggeredAppear(index: index)
    }

    private func metricCard(
        icon: String,
        title: String,
        value: String,
        color: Color,
        index: Int
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Spacer()
        }
        .glassCard(glowColor: color, intensity: 0.3)
        .staggeredAppear(index: index)
    }

    // MARK: - Color helpers

    private func pingColor(_ ping: Int) -> Color {
        if ping > 500 { return .appStatusDegraded }
        if ping > 200 { return .kumaGreenLight }
        return .kumaGreen
    }

    private func uptimeColor(_ uptime: Double) -> Color {
        if uptime < 0.95 { return .appStatusDown }
        if uptime < 0.99 { return .appStatusDegraded }
        return .kumaGreen
    }
}

// Section header (shared with dashboard, made internal)
struct WatchSectionHeader: View {
    let title: String
    let index: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.kumaGreenLight)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.top, 8)
        .staggeredAppear(index: index)
    }
}
