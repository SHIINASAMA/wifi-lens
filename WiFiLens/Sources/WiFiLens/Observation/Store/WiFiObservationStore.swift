import Foundation

@MainActor
final class WiFiObservationStore: ObservableObject {
    @Published var currentStatus: WiFiCurrentStatus?
    @Published var gatewayLatency: GatewayLatencyResult?
    @Published var quality: WiFiQualityResult?

    @Published var latestEnvironmentSnapshot: WiFiEnvironmentSnapshot?
    @Published var channelAnalysis: [ChannelQuality]?
    @Published var channelRecommendation: [ChannelRecommendation]?

    @Published var diagnosis: DiagnosticResult?
    @Published var recentEvents: [WiFiObservationEvent] = []

    @Published var isRefreshingCurrent = false
    @Published var isScanningEnvironment = false
    @Published var lastUpdated: Date?
    @Published var errors: [WiFiObservationError] = []

    func apply(_ observation: WiFiObservation) {
        if let status = observation.currentStatus {
            currentStatus = status
        }
        if let latency = observation.gatewayLatency {
            gatewayLatency = latency
        }
        if let q = observation.quality {
            quality = q
        }
        if let snapshot = observation.environmentSnapshot {
            latestEnvironmentSnapshot = snapshot
        }
        if let analysis = observation.channelAnalysis {
            channelAnalysis = analysis
        }
        if let recs = observation.channelRecommendation {
            channelRecommendation = recs
        }
        if let diag = observation.diagnosis {
            diagnosis = diag
        }
        if !observation.events.isEmpty {
            let existingIDs = Set(recentEvents.map(\.id))
            let newEvents = observation.events.filter { !existingIDs.contains($0.id) }
            recentEvents.append(contentsOf: newEvents)
            if recentEvents.count > 50 {
                recentEvents = Array(recentEvents.suffix(50))
            }
        }
        if !observation.errors.isEmpty {
            errors.append(contentsOf: observation.errors)
            if errors.count > 20 {
                errors = Array(errors.suffix(20))
            }
        }
        lastUpdated = Date()
    }
}
