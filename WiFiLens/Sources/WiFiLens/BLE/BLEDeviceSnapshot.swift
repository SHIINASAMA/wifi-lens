import Foundation

/// Processed device state emitted each batch window. Used directly by the UI.
struct BLEDeviceSnapshot: Sendable, Identifiable {
    var id: String { peripheralIdentifier.uuidString }

    let peripheralIdentifier: UUID
    let localName: String?
    let rssi: Int
    let smoothedRSSI: Double
    let txPower: Int?
    let isConnectable: Bool
    let firstSeen: Date
    let lastSeen: Date
    let advertisementCount: Int
    let rssiHistory: [BLERSSISample]
    let manufacturerData: Data?

    var displayName: String {
        localName ?? peripheralIdentifier.uuidString
    }

    /// Shortened identifier for compact display (first 8 chars of UUID).
    var shortIdentifier: String {
        let uuid = peripheralIdentifier.uuidString
        return String(uuid.prefix(8))
    }
}
