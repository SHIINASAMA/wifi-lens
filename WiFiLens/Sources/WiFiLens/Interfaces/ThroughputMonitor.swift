import Foundation
import Darwin

struct ThroughputSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bytesIn: UInt64
    let bytesOut: UInt64
    let rateIn: Double   // bytes/sec
    let rateOut: Double  // bytes/sec
}

@MainActor
@Observable
final class ThroughputMonitor {
    private(set) var perInterface: [String: [ThroughputSample]] = [:]
    private(set) var isRunning = false
    private var lastCounters: [String: (in: UInt64, out: UInt64, ts: Date)] = [:]
    private var pollTask: Task<Void, Never>?

    static let maxSamples = 90          // retain 90 s
    private static let cleanupInterval = 60  // purge stale ifaces every 60 polls
    private var pollCount = 0

    func start() {
        guard !isRunning else { return }
        isRunning = true
        pollCount = 0
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                sample()
                pollCount += 1
                if pollCount % Self.cleanupInterval == 0 {
                    purgeStaleInterfaces()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
        Log.throughput.info("started")
    }

    func stop() {
        isRunning = false
        pollTask?.cancel()
        pollTask = nil
        lastCounters.removeAll()
        perInterface.removeAll()
        Log.throughput.info("stopped")
    }

    func samples(for name: String) -> [ThroughputSample] {
        perInterface[name] ?? []
    }

    private func purgeStaleInterfaces() {
        let now = Date()
        perInterface = perInterface.filter { _, history in
            guard let last = history.last else { return false }
            return now.timeIntervalSince(last.timestamp) < 120  // gone for 2 min → drop
        }
    }

    /// Interfaces that have generated non-zero traffic
    var activeInterfaces: [String] {
        perInterface.compactMap { name, samples in
            samples.contains(where: { $0.rateIn > 0 || $0.rateOut > 0 }) ? name : nil
        }
    }

    private func sample() {
        var addrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrPtr) == 0, let first = addrPtr else { return }
        defer { freeifaddrs(first) }

        let now = Date()

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let namePtr = ptr.pointee.ifa_name else { continue }
            let name = String(cString: namePtr)

            // Only capture real hardware interfaces with byte counters
            guard let data = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            let bytesIn = UInt64(data.pointee.ifi_ibytes)
            let bytesOut = UInt64(data.pointee.ifi_obytes)

            let prev = lastCounters[name]
            let elapsed = prev.map { now.timeIntervalSince($0.ts) } ?? 1.0
            let deltaIn = prev.map { Double(bytesIn - $0.in) / max(0.1, elapsed) } ?? 0
            let deltaOut = prev.map { Double(bytesOut - $0.out) / max(0.1, elapsed) } ?? 0

            lastCounters[name] = (in: bytesIn, out: bytesOut, ts: now)

            let sample = ThroughputSample(
                timestamp: now,
                bytesIn: bytesIn,
                bytesOut: bytesOut,
                rateIn: max(0, deltaIn),
                rateOut: max(0, deltaOut)
            )

            var history = perInterface[name] ?? []
            history.append(sample)
            if history.count > Self.maxSamples {
                history = Array(history.suffix(Self.maxSamples))
            }
            perInterface[name] = history
        }
    }
}
