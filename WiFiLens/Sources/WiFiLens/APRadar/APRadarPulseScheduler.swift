import Foundation

/// Protocol seam for the pulse scheduler so view-model tests can substitute a
/// fake that records start/cancel calls instead of running real timers.
@MainActor
protocol APRadarPulseScheduling: AnyObject {
    var isActive: Bool { get }
    func start(
        shouldContinue: @escaping @MainActor () -> Bool,
        intervalProvider: @escaping @MainActor () -> Duration,
        playPulse: @escaping @MainActor () -> Void,
        stochastic: Bool
    )
    func cancel()
}

extension APRadarPulseScheduling {
    /// Convenience form for deterministic cadence (non-Geiger presets).
    func start(
        shouldContinue: @escaping @MainActor () -> Bool,
        intervalProvider: @escaping @MainActor () -> Duration,
        playPulse: @escaping @MainActor () -> Void
    ) {
        start(
            shouldContinue: shouldContinue,
            intervalProvider: intervalProvider,
            playPulse: playPulse,
            stochastic: false
        )
    }
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
    /// Incremented on every cancel/start. A cancelled loop that wakes up after
    /// a restart can detect that it is stale and must not tear down the newer
    /// loop's state (`isRunning` / `task`).
    private var generation = 0

    /// How often the waiting loop re-evaluates the desired interval so a
    /// stronger signal (shorter interval) takes effect within ~100 ms instead
    /// of only after the previous, longer interval finishes.
    private static let recheckStep: Duration = .milliseconds(100)

    /// Starts (or restarts) the pulse loop. Any previous loop is cancelled
    /// first, so multiple starts never overlap.
    func start(
        shouldContinue: @escaping @MainActor () -> Bool,
        intervalProvider: @escaping @MainActor () -> Duration,
        playPulse: @escaping @MainActor () -> Void,
        stochastic: Bool = false
    ) {
        cancel()
        generation &+= 1
        let token = generation
        isRunning = true
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.generation == token, self.isRunning, shouldContinue() else { break }
                playPulse()
                if stochastic {
                    // Geiger mode: a click that has been scheduled always
                    // fires. Wait out the full randomly drawn interval; a
                    // fresh RSSI sample never pulls it forward. Only
                    // cancellation / mute / stop breaks the wait, and the
                    // next loop draws a new interval from the current mean.
                    let mean = intervalProvider()
                    let drawn = APRadarPulseInterval.nextExponentialInterval(
                        mean: APRadarPulseInterval.seconds(from: mean)
                    )
                    let deadline = ContinuousClock.now.advanced(by: .seconds(drawn))
                    while !Task.isCancelled {
                        guard self.generation == token, self.isRunning, shouldContinue() else { break }
                        let remaining = deadline - ContinuousClock.now
                        guard remaining > .zero else { break }
                        do {
                            try await Task.sleep(for: min(remaining, Self.recheckStep))
                        } catch {
                            break
                        }
                    }
                } else {
                    // Wait in small steps. If a fresh RSSI sample shortens the
                    // desired interval, pull the next pulse forward instead of
                    // sleeping out the old, longer interval.
                    var deadline = ContinuousClock.now.advanced(by: intervalProvider())
                    while !Task.isCancelled {
                        guard self.generation == token, self.isRunning, shouldContinue() else { break }
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
            }
            // Only the current generation may publish its own shutdown. A
            // stale loop that woke after `cancel()` + a fresh `start()` must
            // leave the new loop's state alone.
            guard let self, self.generation == token else { return }
            self.isRunning = false
            self.task = nil
        }
    }

    /// Cancels the current loop immediately. Safe to call repeatedly.
    func cancel() {
        generation &+= 1
        task?.cancel()
        task = nil
        isRunning = false
    }

    /// True when a loop is alive and not yet cancelled.
    var isActive: Bool {
        isRunning && task != nil
    }
}
