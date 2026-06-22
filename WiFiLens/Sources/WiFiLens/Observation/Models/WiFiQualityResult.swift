import Foundation

struct WiFiQualityResult: Equatable, Sendable {
    var level: WiFiQualityLevel
    var signalLabel: String
    var latencyLabel: String
    var summary: String
}

enum WiFiQualityLevel: String, Sendable, CaseIterable {
    case good, fair, poor, unknown

    var displayName: String {
        switch self {
        case .good:    String(localized: "observation.quality.good", comment: "Good quality level")
        case .fair:    String(localized: "observation.quality.fair", comment: "Fair quality level")
        case .poor:    String(localized: "observation.quality.poor", comment: "Poor quality level")
        case .unknown: String(localized: "observation.quality.unknown", comment: "Unknown quality level")
        }
    }
}
