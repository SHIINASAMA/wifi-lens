import Foundation

enum TrendDirection { case up, down, stable }

/// Retains recent RSSI readings and full network snapshots per BSSID
/// for trend indication, chart history, and future data export.
/// All access is on @MainActor so no locking is needed.
@MainActor
final class SignalHistoryStore {
    private var history: [String: [Int]] = [:]
    private var snapshots: [String: [NetworkSnapshot]] = [:]
    private var scanTimestamps: [Date] = []
    private let maxCount: Int
    private let scanWindow: TimeInterval

    init(maxCount: Int = 20, scanWindow: TimeInterval = 60) {
        self.maxCount = maxCount
        self.scanWindow = max(0, scanWindow)
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

    func recordScan(timestamp: Date) {
        guard !scanTimestamps.contains(timestamp) else { return }
        scanTimestamps.append(timestamp)
        let latest = scanTimestamps.max() ?? timestamp
        let cutoff = latest.addingTimeInterval(-scanWindow)
        scanTimestamps = scanTimestamps
            .filter { $0 >= cutoff }
            .sorted()
        if scanTimestamps.count > maxCount {
            scanTimestamps = Array(scanTimestamps.suffix(maxCount))
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

    /// All RSSI history (unfiltered). OSS tree: test-only references.
    /// NOTE (DD-5, 2026-08-16): keep in sync with the allSnapshots contract.
    var allHistory: [String: [Int]] { history }

    /// All snapshots (unfiltered) — cross-edition contract.
    /// NOTE (DD-5, 2026-08-16): consumed by the Pro recording feature as its
    /// per-tick snapshot source. This is NOT dead or reserved API: changes must
    /// be verified against both the OSS and Pro schemes (verify.sh). The
    /// earlier "for session persistence" comment was misleading; re-evaluate
    /// naming when the session model is designed.
    var allSnapshots: [String: [NetworkSnapshot]] { snapshots }

    /// Successful scan-cycle timestamps (oldest first), bounded independently
    /// from per-BSSID snapshot retention so empty successful scans can still
    /// participate in shared-history consumers such as the heatmap.
    var allScanTimestamps: [Date] { scanTimestamps }
}
