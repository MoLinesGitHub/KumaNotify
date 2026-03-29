import SwiftUI

enum SummaryHeaderViewLogic {
    static func latencyValueText(_ latency: Int) -> String {
        "\(latency)"
    }

    static func lastIncidentText(_ date: Date) -> String {
        String(
            format: String(localized: "Last incident %@"),
            date.formatted(.relative(presentation: .named))
        )
    }
}

struct SummaryHeaderView: View {
    let summary: String
    let latency: Int?
    let overallStatus: OverallStatus
    var lastIncidentDate: Date?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(overallStatus.color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Circle()
                        .fill(overallStatus.color.opacity(0.3))
                        .frame(width: 26, height: 26)

                    Image(systemName: overallStatus.sfSymbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(overallStatus.color)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(overallStatus.label)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Text(summary)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let latency {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(SummaryHeaderViewLogic.latencyValueText(latency))
                            .font(.system(.title3, design: .rounded, weight: .bold).monospacedDigit())
                            .foregroundStyle(overallStatus.color)
                        Text("ms avg")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let lastIncidentDate {
                HStack(spacing: 4) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(SummaryHeaderViewLogic.lastIncidentText(lastIncidentDate))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
