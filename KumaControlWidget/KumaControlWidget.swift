import WidgetKit
import SwiftUI

struct KumaControlEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?

    static let placeholder = KumaControlEntry(
        date: .now,
        data: WidgetData(
            upCount: 5, totalCount: 5, downCount: 0,
            overallStatusRaw: "allUp", lastCheckTime: .now,
            serverName: "Server", hasActiveIncident: false
        )
    )
}

struct KumaControlProvider: TimelineProvider {
    private let defaults: UserDefaults?
    private let now: () -> Date

    init(
        defaults: UserDefaults? = UserDefaults(suiteName: AppConstants.appGroupId),
        now: @escaping () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.now = now
    }

    func placeholder(in context: Context) -> KumaControlEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (KumaControlEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KumaControlEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = WidgetTimelineSupport.nextRefreshDate(from: now())
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    func makeEntry() -> KumaControlEntry {
        let data = WidgetTimelineSupport.readSnapshot(from: defaults)
        return KumaControlEntry(date: now(), data: data)
    }
}

// MARK: - Widget Views

struct KumaControlWidgetEntryView: View {
    var entry: KumaControlEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        if let data = entry.data {
            statusView(data)
        } else {
            noDataView
        }
    }

    private func statusView(_ data: WidgetData) -> some View {
        let stateColor = resolveStatusColor(data.overallStatusRaw)

        return ZStack {
            // Glass background
            ContainerRelativeShape()
                .fill(Color.black)

            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [
                            stateColor.opacity(0.12),
                            stateColor.opacity(0.03),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Glass highlight edge
            ContainerRelativeShape()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.03),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Status orb + label
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        stateColor.opacity(0.7),
                                        stateColor.opacity(0.2),
                                    ],
                                    center: UnitPoint(x: 0.35, y: 0.3),
                                    startRadius: 0,
                                    endRadius: 8
                                )
                            )
                            .frame(width: 14, height: 14)

                        Circle()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                            .frame(width: 14, height: 14)
                    }
                    .shadow(color: stateColor.opacity(0.4), radius: 4)

                    Text(WidgetDataPresentation.statusLabel(for: data))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // Monitor count
                if WidgetDataPresentation.shouldShowSummary(for: data) {
                    Text(data.monitorSummaryLine)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 0)

                // Server name
                if let serverName = data.serverName {
                    Text(serverName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }

                // Last check
                if let time = data.lastCheckTime {
                    Text(time, format: .relative(presentation: .numeric))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
            .padding(12)
        }
    }

    private var noDataView: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color.black)

            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.kumaGreen.opacity(0.06),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ContainerRelativeShape()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.02),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )

            VStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.kumaGreen.opacity(0.4))
                Text(String(localized: "Abre Kuma Control para monitorizar"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(12)
        }
    }

    private func resolveStatusColor(_ overallStatusRaw: String) -> Color {
        switch overallStatusRaw {
        case "allUp": .kumaGreen
        case "degraded": .appStatusDegraded
        case "someDown": .appStatusDown
        default: .appStatusOffline
        }
    }
}

// MARK: - Widget Definition

struct KumaControlWidget: Widget {
    let kind = "com.molinesdesigns.kumanotify.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KumaControlProvider()) { entry in
            KumaControlWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("Kuma Control"))
        .description(LocalizedStringResource("Monitor your services at a glance."))
        .supportedFamilies([.systemSmall])
    }
}
