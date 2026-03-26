import SwiftUI

struct IncidentHistoryView: View {
    let incidents: [IncidentRecord]
    let onDismiss: () -> Void

    private var groupedByDate: [(key: String, incidents: [IncidentRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: incidents) { incident -> String in
            if calendar.isDateInToday(incident.timestamp) {
                return String(localized: "Today")
            } else if calendar.isDateInYesterday(incident.timestamp) {
                return String(localized: "Yesterday")
            } else {
                return incident.timestamp.formatted(.dateTime.month(.abbreviated).day())
            }
        }
        let ordered = incidents.map { incident -> String in
            if calendar.isDateInToday(incident.timestamp) {
                return String(localized: "Today")
            } else if calendar.isDateInYesterday(incident.timestamp) {
                return String(localized: "Yesterday")
            } else {
                return incident.timestamp.formatted(.dateTime.month(.abbreviated).day())
            }
        }
        var seen = Set<String>()
        let uniqueOrder = ordered.filter { seen.insert($0).inserted }
        return uniqueOrder.compactMap { key in
            guard let items = grouped[key] else { return nil }
            return (key: key, incidents: items)
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
