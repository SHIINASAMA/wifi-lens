import Foundation

struct WiFiObservationEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    var timestamp: Date
    var type: EventType
    var details: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: EventType,
        details: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.details = details
    }

    enum EventType: Equatable, Sendable {
        case bssidChange(from: String, to: String)
        case disconnection
        case reconnection
        case signalDrop(from: Int, to: Int)
        case latencySpike(from: Double, to: Double)
        case channelChange(from: Int, to: Int)
    }
}
