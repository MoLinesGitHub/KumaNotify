import Foundation
import Network

@MainActor
@Observable
final class NetworkMonitor {
    var isConnected = true
    var isExpensive = false
    var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.molinesdesigns.kumanotibar.networkmonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.applyPathUpdate(
                    status: path.status,
                    isExpensive: path.isExpensive,
                    connectionType: path.availableInterfaces.first?.type
                )
            }
        }
    }

    func start() {
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    func applyPathUpdate(
        status: NWPath.Status,
        isExpensive: Bool,
        connectionType: NWInterface.InterfaceType?
    ) {
        isConnected = status == .satisfied
        self.isExpensive = isExpensive
        self.connectionType = connectionType
    }
}
