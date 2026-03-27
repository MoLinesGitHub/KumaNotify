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
            case .accessoryCorner:
                cornerView(data)
            default:
                rectangularView(data)
            }
        } else {
            switch family {
            case .accessoryInline:
                Text(String(localized: "Open app"))
            case .accessoryCircular:
                circularNoDataView
            case .accessoryCorner:
                cornerNoDataView
            default:
                rectangularNoDataView
            }
        }
    }

    private func inlineView(_ data: WidgetData) -> some View {
        let watchState = WidgetDataPresentation.watchWidgetState(for: data)
        return Group {
            if watchState == .down || watchState == .incident {
                Text(WidgetDataPresentation.watchStatusLabel(for: data))
            } else {
                Text(WidgetDataPresentation.shouldShowSummary(for: data)
                     ? data.monitorSummaryLine
                     : WidgetDataPresentation.statusLabel(for: data))
            }
        }
    }

    private func circularView(_ data: WidgetData) -> some View {
        let watchState = WidgetDataPresentation.watchWidgetState(for: data)
        return ZStack {
            AccessoryWidgetBackground()
            switch watchState {
            case .incident:
                Text("\(WidgetDataPresentation.watchCount(for: data))")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.appStatusDown)
            case .down:
                VStack(spacing: 2) {
                    Image(systemName: WidgetDataPresentation.watchSymbolName(for: data))
                        .font(.caption)
                        .foregroundStyle(Color.appStatusDown)
                    Text("\(WidgetDataPresentation.watchCount(for: data))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.primary)
                }
            case .degraded:
                Image(systemName: WidgetDataPresentation.watchSymbolName(for: data))
                    .font(.headline)
                    .foregroundStyle(Color.appStatusDegraded)
            case .healthy:
                VStack(spacing: 2) {
                    Text("\(data.upCount)")
                        .font(.headline.monospacedDigit())
                    Text("/\(data.totalCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            case .offline:
                Image(systemName: WidgetDataPresentation.watchSymbolName(for: data))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private func cornerView(_ data: WidgetData) -> some View {
        let watchState = WidgetDataPresentation.watchWidgetState(for: data)

        return ZStack {
            AccessoryWidgetBackground()
            Group {
                switch watchState {
                case .incident:
                    Text("\(WidgetDataPresentation.watchCount(for: data))")
                        .font(.headline.monospacedDigit())
                case .down:
                    VStack(spacing: 1) {
                        Image(systemName: WidgetDataPresentation.watchSymbolName(for: data))
                            .font(.caption2)
                        Text("\(WidgetDataPresentation.watchCount(for: data))")
                            .font(.caption2.monospacedDigit())
                    }
                case .degraded, .healthy, .offline:
                    Image(systemName: WidgetDataPresentation.watchSymbolName(for: data))
                        .font(.caption)
                }
            }
            .foregroundStyle(statusColor(data))
        }
        .widgetLabel {
            Text(
                watchState == .down || watchState == .incident
                ? WidgetDataPresentation.watchStatusLabel(for: data)
                : data.monitorSummaryLine
            )
        }
    }

    private func rectangularView(_ data: WidgetData) -> some View {
        let watchState = WidgetDataPresentation.watchWidgetState(for: data)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if watchState == .incident {
                    Text("\(WidgetDataPresentation.watchCount(for: data))")
                        .font(.caption.monospacedDigit())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.appStatusDown)
                        .frame(minWidth: 14, alignment: .leading)
                } else {
                    Image(systemName: WidgetDataPresentation.watchSymbolName(for: data))
                        .font(.caption)
                        .foregroundStyle(statusColor(data))
                }
                Text(WidgetDataPresentation.watchStatusLabel(for: data))
                    .font(.headline)
                    .lineLimit(1)
            }

            if watchState == .down || watchState == .incident {
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

    private var cornerNoDataView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .widgetLabel {
            Text(String(localized: "Open app"))
        }
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
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}
