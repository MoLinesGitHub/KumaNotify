import SwiftUI

struct MonitorGroupSection: View {
    let group: UnifiedGroup
    let heartbeats: [String: [UnifiedHeartbeat]]
    let onMonitorTap: ((UnifiedMonitor) -> Void)?

    var body: some View {
        Section {
            ForEach(group.monitors, id: \.id) { monitor in
                MonitorRowView(
                    monitor: monitor,
                    heartbeats: heartbeats[monitor.id]
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
}
