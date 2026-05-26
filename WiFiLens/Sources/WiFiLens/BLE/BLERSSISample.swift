import Foundation

/// Single timestamped RSSI reading, stored in per-device ring buffers.
struct BLERSSISample: Sendable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let rawRSSI: Int
    let smoothedRSSI: Double
}
