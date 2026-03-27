import SwiftUI

struct UptimeBadge: View {
    let percentage: Double
    let period: UptimePeriod

    private var displayText: String {
        percentage.formatted(.percent.precision(.fractionLength(1)))
    }

    private var color: Color {
        if percentage >= 0.999 { return .green }
        if percentage >= 0.99 { return .green.opacity(0.8) }
        if percentage >= 0.95 { return .yellow }
        return .red
    }

    var body: some View {
        Text(displayText)
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel(String(localized: "Uptime"))
            .accessibilityValue(
                String.localizedStringWithFormat(
                    String(localized: "Uptime %@ (%@)"),
                    displayText,
                    period.rawValue
                )
            )
    }
}
