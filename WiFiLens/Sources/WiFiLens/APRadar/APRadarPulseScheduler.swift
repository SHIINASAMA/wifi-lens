import Foundation

/// Protocol seam for the pulse scheduler so view-model tests can substitute a
/// fake that records start/cancel calls instead of running real timers.
@MainActor
protocol APRadarPulseScheduling: AnyObject {
    var isActive: Bool { get }
    func start(
        shouldContinue: @escaping @MainActor () -> Bool,
        intervalProvider: @escaping @MainActor () -> Duration,
        playPulse: @escaping @MainActor () -> Void
    )
    func cancel()
}

/// Owns the single sound-pulse scheduling task. It plays one pulse, waits for
/// the interval computed from the latest smoothed RSSI, then re-checks whether
/// it should continue. At most one task exists at any time.
///
/// The scheduler holds no business state: continuation, interval, and pulse
/// behavior are injected by the view model.
@MainActor
final class APRadarPulseScheduler: APRadarPulseScheduling {
    private var task: Task<Void, Never>?
    private(set) var isRunning = false

    /// How often the waiting loop re-evaluates the desired interval so a
    /// stronger signal (shorter interval) takes effect within ~100 ms instead
    /// of only after the previous, longer interval finishes.
    private static let recheckStep: Duration = .milliseconds(100)

    /// Starts (or restarts) the pulse loop. Any previous loop is cancelled
    /// first, so multiple starts never overlap.
    func start(
        shouldContinue: @escaping @MainActor () -> Bool,
        intervalProvider: @escaping @MainActor () -> Duration,
        playPulse: @escaping @MainActor () -> Void
    ) {
        cancel()
        isRunning = true
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning, shouldContinue() else { break }
                playPulse()
                // Wait in small steps. If a fresh RSSI sample shortens the
                // desired interval, pull the next pulse forward instead of
                // sleeping out the old, longer interval.
                var deadline = ContinuousClock.now.advanced(by: intervalProvider())
                while !Task.isCancelled {
                    guard self.isRunning, shouldContinue() else { break }
                    let remaining = deadline - ContinuousClock.now
                    guard remaining > .zero else { break }
                    do {
                        try await Task.sleep(for: min(remaining, Self.recheckStep))
                    } catch {
                        break
                    }
                    let desired = intervalProvider()
                    let pulledIn = ContinuousClock.now.advanced(by: desired)
                    if pulledIn < deadline {
                        deadline = pulledIn
                    }
                }
            }
            self?.isRunning = false
            self?.task = nil
        }
    }

    /// Cancels the current loop immediately. Safe to call repeatedly.
    func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    /// True when a loop is alive and not yet cancelled.
    var isActive: Bool {
        isRunning && task != nil
    }
}
