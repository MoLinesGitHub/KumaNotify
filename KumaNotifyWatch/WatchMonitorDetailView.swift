import SwiftUI

struct WatchMonitorDetailView: View {
    let monitor: UnifiedMonitor
    let latestHeartbeat: UnifiedHeartbeat?

    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: monitor.currentStatus.sfSymbol)
                        .foregroundStyle(monitor.currentStatus.color)
                    Text(monitor.currentStatus.label)
                        .font(.headline)
                }

                if let lastStatusChange = monitor.lastStatusChange {
                    WatchDetailRow(
                        title: String(localized: "Last change"),
                        value: Text(lastStatusChange, format: .relative(presentation: .named))
                    )
                }
            }

            Section {
                WatchDetailRow(
                    title: String(localized: "Type"),
                    value: Text(monitor.type)
                )

                if let latestPing = monitor.latestPing {
                    WatchDetailRow(
                        title: String(localized: "Ping"),
                        value: Text("\(latestPing) ms")
                    )
                }

                if let uptime24h = monitor.uptime24h {
                    WatchDetailRow(
                        title: String(localized: "Uptime"),
                        value: Text(uptime24h, format: .percent.precision(.fractionLength(1)))
                    )
                }

                if let validCert = monitor.validCert {
                    WatchDetailRow(
                        title: String(localized: "Certificate"),
                        value: Text(validCert ? String(localized: "Valid") : String(localized: "Invalid"))
                    )
                }

                if let certExpiryDays = monitor.certExpiryDays {
                    WatchDetailRow(
                        title: String(localized: "Certificate expires"),
                        value: Text(
                            String.localizedStringWithFormat(
                                String(localized: "Expires in %lld days"),
                                Int64(certExpiryDays)
                            )
                        )
                    )
                }
            }

            Section(String(localized: "Latest heartbeat")) {
                if let latestHeartbeat {
                    WatchDetailRow(
                        title: String(localized: "Status"),
                        value: Text(latestHeartbeat.status.label)
                    )

                    WatchDetailRow(
                        title: String(localized: "Time"),
                        value: Text(latestHeartbeat.time, format: .relative(presentation: .named))
                    )

                    if let ping = latestHeartbeat.ping {
                        WatchDetailRow(
                            title: String(localized: "Ping"),
                            value: Text("\(ping) ms")
                        )
                    }

                    if !latestHeartbeat.message.isEmpty {
                        Text(latestHeartbeat.message)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No heartbeat yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let url = monitor.url {
                Section {
                    Link(destination: url) {
                        Label(String(localized: "Open URL"), systemImage: "link")
                    }
                }
            }
        }
        .navigationTitle(monitor.name)
    }
}

private struct WatchDetailRow: View {
    let title: String
    let value: Text

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            value
                .multilineTextAlignment(.trailing)
        }
        .font(.caption2)
    }
}
