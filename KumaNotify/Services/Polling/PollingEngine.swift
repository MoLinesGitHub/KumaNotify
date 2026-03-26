import Foundation

@Observable
@MainActor
final class PollingEngine {
    var lastPollTime: Date?
    var isPolling = false
    var consecutiveFailures = 0

    private var timer: Timer?
    private var pollAction: (@Sendable () async -> Void)?

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

        let currentAction = pollAction
        timer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.executePoll(currentAction)
            }
        }

        Task {
            await executePoll(currentAction)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
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
        consecutiveFailures = 0
    }

    func reportFailure() {
        consecutiveFailures += 1
    }

    var effectiveInterval: TimeInterval {
        guard consecutiveFailures > 0 else { return interval }
        let backoff = interval * pow(2, Double(min(consecutiveFailures, 5)))
        return min(backoff, 300)
    }
}
