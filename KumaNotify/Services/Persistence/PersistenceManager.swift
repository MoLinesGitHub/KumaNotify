import Foundation
import SwiftData

@ModelActor
public actor PersistenceManager {
    
    public init(isStoredInMemoryOnly: Bool = false) throws {
        let schema = Schema([IncidentRecord.self, MonitorPreference.self])
        let config = ModelConfiguration(
            "KumaNotify",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        self.init(modelContainer: container)
    }

    // MARK: - Incident Records

    public func recordIncident(_ record: IncidentRecord) {
        // Deduplication: skip if same monitor+transition within 60s
        let windowStart = record.timestamp.addingTimeInterval(-60)

        do {
            var recentDescriptor = FetchDescriptor<IncidentRecord>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            recentDescriptor.fetchLimit = 25

            let recent = try modelContext.fetch(recentDescriptor)
            let isDuplicate = recent.contains {
                $0.monitorId == record.monitorId &&
                $0.serverConnectionId == record.serverConnectionId &&
                $0.transitionType == record.transitionType &&
                $0.timestamp > windowStart
            }

            if isDuplicate {
                print("Persistence: Skipping duplicate incident for monitor \(record.monitorId)")
                return
            }
        } catch {
            print("Persistence: Dedup check failed for monitor \(record.monitorId): \(error.localizedDescription)")
        }

        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            print("Persistence: Failed to save incident for '\(record.monitorName)': \(error.localizedDescription)")
            modelContext.delete(record)
        }
    }

    public func fetchRecentIncidents(
        serverConnectionId: UUID? = nil,
        limit: Int = 100
    ) -> [IncidentRecord] {
        do {
            let descriptor: FetchDescriptor<IncidentRecord>
            if let serverConnectionId {
                let predicate = #Predicate<IncidentRecord> { $0.serverConnectionId == serverConnectionId }
                descriptor = FetchDescriptor(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor(
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            }

            var boundedDescriptor = descriptor
            boundedDescriptor.fetchLimit = limit
            return try modelContext.fetch(boundedDescriptor)
        } catch {
            print("Persistence: Failed to fetch incidents: \(error.localizedDescription)")
            return []
        }
    }

    public func purgeOldIncidents(olderThan days: Int = 30) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            print("Persistence: Failed to calculate purge cutoff date")
            return
        }
        let predicate = #Predicate<IncidentRecord> { $0.timestamp < cutoff }
        do {
            try modelContext.delete(model: IncidentRecord.self, where: predicate)
            try modelContext.save()
        } catch {
            print("Persistence: Failed to purge old incidents: \(error.localizedDescription)")
        }
    }

    // MARK: - Monitor Preferences

    public func fetchAllPreferences() -> [String: MonitorPreference] {
        let descriptor = FetchDescriptor<MonitorPreference>()
        do {
            let results = try modelContext.fetch(descriptor)
            return Dictionary(results.map { ($0.compositeKey, $0) }, uniquingKeysWith: { _, new in new })
        } catch {
            print("Persistence: Failed to fetch preferences: \(error.localizedDescription)")
            return [:]
        }
    }

    public func togglePin(for monitorId: String, serverConnectionId: UUID) {
        let pref = fetchOrCreatePreference(for: monitorId, serverConnectionId: serverConnectionId)
        pref.pin()
        do {
            try modelContext.save()
        } catch {
            print("Persistence: Failed to save pin preference: \(error.localizedDescription)")
        }
    }

    public func toggleHidden(for monitorId: String, serverConnectionId: UUID) {
        let pref = fetchOrCreatePreference(for: monitorId, serverConnectionId: serverConnectionId)
        pref.hide()
        do {
            try modelContext.save()
        } catch {
            print("Persistence: Failed to save hide preference: \(error.localizedDescription)")
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
            print("Persistence: Failed to fetch preference for monitor \(monitorId): \(error.localizedDescription)")
        }

        let pref = MonitorPreference(monitorId: monitorId, serverConnectionId: serverConnectionId)
        modelContext.insert(pref)
        return pref
    }
}
