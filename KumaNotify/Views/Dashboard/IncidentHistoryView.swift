import SwiftUI

struct IncidentHistoryView: View {
    let incidents: [IncidentRecord]
    let onDismiss: () -> Void

    private var groupedByDate: [(key: String, incidents: [IncidentRecord])] {
        let calendar = Calendar.current
        func dateKey(for incident: IncidentRecord) -> String {
            if calendar.isDateInToday(incident.timestamp) {
                return String(localized: "Today")
            } else if calendar.isDateInYesterday(incident.timestamp) {
                return String(localized: "Yesterday")
            } else {
                return incident.timestamp.formatted(.dateTime.day().month(.abbreviated).year())
            }
        }
        let keyed = incidents.map { (key: dateKey(for: $0), incident: $0) }
        var seen = Set<String>()
        let uniqueOrder = keyed.compactMap { seen.insert($0.key).inserted ? $0.key : nil }
        let grouped = Dictionary(grouping: keyed, by: \.key)
        return uniqueOrder.compactMap { k in
            guard let items = grouped[k] else { return nil }
            return (key: k, incidents: items.map(\.incident))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Text("Incident History")
                    .font(.headline)
                Spacer()
            }
            .padding(12)

            Divider()

            if incidents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedByDate, id: \.key) { section in
                            Section {
                                ForEach(section.incidents, id: \.persistentModelID) { incident in
                                    IncidentRowView(incident: incident)
                                }
                            } header: {
                                HStack {
                                    Text(section.key)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.bar)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No incidents recorded")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Incidents will appear here when monitors go down or recover.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}
