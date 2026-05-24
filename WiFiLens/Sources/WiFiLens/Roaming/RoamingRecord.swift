import Foundation

struct RoamingSample: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let rssi: Int
    let channel: Int
    let txRate: Double
    var gatewayLatency: Double?

    enum CodingKeys: String, CodingKey {
        case timestamp, rssi, channel, txRate, gatewayLatency
    }
}

struct RoamingSegment: Identifiable, Codable {
    let id = UUID()
    let bssid: String
    let startTime: Date
    var endTime: Date?
    var samples: [RoamingSample] = []

    enum CodingKeys: String, CodingKey {
        case bssid, startTime, endTime, samples
    }

    var rssiRange: (min: Int, max: Int) {
        guard !samples.isEmpty else { return (-100, -30) }
        let values = samples.map(\.rssi)
        return (values.min() ?? -100, values.max() ?? -30)
    }

    var duration: TimeInterval {
        let end = endTime ?? samples.last?.timestamp ?? startTime
        return end.timeIntervalSince(startTime)
    }
}

struct APTransitionEvent: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let fromBSSID: String
    let toBSSID: String
    let rssiBefore: Int
    let rssiAfter: Int
    let channelBefore: Int
    let channelAfter: Int

    enum CodingKeys: String, CodingKey {
        case timestamp, fromBSSID, toBSSID, rssiBefore, rssiAfter, channelBefore, channelAfter
    }
}
