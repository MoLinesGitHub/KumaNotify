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

    var body: some View {
        Section {
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
        } header: {
            HStack {
                Text(group.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                let up = group.monitors.filter { $0.currentStatus == .up }.count
                Text("\(up)/\(group.monitors.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private func prefFor(_ monitor: UnifiedMonitor) -> MonitorPreference? {
        guard let cid = connectionId else { return monitorPreferences[monitor.id] }
        let key = MonitorPreference.makeCompositeKey(monitorId: monitor.id, serverConnectionId: cid)
        return monitorPreferences[key]
    }
}
