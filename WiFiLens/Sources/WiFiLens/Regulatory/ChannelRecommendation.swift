import Foundation

/// The output of the regulatory-aware channel recommendation pipeline.
/// Wraps raw RF scoring with all downstream filtering results.
/// Preserves the original RF score, quality level, and AP counts verbatim.
struct ChannelRecommendation: Identifiable, Sendable {
    // MARK: - Original RF fields (preserved from ChannelQuality)

    let channel: Int
    let band: String
    let bandDisplay: String
    let rfScore: Int
    let rfLevel: ChannelQuality.QualityLevel
    let apCount: Int
    let coChannelCount: Int
    let adjacentCount: Int
    let interferenceScore: Int
    let overlapLevel: ChannelQuality.OverlapLevel
    let strongestNeighborRSSI: Int
    var isCurrentChannel: Bool = false
    var showInSimpleView: Bool = true

    /// Original RF recommendation (top-2 per band, score ≥ 70).
    /// Distinct from `classification` — a channel can be RF-recommended but
    /// regulatory-advanced (e.g., DFS), or RF-good and regulatory-recommended.
    var rfIsRecommended: Bool = false

    var id: String { "\(band)-\(channel)" }

    // MARK: - Classification

    enum Classification: String, Sendable, CaseIterable {
        case recommended
        case advanced
        case restricted

        var displayName: String {
            switch self {
            case .recommended: String(localized: "Recommended")
            case .advanced:    String(localized: "Advanced")
            case .restricted:  String(localized: "Restricted")
            }
        }

        var order: Int {
            switch self {
            case .recommended: 2
            case .advanced:    1
            case .restricted:  0
            }
        }
    }

    var classification: Classification = .recommended

    // MARK: - Restriction Reasons

    struct RestrictionReason: Identifiable, Sendable {
        public let id = UUID()
        let code: String
        let description: String
    }

    var restrictionReasons: [RestrictionReason] = []

    // MARK: - Device Compatibility

    var deviceCompatible: Bool = true
    var deviceIncompatibilityReason: String?

    // MARK: - Legacy compatibility

    /// RF recommendation: top-2 per band with score ≥ 70.
    /// For backward compatibility with OverviewView.
    var isRecommended: Bool { rfIsRecommended }

    // MARK: - Initializers

    /// Create from a raw `ChannelQuality` result (pure RF, no filtering yet).
    init(from rf: ChannelQuality) {
        self.channel = rf.channel
        self.band = rf.band
        self.bandDisplay = rf.bandDisplay
        self.rfScore = rf.qualityScore
        self.rfLevel = rf.qualityLevel
        self.apCount = rf.apCount
        self.coChannelCount = rf.coChannelCount
        self.adjacentCount = rf.adjacentCount
        self.interferenceScore = rf.interferenceScore
        self.overlapLevel = rf.overlapLevel
        self.strongestNeighborRSSI = rf.strongestNeighborRSSI
        self.isCurrentChannel = rf.isCurrentChannel
        self.showInSimpleView = rf.showInSimpleView
        self.rfIsRecommended = rf.isRecommended
    }
}
