import Foundation

enum TrendDirection { case up, down, stable }

/// Retains recent RSSI readings and full network snapshots per BSSID
/// for trend indication, chart history, and future data export.
/// All access is on @MainActor so no locking is needed.
@MainActor
final class SignalHistoryStore {
    private var history: [String: [Int]] = [:]
    private var snapshots: [String: [NetworkSnapshot]] = [:]
    private let maxCount: Int

    init(maxCount: Int = 20) {
        self.maxCount = maxCount
    }

    func record(bssid: String, rssi: Int, snapshot: NetworkSnapshot? = nil) {
        // RSSI
        var entries = history[bssid] ?? []
        entries.append(rssi)
        if entries.count > maxCount {
            entries.removeFirst(entries.count - maxCount)
        }
        history[bssid] = entries

        // Snapshot
        if let snap = snapshot {
            var snaps = snapshots[bssid] ?? []
            snaps.append(snap)
            if snaps.count > maxCount {
                snaps.removeFirst(snaps.count - maxCount)
            }
            snapshots[bssid] = snaps
        }
    }

    /// Compare latest reading against the one before it.
    func trend(for bssid: String) -> (direction: TrendDirection, delta: Int)? {
        guard let entries = history[bssid], entries.count >= 2 else { return nil }
        let prev = entries[entries.count - 2]
        let curr = entries[entries.count - 1]
        let delta = curr - prev
        switch delta {
        case 2...:      return (.up, delta)
        case ...(-2):   return (.down, delta)
        default:        return (.stable, delta)
        }
    }

    /// Raw RSSI history (oldest first) for chart rendering.
    func rssiHistory(for bssid: String) -> [Int]? {
        guard let entries = history[bssid], entries.count >= 2 else { return nil }
        return entries
    }

    /// Full snapshots (oldest first) for the trend time-series chart and export.
    func snapshotHistory(for bssid: String) -> [NetworkSnapshot]? {
        guard let snaps = snapshots[bssid], snaps.count >= 2 else { return nil }
        return snaps
    }

    /// All RSSI history (unfiltered) for session persistence.
    var allHistory: [String: [Int]] { history }

    /// All snapshots (unfiltered) for session persistence.
    var allSnapshots: [String: [NetworkSnapshot]] { snapshots }
}
