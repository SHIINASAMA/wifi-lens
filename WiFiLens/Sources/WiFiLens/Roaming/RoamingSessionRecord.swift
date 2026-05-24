import Foundation

struct RoamingSessionRecord: Codable {
    let version: Int
    let savedAt: Date
    let ssid: String
    let bssid: String?
    let phyMode: String?
    let channel: Int
    let duration: TimeInterval
    let segments: [RoamingSegment]
    let transitions: [APTransitionEvent]

    static let currentVersion = 1
}
