import SwiftUI

struct MaintenanceBannerView: View {
    let maintenances: [UnifiedMaintenance]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(maintenances) { maintenance in
                maintenanceRow(maintenance)
                if maintenance.id != maintenances.last?.id {
                    Divider().padding(.horizontal, 8)
                }
            }
        }
        .background(.yellow.opacity(0.08))
    }

    private func maintenanceRow(_ maintenance: UnifiedMaintenance) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver")
                .foregroundStyle(.yellow)
                .font(.caption)
                .frame(width: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(maintenance.title)
                    .font(.system(.caption, weight: .medium))
                    .lineLimit(1)
                if let desc = maintenance.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let start = maintenance.startDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(start, format: .relative(presentation: .named))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let end = maintenance.endDate {
                        Text(String(format: String(localized: "→ %@"), end.formatted(date: .omitted, time: .shortened)))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }
}
