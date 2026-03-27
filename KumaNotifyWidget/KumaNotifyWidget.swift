import WidgetKit
import SwiftUI

struct KumaNotifyEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?

    static let placeholder = KumaNotifyEntry(
        date: .now,
        data: WidgetData(
            upCount: 5, totalCount: 5, downCount: 0,
            overallStatusRaw: "allUp", lastCheckTime: .now,
            serverName: "Server", hasActiveIncident: false
        )
    )
}

struct KumaNotifyProvider: TimelineProvider {
    func placeholder(in context: Context) -> KumaNotifyEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (KumaNotifyEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KumaNotifyEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> KumaNotifyEntry {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupId)
        let data = defaults.flatMap { WidgetData.read(from: $0) }
        return KumaNotifyEntry(date: .now, data: data)
    }
}

// MARK: - Widget Views

struct KumaNotifyWidgetEntryView: View {
    var entry: KumaNotifyEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        if let data = entry.data {
            statusView(data)
        } else {
            noDataView
        }
    }

    private func statusView(_ data: WidgetData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor(data.overallStatusRaw))
                    .frame(width: 10, height: 10)
                Text(statusLabel(data))
                    .font(.headline)
                    .lineLimit(1)
            }

            if data.overallStatusRaw != "unreachable" {
                Text(data.monitorSummaryLine)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let serverName = data.serverName {
                Text(serverName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if let time = data.lastCheckTime {
                Text(time, format: .relative(presentation: .numeric))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }

    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(String(localized: "Open Kuma Notify to start monitoring"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func statusColor(_ key: String) -> Color {
        switch key {
        case "allUp": .green
        case "degraded": .yellow
        case "someDown": .red
        default: .gray
        }
    }

    private func statusLabel(_ data: WidgetData) -> String {
        switch data.overallStatusRaw {
        case "allUp": String(localized: "All OK")
        case "degraded": String(localized: "Degraded")
        case "someDown": String(format: String(localized: "%lld down"), data.downCount)
        default: String(localized: "Offline")
        }
    }
}

// MARK: - Widget Definition

struct KumaNotifyWidget: Widget {
    let kind = "com.molinesdesigns.kumanotify.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KumaNotifyProvider()) { entry in
            KumaNotifyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("Kuma Notify"))
        .description(LocalizedStringResource("Monitor your services at a glance."))
        .supportedFamilies([.systemSmall])
    }
}
