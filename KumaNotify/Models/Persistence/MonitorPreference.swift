import Foundation
import SwiftData

@Model
final class MonitorPreference {
    @Attribute(.unique) var compositeKey: String
    var monitorId: String
    var serverConnectionId: UUID
    var isPinned: Bool
    var isHidden: Bool

    static func makeCompositeKey(monitorId: String, serverConnectionId: UUID) -> String {
        "\(serverConnectionId.uuidString):\(monitorId)"
    }

    init(
        monitorId: String,
        serverConnectionId: UUID,
        isPinned: Bool = false,
        isHidden: Bool = false
    ) {
        self.compositeKey = Self.makeCompositeKey(monitorId: monitorId, serverConnectionId: serverConnectionId)
        self.monitorId = monitorId
        self.serverConnectionId = serverConnectionId
        self.isPinned = isPinned
        self.isHidden = isHidden
    }

    func pin() {
        isPinned.toggle()
        if isPinned { isHidden = false }
    }

    func hide() {
        isHidden.toggle()
        if isHidden { isPinned = false }
    }
}
