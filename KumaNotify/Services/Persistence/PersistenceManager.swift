import Foundation
import SwiftData
import os

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
        // Deduplication: skip if same monitor+transition within 60s
        let windowStart = record.timestamp.addingTimeInterval(-60)
        let monId = record.monitorId
        let transition = record.transitionType
        let dedupPredicate = #Predicate<IncidentRecord> {
            $0.monitorId == monId &&
            $0.transitionType == transition &&
            $0.timestamp > windowStart
        }
        var dedupDescriptor = FetchDescriptor<IncidentRecord>(predicate: dedupPredicate)
        dedupDescriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(dedupDescriptor), !existing.isEmpty {
            Logger.persistence.debug("Skipping duplicate incident for monitor \(monId)")
            return
        }

        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            Logger.persistence.error("Failed to save incident for '\(record.monitorName)': \(error.localizedDescription)")
            modelContext.delete(record)
        }
    }

    func fetchRecentIncidents(limit: Int = AppConstants.maxIncidentHistoryDisplay) -> [IncidentRecord] {
        var descriptor = FetchDescriptor<IncidentRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Logger.persistence.error("Failed to fetch incidents: \(error.localizedDescription)")
            return []
        }
    }

    func purgeOldIncidents(olderThan days: Int = AppConstants.incidentRetentionDays) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            Logger.persistence.error("Failed to calculate purge cutoff date")
            return
        }
        let predicate = #Predicate<IncidentRecord> { $0.timestamp < cutoff }
        do {
            try modelContext.delete(model: IncidentRecord.self, where: predicate)
            try modelContext.save()
        } catch {
            Logger.persistence.error("Failed to purge old incidents: \(error.localizedDescription)")
        }
    }

    // MARK: - Monitor Preferences

    func fetchAllPreferences() -> [String: MonitorPreference] {
        let descriptor = FetchDescriptor<MonitorPreference>()
        do {
            let results = try modelContext.fetch(descriptor)
            return Dictionary(results.map { ($0.monitorId, $0) }, uniquingKeysWith: { _, new in new })
        } catch {
            Logger.persistence.error("Failed to fetch preferences: \(error.localizedDescription)")
            return [:]
        }
    }

    func togglePin(for monitorId: String, serverConnectionId: UUID) {
        let pref = fetchOrCreatePreference(for: monitorId, serverConnectionId: serverConnectionId)
        pref.pin()
        do {
            try modelContext.save()
        } catch {
            Logger.persistence.error("Failed to save pin preference: \(error.localizedDescription)")
        }
    }

    func toggleHidden(for monitorId: String, serverConnectionId: UUID) {
        let pref = fetchOrCreatePreference(for: monitorId, serverConnectionId: serverConnectionId)
        pref.hide()
        do {
            try modelContext.save()
        } catch {
            Logger.persistence.error("Failed to save hide preference: \(error.localizedDescription)")
        }
    }

    private func fetchOrCreatePreference(for monitorId: String, serverConnectionId: UUID) -> MonitorPreference {
        let key = MonitorPreference.makeCompositeKey(monitorId: monitorId, serverConnectionId: serverConnectionId)
        let predicate = #Predicate<MonitorPreference> { $0.compositeKey == key }
        var descriptor = FetchDescriptor<MonitorPreference>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            if let existing = try modelContext.fetch(descriptor).first {
                return existing
            }
        } catch {
            Logger.persistence.error("Failed to fetch preference for monitor \(monitorId): \(error.localizedDescription)")
        }

        let pref = MonitorPreference(monitorId: monitorId, serverConnectionId: serverConnectionId)
        modelContext.insert(pref)
        return pref
    }
}
