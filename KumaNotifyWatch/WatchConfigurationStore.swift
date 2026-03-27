import Foundation
import Observation

@Observable
@MainActor
final class WatchConfigurationStore {
    private let defaults: UserDefaults

    var connection: ServerConnection?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.connection = Self.readConnection(from: defaults)
    }

    func draftConnection(
        name: String,
        baseURLString: String,
        statusPageSlug: String
    ) -> ServerConnection? {
        guard let baseURL = ServerConnection.validatedBaseURL(from: baseURLString),
              let slug = ServerConnection.validatedStatusPageSlug(from: statusPageSlug)
        else {
            return nil
        }

        return ServerConnection(
            id: connection?.id ?? UUID(),
            name: ServerConnection.normalizedDisplayName(from: name),
            baseURL: baseURL,
            statusPageSlug: slug,
            isDefault: true
        )
    }

    func save(_ connection: ServerConnection) {
        self.connection = connection
        persistConnection(connection)
    }

    func clear() {
        connection = nil
        defaults.removeObject(forKey: AppConstants.watchConnectionDefaultsKey)
    }

    private func persistConnection(_ connection: ServerConnection) {
        if let data = try? JSONEncoder().encode(connection) {
            defaults.set(data, forKey: AppConstants.watchConnectionDefaultsKey)
        }
    }

    private static func readConnection(from defaults: UserDefaults) -> ServerConnection? {
        guard let data = defaults.data(forKey: AppConstants.watchConnectionDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(ServerConnection.self, from: data)
    }
}
