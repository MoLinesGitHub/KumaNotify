import Foundation
import SwiftData

@Model
final class MonitorPreference {
    @Attribute(.unique) var monitorId: String
    var serverConnectionId: UUID
    var isPinned: Bool
    var isHidden: Bool

    init(
        monitorId: String,
        serverConnectionId: UUID,
        isPinned: Bool = false,
        isHidden: Bool = false
    ) {
        self.monitorId = monitorId
        self.serverConnectionId = serverConnectionId
        self.isPinned = isPinned
        self.isHidden = isHidden
    }
}
