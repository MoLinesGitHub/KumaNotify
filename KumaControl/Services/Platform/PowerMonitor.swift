import Foundation
import IOKit.ps

@Observable
@MainActor
final class PowerMonitor {
    private(set) var isOnBattery = false
    private(set) var batteryLevel: Double = 1.0

    @ObservationIgnored
    nonisolated(unsafe) private var runLoopSource: CFRunLoopSource?

    func start() {
        updatePowerState()

        let context = Unmanaged.passRetained(self).toOpaque()
        runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                monitor.updatePowerState()
            }
        }, context).takeRetainedValue()

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            // Release the retained self from start()
            Unmanaged<PowerMonitor>.passUnretained(self).release()
            runLoopSource = nil
        }
    }

    private func updatePowerState() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first as CFTypeRef)?.takeUnretainedValue() as? [String: Any]
        else {
            applyPowerState(from: nil)
            return
        }

        applyPowerState(from: desc)
    }

    func applyPowerState(from description: [String: Any]?) {
        let state = Self.normalizedPowerState(from: description)
        isOnBattery = state.isOnBattery
        batteryLevel = state.batteryLevel
    }

    nonisolated static func normalizedPowerState(from description: [String: Any]?) -> (isOnBattery: Bool, batteryLevel: Double) {
        guard let description else {
            // Desktop Mac or no battery info — treat as AC
            return (false, 1.0)
        }

        let powerSource = description[kIOPSPowerSourceStateKey] as? String ?? ""
        let isOnBattery = (powerSource == kIOPSBatteryPowerValue)

        if let capacity = description[kIOPSCurrentCapacityKey] as? Int,
           let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
           maxCapacity > 0 {
            return (isOnBattery, Double(capacity) / Double(maxCapacity))
        }

        return (isOnBattery, 1.0)
    }
}
