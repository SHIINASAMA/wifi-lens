import Foundation

struct WiFiObservation: Equatable, Sendable {
    var timestamp: Date
    var currentStatus: WiFiCurrentStatus?
    var environmentSnapshot: WiFiEnvironmentSnapshot?
    var gatewayLatency: GatewayLatencyResult?
    var quality: WiFiQualityResult?
    var channelAnalysis: [ChannelQuality]?
    var channelRecommendation: [ChannelRecommendation]?
    var diagnosis: DiagnosticResult?
    var events: [WiFiObservationEvent]
    var errors: [WiFiObservationError]

    init(
        timestamp: Date = Date(),
        currentStatus: WiFiCurrentStatus? = nil,
        environmentSnapshot: WiFiEnvironmentSnapshot? = nil,
        gatewayLatency: GatewayLatencyResult? = nil,
        quality: WiFiQualityResult? = nil,
        channelAnalysis: [ChannelQuality]? = nil,
        channelRecommendation: [ChannelRecommendation]? = nil,
        diagnosis: DiagnosticResult? = nil,
        events: [WiFiObservationEvent] = [],
        errors: [WiFiObservationError] = []
    ) {
        self.timestamp = timestamp
        self.currentStatus = currentStatus
        self.environmentSnapshot = environmentSnapshot
        self.gatewayLatency = gatewayLatency
        self.quality = quality
        self.channelAnalysis = channelAnalysis
        self.channelRecommendation = channelRecommendation
        self.diagnosis = diagnosis
        self.events = events
        self.errors = errors
    }

    static func == (lhs: WiFiObservation, rhs: WiFiObservation) -> Bool {
        lhs.timestamp == rhs.timestamp &&
        lhs.currentStatus == rhs.currentStatus &&
        lhs.environmentSnapshot == rhs.environmentSnapshot &&
        lhs.gatewayLatency == rhs.gatewayLatency &&
        lhs.quality == rhs.quality &&
        lhs.diagnosis == rhs.diagnosis &&
        lhs.events == rhs.events &&
        lhs.errors == rhs.errors &&
        (lhs.channelAnalysis?.count == rhs.channelAnalysis?.count) &&
        (lhs.channelRecommendation?.count == rhs.channelRecommendation?.count)
    }
}
