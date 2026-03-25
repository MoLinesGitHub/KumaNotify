import SwiftUI

struct FilterBarView: View {
    @Binding var statusFilter: MonitorStatus?
    @Binding var searchText: String
    @Binding var uptimePeriod: UptimePeriod

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                filterButton(label: "All", filter: nil)
                filterButton(label: "Up", filter: .up, color: .green)
                filterButton(label: "Down", filter: .down, color: .red)
                filterButton(label: "Pending", filter: .pending, color: .yellow)
                Spacer()
                Picker("", selection: $uptimePeriod) {
                    ForEach(UptimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                TextField("Search monitors...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func filterButton(label: String, filter: MonitorStatus?, color: Color = .primary) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                statusFilter = statusFilter == filter ? nil : filter
            }
        } label: {
            Text(label)
                .font(.caption2)
                .fontWeight(statusFilter == filter ? .semibold : .regular)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    statusFilter == filter ? color.opacity(0.2) : Color.clear,
                    in: Capsule()
                )
                .foregroundStyle(statusFilter == filter ? color : .secondary)
        }
        .buttonStyle(.borderless)
    }
}

enum UptimePeriod: String, CaseIterable, Sendable {
    case twentyFourHours = "24h"
    case sevenDays = "7d"
    case thirtyDays = "30d"

    var uptimeKeySuffix: String {
        switch self {
        case .twentyFourHours: "24"
        case .sevenDays: "720"
        case .thirtyDays: "43200"
        }
    }
}
