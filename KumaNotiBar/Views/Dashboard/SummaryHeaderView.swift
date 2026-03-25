import SwiftUI

struct SummaryHeaderView: View {
    let summary: String
    let latency: Int?
    let overallStatus: OverallStatus

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: overallStatus.sfSymbol)
                    .foregroundStyle(overallStatus.color)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(overallStatus.label)
                        .font(.headline)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let latency {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(latency)ms")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("avg")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(12)
    }
}
