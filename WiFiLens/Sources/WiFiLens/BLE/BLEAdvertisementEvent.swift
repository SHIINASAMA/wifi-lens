import Foundation

/// Raw advertisement event from a single CoreBluetooth `didDiscover` callback.
struct BLEAdvertisementEvent: Sendable {
    let timestamp: Date
    let peripheralIdentifier: UUID
    let localName: String?
    let rssi: Int
    let txPower: Int?
    let manufacturerData: Data?
    let serviceUUIDs: [String]?
    let isConnectable: Bool
}
