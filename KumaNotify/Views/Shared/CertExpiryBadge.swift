import SwiftUI

struct CertExpiryBadge: View {
    let daysRemaining: Int

    private var color: Color {
        if daysRemaining < 7 { return .red }
        if daysRemaining < 14 { return .orange }
        return .yellow
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "lock.shield")
                .font(.system(size: 8))
            Text("\(daysRemaining)d")
                .font(.caption2.monospacedDigit())
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }
}
