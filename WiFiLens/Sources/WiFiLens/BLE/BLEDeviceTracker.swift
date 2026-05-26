import Foundation

/// Per-device ring buffers and EMA smoothing for BLE RSSI tracking.
/// Analogous to SignalHistoryStore but tuned for BLE advertisement patterns.
@MainActor
final class BLEDeviceTracker {
    private var deviceHistories: [UUID: [BLERSSISample]] = [:]
    private var emaFilters: [UUID: ExponentialMovingAverage] = [:]
    private var firstSeenTimestamps: [UUID: Date] = [:]

    let maxHistoryCount: Int
    let emaAlpha: Double
    let staleTimeout: TimeInterval

    init(maxHistoryCount: Int = 30, emaAlpha: Double = 0.25, staleTimeout: TimeInterval = 60) {
        self.maxHistoryCount = maxHistoryCount
        self.emaAlpha = emaAlpha
        self.staleTimeout = staleTimeout
    }

    /// Process a batch of raw advertisement events, returning updated snapshots
    /// with RSSI history attached. Updates internal ring buffers and EMA filters.
    /// Purges devices not seen within staleTimeout.
    func processBatch(
        _ eventsByDevice: [UUID: [BLEAdvertisementEvent]]
    ) -> [BLEDeviceSnapshot] {
        purgeStale()

        var snapshots: [BLEDeviceSnapshot] = []

        for (identifier, events) in eventsByDevice {
            guard let latest = events.max(by: { $0.timestamp < $1.timestamp }),
                  !events.isEmpty else { continue }

            let now = Date()
            if firstSeenTimestamps[identifier] == nil {
                firstSeenTimestamps[identifier] = latest.timestamp
            }

            // RSSI aggregation: use best (strongest) RSSI from this batch
            let bestRSSI = events.map(\.rssi).max() ?? latest.rssi

            // EMA smoothing
            var ema = emaFilters[identifier]
                ?? ExponentialMovingAverage(alpha: emaAlpha, initial: Double(bestRSSI))
            let smoothed = ema.smooth(Double(bestRSSI))
            emaFilters[identifier] = ema

            // Build sample and append to ring buffer
            let sample = BLERSSISample(
                timestamp: now,
                rawRSSI: bestRSSI,
                smoothedRSSI: smoothed
            )

            var history = deviceHistories[identifier] ?? []
            history.append(sample)
            if history.count > maxHistoryCount {
                history.removeFirst(history.count - maxHistoryCount)
            }
            deviceHistories[identifier] = history

            snapshots.append(BLEDeviceSnapshot(
                peripheralIdentifier: identifier,
                localName: latest.localName,
                rssi: bestRSSI,
                smoothedRSSI: smoothed,
                txPower: latest.txPower,
                isConnectable: latest.isConnectable,
                firstSeen: firstSeenTimestamps[identifier] ?? latest.timestamp,
                lastSeen: latest.timestamp,
                advertisementCount: events.count,
                rssiHistory: history,
                manufacturerData: latest.manufacturerData
            ))
        }

        return snapshots
    }

    /// RSSI history for a specific device (for chart rendering).
    func rssiHistory(for identifier: UUID) -> [BLERSSISample]? {
        guard let history = deviceHistories[identifier], history.count >= 2 else {
            return nil
        }
        return history
    }

    /// Remove devices not seen within the stale timeout.
    func purgeStale() {
        let cutoff = Date().addingTimeInterval(-staleTimeout)
        let stale = deviceHistories.filter { _, samples in
            guard let last = samples.last else { return true }
            return last.timestamp < cutoff
        }
        for (id, _) in stale {
            deviceHistories.removeValue(forKey: id)
            emaFilters.removeValue(forKey: id)
            firstSeenTimestamps.removeValue(forKey: id)
        }
    }
}
