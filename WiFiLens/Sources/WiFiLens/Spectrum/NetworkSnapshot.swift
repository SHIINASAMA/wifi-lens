import Foundation

/// A lightweight snapshot of a single network from one scan moment.
/// Stored per BSSID for trend charts and future data export.
struct NetworkSnapshot: Codable {
    let timestamp: Date
    let bssid: String
    let ssid: String
    let rssi: Int
    let channel: Int
    let band: String
    let phyMode: String
    let channelWidth: String
    let mcs: String
    let nss: String
    let security: String
    let country: String
    let supportsK: Bool
    let supportsR: Bool
    let supportsV: Bool
    let supportsWPA3: Bool
    let isHiddenSSID: Bool
}
