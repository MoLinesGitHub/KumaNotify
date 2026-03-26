import SwiftUI

struct UptimeBadge: View {
    let percentage: Double
    let period: UptimePeriod

    private var displayText: String {
        String(format: "%.1f%%", percentage * 100)
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
    }
}
