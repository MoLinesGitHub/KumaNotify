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
    private let defaults: UserDefaults?
    private let now: () -> Date

    init(
        defaults: UserDefaults? = UserDefaults(suiteName: AppConstants.appGroupId),
        now: @escaping () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.now = now
    }

    func placeholder(in context: Context) -> KumaNotifyEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (KumaNotifyEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KumaNotifyEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = WidgetTimelineSupport.nextRefreshDate(from: now())
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    func makeEntry() -> KumaNotifyEntry {
        let data = WidgetTimelineSupport.readSnapshot(from: defaults)
        return KumaNotifyEntry(date: now(), data: data)
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
                    .fill(statusColor(WidgetDataPresentation.statusColorKey(for: data.overallStatusRaw)))
                    .frame(width: 10, height: 10)
                Text(WidgetDataPresentation.statusLabel(for: data))
                    .font(.headline)
                    .lineLimit(1)
            }

            if WidgetDataPresentation.shouldShowSummary(for: data) {
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
        case "green": .appStatusUp
        case "yellow": .appStatusDegraded
        case "red": .appStatusDown
        default: .appStatusOffline
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
