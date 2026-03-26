import Foundation
import SwiftData

@MainActor
@Observable
final class PersistenceManager {
    let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init() throws {
        let schema = Schema([IncidentRecord.self, MonitorPreference.self])
        let config = ModelConfiguration(
            "KumaNotify",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        self.modelContext = modelContainer.mainContext
    }

    // MARK: - Incident Records

    func recordIncident(_ record: IncidentRecord) {
        modelContext.insert(record)
        try? modelContext.save()
    }

    func fetchRecentIncidents(limit: Int = AppConstants.maxIncidentHistoryDisplay) -> [IncidentRecord] {
        var descriptor = FetchDescriptor<IncidentRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func purgeOldIncidents(olderThan days: Int = AppConstants.incidentRetentionDays) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = #Predicate<IncidentRecord> { $0.timestamp < cutoff }
        try? modelContext.delete(model: IncidentRecord.self, where: predicate)
        try? modelContext.save()
    }

    // MARK: - Monitor Preferences

    func fetchAllPreferences() -> [String: MonitorPreference] {
        let descriptor = FetchDescriptor<MonitorPreference>()
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: results.map { ($0.monitorId, $0) })
    }

    func togglePin(for monitorId: String, serverConnectionId: UUID) {
        let pref = fetchOrCreatePreference(for: monitorId, serverConnectionId: serverConnectionId)
        pref.isPinned.toggle()
        if pref.isPinned { pref.isHidden = false }
        try? modelContext.save()
    }

    func toggleHidden(for monitorId: String, serverConnectionId: UUID) {
        let pref = fetchOrCreatePreference(for: monitorId, serverConnectionId: serverConnectionId)
        pref.isHidden.toggle()
        if pref.isHidden { pref.isPinned = false }
        try? modelContext.save()
    }

    private func fetchOrCreatePreference(for monitorId: String, serverConnectionId: UUID) -> MonitorPreference {
        let predicate = #Predicate<MonitorPreference> { $0.monitorId == monitorId }
        var descriptor = FetchDescriptor<MonitorPreference>(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let pref = MonitorPreference(monitorId: monitorId, serverConnectionId: serverConnectionId)
        modelContext.insert(pref)
        return pref
    }
}
