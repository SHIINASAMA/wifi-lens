import Foundation

struct RoamingSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let rssi: Int
    let channel: Int
    let txRate: Double
    var gatewayLatency: Double?
}

struct RoamingSegment: Identifiable {
    let id = UUID()
    let bssid: String
    let startTime: Date
    var endTime: Date?
    var samples: [RoamingSample] = []

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

struct APTransitionEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let fromBSSID: String
    let toBSSID: String
    let rssiBefore: Int
    let rssiAfter: Int
    let channelBefore: Int
    let channelAfter: Int
}
