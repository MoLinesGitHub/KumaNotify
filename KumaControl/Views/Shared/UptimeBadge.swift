import SwiftUI

enum UptimeBadgeLogic {
    enum ColorTier {
        case healthy
        case healthySoft
        case warning
        case critical
    }

    static func displayText(for percentage: Double) -> String {
        percentage.formatted(.percent.precision(.fractionLength(1)))
    }

    static func colorTier(for percentage: Double) -> ColorTier {
        if percentage >= 0.999 { return .healthy }
        if percentage >= 0.99 { return .healthySoft }
        if percentage >= 0.95 { return .warning }
        return .critical
    }

    static func accessibilityValue(percentage: Double, period: UptimePeriod) -> String {
        String.localizedStringWithFormat(
            String(localized: "Uptime %@ (%@)"),
            displayText(for: percentage),
            period.rawValue
        )
    }
}

struct UptimeBadge: View {
    let percentage: Double
    let period: UptimePeriod

    private var displayText: String {
        UptimeBadgeLogic.displayText(for: percentage)
    }

    private var color: Color {
        switch UptimeBadgeLogic.colorTier(for: percentage) {
        case .healthy: .green
        case .healthySoft: .green.opacity(0.8)
        case .warning: .yellow
        case .critical: .red
        }
    }

    var body: some View {
        Text(displayText)
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel(String(localized: "Uptime"))
            .accessibilityValue(UptimeBadgeLogic.accessibilityValue(percentage: percentage, period: period))
    }
}
