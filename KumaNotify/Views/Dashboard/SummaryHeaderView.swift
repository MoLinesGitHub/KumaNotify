import SwiftUI

struct SummaryHeaderView: View {
    let summary: String
    let latency: Int?
    let overallStatus: OverallStatus
    var lastIncidentDate: Date?

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: overallStatus.sfSymbol)
                    .foregroundStyle(overallStatus.color)
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(overallStatus.label)
                        .font(.headline)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    if let latency {
                        Text("\(latency)ms")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("avg")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            if let lastIncidentDate {
                HStack(spacing: 4) {
                    Image(systemName: "shield.checkered")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    Text(String(format: String(localized: "Last incident %@"), lastIncidentDate.formatted(.relative(presentation: .named))))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
        .padding(12)
    }
}
