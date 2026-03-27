import SwiftUI

struct IncidentRowView: View {
    let incident: IncidentRecordSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: incident.transitionType.sfSymbol)
                .foregroundStyle(incident.transitionType.color)
                .font(.caption)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(incident.monitorName)
                    .font(.system(.caption, weight: .medium))
                    .lineLimit(1)
                Text(incident.transitionType.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(incident.timestamp, style: .time)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let duration = incident.downDuration {
                    Text(Self.durationFormatter.string(from: duration) ?? "")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.hour, .minute, .second]
        f.maximumUnitCount = 2
        return f
    }()
}
