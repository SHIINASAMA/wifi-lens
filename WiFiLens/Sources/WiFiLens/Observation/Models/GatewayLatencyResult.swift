import Foundation

struct GatewayLatencyResult: Equatable, Sendable {
    var timestamp: Date
    var routerIP: String?
    var latencyMs: Double?
    var packetLoss: Double?
    var error: WiFiObservationError?
}
