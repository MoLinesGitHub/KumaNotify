import SwiftUI

struct MonitorGroupSection: View {
    let group: UnifiedGroup
    let heartbeats: [String: [UnifiedHeartbeat]]
    var uptimePeriod: UptimePeriod = .twentyFourHours
    var monitorPreferences: [String: MonitorPreferenceSnapshot] = [:]
    var showProFeatures: Bool = true
    var acknowledgedMonitors: Set<String> = []
    var connectionId: UUID?
    let onMonitorTap: ((UnifiedMonitor) -> Void)?
    var onTogglePin: ((UnifiedMonitor) -> Void)?
    var onToggleHidden: ((UnifiedMonitor) -> Void)?
    var onToggleAcknowledge: ((UnifiedMonitor) -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: 94, maximum: 106), spacing: 8)
    ]

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(group.monitors, id: \.id) { monitor in
                    Button {
                        onMonitorTap?(monitor)
                    } label: {
                        MonitorRowView(
                            monitor: monitor,
                            heartbeats: heartbeats[monitor.id],
                            uptimePeriod: uptimePeriod,
                            isPinned: prefFor(monitor)?.isPinned ?? false,
                            isHidden: prefFor(monitor)?.isHidden ?? false,
                            showProFeatures: showProFeatures,
                            isAcknowledged: connectionId.map { acknowledgedMonitors.contains("\($0):\(monitor.id)") } ?? false,
                            onTogglePin: { onTogglePin?(monitor) },
                            onToggleHidden: { onToggleHidden?(monitor) },
                            onToggleAcknowledge: { onToggleAcknowledge?(monitor) }
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dashboard.monitor.\(monitor.id)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        } header: {
            HStack(spacing: 6) {
                // Colored glass pill
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [sectionColor.opacity(0.8), sectionColor.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 14)
                    .shadow(color: sectionColor.opacity(0.4), radius: 3)

                Text(group.name)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .textCase(.uppercase)
                    .tracking(1.0)

                Spacer()

                let up = group.monitors.filter { $0.currentStatus == .up }.count
                HStack(spacing: 3) {
                    Text("\(up)")
                        .foregroundStyle(Color.kumaGreen)
                    Text("/")
                        .foregroundStyle(.tertiary)
                    Text("\(group.monitors.count)")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.background)
        }
    }

    private var sectionColor: Color {
        let allUp = group.monitors.allSatisfy { $0.currentStatus == .up }
        let anyDown = group.monitors.contains { $0.currentStatus == .down }
        if anyDown { return .appStatusDown }
        if allUp { return .kumaGreen }
        return .appStatusDegraded
    }

    private func prefFor(_ monitor: UnifiedMonitor) -> MonitorPreferenceSnapshot? {
        guard let cid = connectionId else { return monitorPreferences[monitor.id] }
        let key = MonitorPreference.makeCompositeKey(monitorId: monitor.id, serverConnectionId: cid)
        return monitorPreferences[key]
    }
}
