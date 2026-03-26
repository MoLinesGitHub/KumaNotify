import SwiftUI

struct MonitorGroupSection: View {
    let group: UnifiedGroup
    let heartbeats: [String: [UnifiedHeartbeat]]
    var uptimePeriod: UptimePeriod = .twentyFourHours
    var monitorPreferences: [String: MonitorPreference] = [:]
    var showProFeatures: Bool = true
    var acknowledgedMonitors: Set<String> = []
    var connectionId: UUID?
    let onMonitorTap: ((UnifiedMonitor) -> Void)?
    var onTogglePin: ((UnifiedMonitor) -> Void)?
    var onToggleHidden: ((UnifiedMonitor) -> Void)?
    var onToggleAcknowledge: ((UnifiedMonitor) -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: 88, maximum: 100), spacing: 6)
    ]

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(group.monitors, id: \.id) { monitor in
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
                    .onTapGesture {
                        onMonitorTap?(monitor)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        } header: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(sectionColor)
                    .frame(width: 3, height: 12)

                Text(group.name)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Spacer()

                let up = group.monitors.filter { $0.currentStatus == .up }.count
                Text("\(up)/\(group.monitors.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.background)
        }
    }

    private var sectionColor: Color {
        let allUp = group.monitors.allSatisfy { $0.currentStatus == .up }
        let anyDown = group.monitors.contains { $0.currentStatus == .down }
        if anyDown { return .red }
        if allUp { return .green }
        return .yellow
    }

    private func prefFor(_ monitor: UnifiedMonitor) -> MonitorPreference? {
        guard let cid = connectionId else { return monitorPreferences[monitor.id] }
        let key = MonitorPreference.makeCompositeKey(monitorId: monitor.id, serverConnectionId: cid)
        return monitorPreferences[key]
    }
}
