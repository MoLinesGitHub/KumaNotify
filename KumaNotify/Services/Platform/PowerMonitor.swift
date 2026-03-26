import Foundation
import IOKit.ps

@Observable
@MainActor
final class PowerMonitor {
    private(set) var isOnBattery = false
    private(set) var batteryLevel: Double = 1.0

    private var runLoopSource: CFRunLoopSource?

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
            // Desktop Mac or no battery info — treat as AC
            isOnBattery = false
            batteryLevel = 1.0
            return
        }

        let powerSource = desc[kIOPSPowerSourceStateKey] as? String ?? ""
        isOnBattery = (powerSource == kIOPSBatteryPowerValue)

        if let capacity = desc[kIOPSCurrentCapacityKey] as? Int,
           let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int,
           maxCapacity > 0 {
            batteryLevel = Double(capacity) / Double(maxCapacity)
        }
    }
}
