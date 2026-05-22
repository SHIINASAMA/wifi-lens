import Foundation

/// Per-channel congestion analysis result.
struct ChannelQuality: Identifiable {
    let channel: Int
    let band: String
    let bandDisplay: String
    let qualityScore: Int          // 0–100
    let qualityLevel: QualityLevel
    let apCount: Int               // APs on or overlapping this channel
    let coChannelCount: Int         // APs on the same channel only
    let adjacentCount: Int          // APs on overlapping adjacent channels
    let interferenceScore: Int      // raw interference penalty (0 = clean)
    let overlapLevel: OverlapLevel
    let strongestNeighborRSSI: Int
    var isRecommended: Bool = false
    var isCurrentChannel: Bool = false
    var showInSimpleView: Bool = true

    var id: String { "\(band)-\(channel)" }

    enum QualityLevel: String, CaseIterable {
        case excellent
        case good
        case moderate
        case busy
        case congested

        var displayName: String {
            switch self {
            case .excellent: String(localized: "Excellent")
            case .good:      String(localized: "Good")
            case .moderate:  String(localized: "Moderate")
            case .busy:      String(localized: "Busy")
            case .congested: String(localized: "Congested")
            }
        }

        var scoreRange: ClosedRange<Int> {
            switch self {
            case .excellent: 90...100
            case .good:      70...89
            case .moderate:  50...69
            case .busy:      30...49
            case .congested: 0...29
            }
        }

        var color: String {
            switch self {
            case .excellent: "#34C759"
            case .good:      "#30B0C7"
            case .moderate:  "#FF9F0A"
            case .busy:      "#FF6B35"
            case .congested: "#FF3B30"
            }
        }

        var minScore: Int { scoreRange.lowerBound }

        static func from(score: Int) -> Self {
            switch score {
            case 90...100: .excellent
            case 70...89:  .good
            case 50...69:  .moderate
            case 30...49:  .busy
            default:       .congested
            }
        }

        fileprivate var order: Int {
            switch self {
            case .excellent: 4; case .good: 3; case .moderate: 2; case .busy: 1; case .congested: 0
            }
        }
    }

    enum OverlapLevel: String {
        case low
        case moderate
        case high

        var displayName: String {
            switch self {
            case .low:      String(localized: "Low")
            case .moderate: String(localized: "Moderate")
            case .high:     String(localized: "High")
            }
        }
    }
}

/// Hysteresis wrapper that smooths quality score fluctuations across level boundaries.
/// Upgrades to a better level immediately; downgrades only when the score drops below
/// the current level's minimum by the configured margin.
struct StableScore {
    private var current: Int
    private var level: ChannelQuality.QualityLevel

    init(initialScore: Int = 100) {
        self.current = initialScore
        self.level = .from(score: initialScore)
    }

    /// Feed a new raw score. Returns the stabilized score (may be held at boundary if flickering).
    mutating func update(score: Int, downgradeMargin: Int = 5, upgradeMargin: Int = 2) -> Int {
        let rawLevel = ChannelQuality.QualityLevel.from(score: score)

        if rawLevel.order > level.order {
            // Upgrade only if score is above the current level's maximum by upgrade margin
            if score >= level.scoreRange.upperBound + upgradeMargin {
                current = score
                level = rawLevel
            }
        } else if rawLevel.order < level.order {
            // Downgrade only if score is below the current level's minimum by downgrade margin
            if score <= level.minScore - downgradeMargin {
                current = score
                level = rawLevel
            }
        } else {
            // Same level: track smoothly
            current = score
        }
        return current
    }

    mutating func reset(score: Int = 100) {
        current = score
        level = .from(score: score)
    }
}

/// Computes channel congestion scores per band.
enum ChannelQualityCalculator {
    struct APInfo {
        let channel: Int
        let rssi: Int
        let channelWidth: String  // "20"/"40"/"80"/"160"
        let band: String          // "24"/"5"/"6"
        let apex: Double          // span midpoint
    }

    /// Produce a quality rating for every relevant channel in each band.
    static func compute(aps: [APInfo], currentChannel: Int? = nil, supportedBands: Set<String> = ["24", "5", "6"]) -> [ChannelQuality] {
        var results: [ChannelQuality] = []

        for band in supportedBands.sorted() {
            let bandAPs = aps.filter { $0.band == band }

            let channels = band == "24"
                ? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
                : stride(from: band == "5" ? 36 : 1, through: band == "5" ? 165 : 233, by: 4).map { $0 }

            let bandDisplay = band == "24" ? String(localized: "2.4 GHz") : band == "5" ? String(localized: "5 GHz") : String(localized: "6 GHz")

            // Score each channel
            let scored = channels.map { ch -> ChannelQuality in
                let interference = computeInterference(channel: ch, band: band, aps: bandAPs)
                let score = max(0, min(100, 100 - interference))
                let level: ChannelQuality.QualityLevel = switch score {
                case 90...100: .excellent
                case 70...89:  .good
                case 50...69:  .moderate
                case 30...49:  .busy
                default:       .congested
                }
                let strongest = bandAPs
                    .filter { overlaps(channel: ch, other: $0, band: band) }
                    .map(\.rssi).max() ?? -100
                let allOverlapping = bandAPs.filter { overlaps(channel: ch, other: $0, band: band) }
                let overlapCount = allOverlapping.count
                let coChanCount = bandAPs.filter { $0.channel == ch }.count
                let adjCount = allOverlapping.filter { $0.channel != ch }.count
                let overlap: ChannelQuality.OverlapLevel = switch overlapCount {
                case 0...1: .low
                case 2...3: .moderate
                default:    .high
                }

                return ChannelQuality(
                    channel: ch,
                    band: band,
                    bandDisplay: bandDisplay,
                    qualityScore: score,
                    qualityLevel: level,
                    apCount: overlapCount,
                    coChannelCount: coChanCount,
                    adjacentCount: adjCount,
                    interferenceScore: interference,
                    overlapLevel: overlap,
                    strongestNeighborRSSI: strongest,
                    isRecommended: false,
                    isCurrentChannel: ch == currentChannel
                )
            }

            // Mark top 2 per band as recommended (if score ≥ 70)
            let eligible = scored.filter { $0.qualityScore >= 70 }.sorted(by: { $0.qualityScore > $1.qualityScore }).prefix(2)
            let recIDs = Set(eligible.map(\.id))
            results += scored.map { q in
                var q = q
                q.isRecommended = recIDs.contains(q.id)
                // Simple view: current channel, recommended, or congested/busy
                q.showInSimpleView = q.isCurrentChannel
                    || q.isRecommended
                    || q.apCount > 0
                return q
            }
        }

        // Sort: current channel first, then recommended, then by score, then by channel
        return results.sorted { a, b in
            if a.isCurrentChannel != b.isCurrentChannel { return a.isCurrentChannel }
            if a.isRecommended != b.isRecommended { return a.isRecommended }
            if a.qualityScore != b.qualityScore { return a.qualityScore > b.qualityScore }
            if a.band != b.band { return a.band < b.band }
            return a.channel < b.channel
        }
    }

    // MARK: - Interference model

    private static func computeInterference(channel: Int, band: String, aps: [APInfo]) -> Int {
        var penalty: Double = 0
        for ap in aps {
            let factor = overlapFactor(channel: channel, other: ap, band: band)
            guard factor > 0 else { continue }
            let rssiWeight = max(0, min(1, Double(ap.rssi + 100) / 70.0))
            let widthMul: Double = switch ap.channelWidth {
            case "160": 2.0
            case "80":  1.5
            case "40":  1.2
            default:    1.0
            }
            let bandMul: Double = band == "24" ? 1.8 : 1.0
            penalty += factor * rssiWeight * widthMul * bandMul * 18.0
        }
        return Int(penalty.rounded())
    }

    /// 0.0 = no overlap, 1.0 = co-channel, 0.1–0.8 = partial overlap
    private static func overlapFactor(channel: Int, other: APInfo, band: String) -> Double {
        if other.channel == channel { return 1.0 }

        if band == "24" {
            let dist = abs(channel - other.channel)
            return switch dist {
            case 1: 0.8
            case 2: 0.55
            case 3: 0.3
            case 4: 0.15
            default: 0
            }
        }

        // 5 / 6 GHz: only wide channels cause adjacency interference
        let dist = abs(channel - other.channel)
        let width = Int(other.channelWidth) ?? 20
        let halfSpan = width / 20 / 2  // how many 5MHz steps
        if dist == 0 { return 1.0 }
        if dist <= halfSpan { return 0.4 }
        if dist <= halfSpan + 1 { return 0.15 }
        return 0
    }

    private static func overlaps(channel: Int, other: APInfo, band: String) -> Bool {
        overlapFactor(channel: channel, other: other, band: band) > 0
    }
}
