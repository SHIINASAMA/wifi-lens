import Foundation

struct WiFiEnvironmentSnapshot: Equatable, Sendable {
    var timestamp: Date
    var interfaceName: String?
    var networks: [WiFiNetworkObservation]
    var scanDurationMs: Double?
    var error: WiFiObservationError?
}
