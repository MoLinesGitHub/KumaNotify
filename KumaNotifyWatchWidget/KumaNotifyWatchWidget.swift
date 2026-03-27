import SwiftUI
import WidgetKit

@main
struct KumaNotifyWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        KumaNotifyWatchWidget()
    }
}

struct KumaNotifyWatchWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?
}

struct KumaNotifyWatchWidgetProvider: TimelineProvider {
    private let defaults: UserDefaults?
    private let now: () -> Date

    init(
        defaults: UserDefaults? = UserDefaults(suiteName: AppConstants.appGroupId),
        now: @escaping () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.now = now
    }

    func placeholder(in context: Context) -> KumaNotifyWatchWidgetEntry {
        KumaNotifyWatchWidgetEntry(
            date: now(),
            data: WidgetData(
                upCount: 5,
                totalCount: 5,
                downCount: 0,
                overallStatusRaw: "allUp",
                lastCheckTime: now(),
                serverName: "Kuma",
                hasActiveIncident: false
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (KumaNotifyWatchWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KumaNotifyWatchWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = WidgetTimelineSupport.nextRefreshDate(from: now())
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> KumaNotifyWatchWidgetEntry {
        KumaNotifyWatchWidgetEntry(
            date: now(),
            data: WidgetTimelineSupport.readSnapshot(from: defaults)
        )
    }
}

struct KumaNotifyWatchWidgetEntryView: View {
    let entry: KumaNotifyWatchWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let data = entry.data {
            switch family {
            case .accessoryInline:
                inlineView(data)
            case .accessoryCircular:
                circularView(data)
            default:
                rectangularView(data)
            }
        } else {
            switch family {
            case .accessoryInline:
                Text(String(localized: "Open app"))
            case .accessoryCircular:
                circularNoDataView
            default:
                rectangularNoDataView
            }
        }
    }

    private func inlineView(_ data: WidgetData) -> some View {
        if data.overallStatusRaw == "someDown" || data.hasActiveIncident {
            Text(WidgetDataPresentation.watchStatusLabel(for: data))
        } else {
            Text(WidgetDataPresentation.shouldShowSummary(for: data)
                 ? data.monitorSummaryLine
                 : WidgetDataPresentation.statusLabel(for: data))
        }
    }

    private func circularView(_ data: WidgetData) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            if data.overallStatusRaw == "someDown" || data.hasActiveIncident {
                let count = WidgetDataPresentation.criticalEventCount(for: data)
                VStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.appStatusDown)
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
            } else {
                VStack(spacing: 2) {
                    Text("\(data.upCount)")
                        .font(.headline.monospacedDigit())
                    Text("/\(data.totalCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var circularNoDataView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func rectangularView(_ data: WidgetData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor(data))
                    .frame(width: 8, height: 8)
                Text(WidgetDataPresentation.watchStatusLabel(for: data))
                    .font(.headline)
                    .lineLimit(1)
            }

            if data.overallStatusRaw == "someDown" || data.hasActiveIncident {
                Text(data.monitorSummaryLine)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if WidgetDataPresentation.shouldShowSummary(for: data) {
                Text(data.monitorSummaryLine)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let serverName = data.serverName {
                Text(serverName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var rectangularNoDataView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "No data"))
                .font(.headline)
            Text(String(localized: "Open app"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func statusColor(_ data: WidgetData) -> Color {
        switch WidgetDataPresentation.watchStatusColorKey(for: data) {
        case "green": .appStatusUp
        case "yellow": .appStatusDegraded
        case "red": .appStatusDown
        default: .appStatusOffline
        }
    }
}

struct KumaNotifyWatchWidget: Widget {
    let kind = AppConstants.watchWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KumaNotifyWatchWidgetProvider()) { entry in
            KumaNotifyWatchWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("Kuma Notify"))
        .description(LocalizedStringResource("Monitor your services at a glance."))
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
