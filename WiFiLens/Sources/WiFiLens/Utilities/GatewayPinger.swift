import Foundation

actor GatewayPinger {
    /// Overall budget for a single ping, including process startup. Kept just
    /// above the `-W 1000` ping timeout so an unreachable gateway is normally
    /// reported by the process itself, while still bounding the wait if the
    /// process ever hangs.
    private static let pingTimeout: Duration = .milliseconds(1500)

    private var lastTask: Task<Double?, Never>?
    private var currentProcess: Process?

    func ping(host: String) async -> Double? {
        lastTask?.cancel()
        currentProcess?.terminate()

        let task = Task<Double?, Never> { [host] in
            await self.runPing(host: host)
        }
        lastTask = task
        return await task.value
    }

    private func runPing(host: String) async -> Double? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-W", "1000", host]

        let pipe = Pipe()
        process.standardOutput = pipe

        currentProcess = process

        do {
            try process.run()
        } catch {
            return nil
        }

        guard await Self.waitForExit(process) == 0,
              !Task.isCancelled
        else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        for line in output.components(separatedBy: "\n") {
            if line.contains("time=") {
                if let range = line.range(of: "time=") {
                    let rest = line[range.upperBound...]
                    let msStr = rest.components(separatedBy: " ").first ?? ""
                    return Double(msStr)
                }
            }
        }
        return nil
    }

    /// Waits for `process` to finish without blocking the actor executor.
    /// Returns the process termination status. Cancellation terminates the
    /// process immediately so the caller gets `nil` quickly instead of waiting
    /// out the ping timeout; a timeout task is the backstop if the process
    /// hangs.
    private static func waitForExit(_ process: Process) async -> Int32 {
        let state = PingWaitState(process: process)

        let timeoutTask = Task { [state] in
            do {
                try await Task.sleep(for: Self.pingTimeout)
            } catch {
                return // Cancelled; the wait already completed.
            }
            state.terminate()
        }

        let status = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Int32, Never>) in
                state.process.terminationHandler = { [state] terminatedProcess in
                    _ = state.resumeIfNeeded(continuation, status: terminatedProcess.terminationStatus)
                }
                // Cover the race where the process exited before the handler
                // was installed.
                if !state.process.isRunning {
                    _ = state.resumeIfNeeded(continuation, status: state.process.terminationStatus)
                }
            }
        } onCancel: {
            state.terminate()
        }

        timeoutTask.cancel()
        return status
    }
}

/// Thread-safe bridge between the process's `terminationHandler`, the
/// cancellation/timeout paths, and the continuation. `Process` is not
/// `Sendable`, so it is boxed here; every cross-thread access goes through
/// this state object.
private final class PingWaitState: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    let process: Process

    init(process: Process) {
        self.process = process
    }

    /// Sends SIGTERM to the ping process. Safe to call from any thread.
    func terminate() {
        process.terminate()
    }

    /// Resumes `continuation` exactly once and clears the termination handler
    /// to break the retain cycle. Returns `true` when this call performed the
    /// resume, `false` when another path already did.
    func resumeIfNeeded(_ continuation: CheckedContinuation<Int32, Never>, status: Int32) -> Bool {
        lock.lock()
        if didResume {
            lock.unlock()
            return false
        }
        didResume = true
        process.terminationHandler = nil
        lock.unlock()
        continuation.resume(returning: status)
        return true
    }
}
