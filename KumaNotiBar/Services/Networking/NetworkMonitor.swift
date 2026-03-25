import Foundation
import Network

@Observable
final class NetworkMonitor: @unchecked Sendable {
    var isConnected = true
    var isExpensive = false
    var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.molinesdesigns.kumanotibar.networkmonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                if path.availableInterfaces.isEmpty {
                    self?.connectionType = nil
                } else {
                    self?.connectionType = path.availableInterfaces.first?.type
                }
            }
        }
    }

    func start() {
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
