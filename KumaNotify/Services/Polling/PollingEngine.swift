import Foundation

@Observable
@MainActor
final class PollingEngine {
    var lastPollTime: Date?
    var isPolling = false
    var consecutiveFailures = 0

    private var timer: Timer?
    private var pollAction: (@Sendable () async -> Void)?
    private var scheduledInterval: TimeInterval?

    var interval: TimeInterval = AppConstants.defaultPollingInterval {
        didSet {
            guard interval != oldValue, timer != nil, pollAction != nil else { return }
            stop()
            start()
        }
    }

    func start(action: @escaping @Sendable () async -> Void) {
        self.pollAction = action
        start()
    }

    func start() {
        stop()
        guard let pollAction else { return }

        scheduleTimer(for: pollAction)

        Task {
            await executePoll(pollAction)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        scheduledInterval = nil
    }

    func forceRefresh() {
        guard let pollAction else { return }
        Task {
            await executePoll(pollAction)
        }
    }

    private func executePoll(_ action: @Sendable () async -> Void) async {
        guard !isPolling else { return }
        isPolling = true
        await action()
        lastPollTime = Date()
        isPolling = false
    }

    func reportSuccess() {
        let previousInterval = effectiveInterval
        consecutiveFailures = 0
        rescheduleTimerIfNeeded(previousInterval: previousInterval)
    }

    func reportFailure() {
        let previousInterval = effectiveInterval
        consecutiveFailures += 1
        rescheduleTimerIfNeeded(previousInterval: previousInterval)
    }

    var effectiveInterval: TimeInterval {
        guard consecutiveFailures > 0 else { return interval }
        let backoff = interval * pow(2, Double(min(consecutiveFailures, 5)))
        return min(backoff, 300)
    }

    var scheduledTimerInterval: TimeInterval? {
        scheduledInterval
    }

    private func scheduleTimer(for action: @escaping @Sendable () async -> Void) {
        let interval = effectiveInterval
        scheduledInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.executePoll(action)
            }
        }
    }

    private func rescheduleTimerIfNeeded(previousInterval: TimeInterval) {
        guard let pollAction, timer != nil else { return }

        let nextInterval = effectiveInterval
        guard nextInterval != previousInterval else { return }

        timer?.invalidate()
        timer = nil
        scheduleTimer(for: pollAction)
    }
}
