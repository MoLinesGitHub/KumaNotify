import SwiftUI

enum CertExpiryBadgeLogic {
    enum Severity {
        case urgent
        case warning
        case notice
    }

    static func severity(for daysRemaining: Int) -> Severity {
        if daysRemaining < 7 { return .urgent }
        if daysRemaining < 14 { return .warning }
        return .notice
    }

    static func compactText(daysRemaining: Int) -> String {
        String(format: String(localized: "%@d"), "\(daysRemaining)")
    }

    static func accessibilityLabel(daysRemaining: Int) -> String {
        String(format: String(localized: "Certificate expires in %lld days"), Int64(daysRemaining))
    }
}

struct CertExpiryBadge: View {
    let daysRemaining: Int

    private var color: Color {
        switch CertExpiryBadgeLogic.severity(for: daysRemaining) {
        case .urgent: .red
        case .warning: .orange
        case .notice: .yellow
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "lock.shield")
                .font(.system(size: 8))
            Text(CertExpiryBadgeLogic.compactText(daysRemaining: daysRemaining))
                .font(.caption2.monospacedDigit())
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CertExpiryBadgeLogic.accessibilityLabel(daysRemaining: daysRemaining))
    }
}
