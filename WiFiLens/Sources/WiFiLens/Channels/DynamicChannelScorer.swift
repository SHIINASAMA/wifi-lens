import Foundation

/// Predictive channel scoring model that accounts for dynamic system behavior.
///
/// The core problem: channel recommendations are based on static snapshots, but
/// following recommendations changes the environment. A recommended channel will
/// attract migrating APs, degrading its own quality — a feedback loop.
///
/// This model predicts future channel state by:
/// 1. Tracking per-channel AP count history across scans (EMA smoothing)
/// 2. Estimating migration pressure from recently recommended channels
/// 3. Computing predicted scores that represent expected future quality
///
/// The predicted score is used for recommendation selection instead of the raw
/// RF snapshot score, producing recommendations that remain valid after users
/// act on them.
@MainActor
final class DynamicChannelScorer {
    private let maxHistory = 5
    private let emaAlpha = 0.4
    private let migrationFraction = 0.3

    struct ChannelHistory {
        var apCounts: [Int] = []
        var lastRecommended: Bool = false
        var lastScore: Int = 100
    }

    private var history: [String: ChannelHistory] = [:]
    private var previousRecommendations: Set<String> = []

    func reset() {
        history.removeAll()
        previousRecommendations.removeAll()
    }

    /// Compute predicted scores for all channels and update `predictedScore` on each.
    func computePredictedScores(_ qualities: [ChannelQuality]) -> [ChannelQuality] {
        let bandAPCounts = computeBandTotalAPCounts(qualities)
        var result: [ChannelQuality] = []

        for var q in qualities {
            let key = q.id
            var h = history[key] ?? ChannelHistory()

            h.apCounts.append(q.apCount)
            if h.apCounts.count > maxHistory {
                h.apCounts.removeFirst()
            }
            h.lastRecommended = previousRecommendations.contains(key)
            h.lastScore = q.qualityScore
            history[key] = h

            let predictedAPs = predictAPCount(h)
            let migrationPressure = estimateMigrationPressure(
                channelID: key, band: q.band, bandAPCounts: bandAPCounts
            )
            let predictedScore = computePredictedScore(
                currentScore: q.qualityScore,
                currentAPs: q.apCount,
                predictedAPs: predictedAPs,
                migrationPressure: migrationPressure,
                wasRecommended: h.lastRecommended
            )

            q.predictedScore = predictedScore
            result.append(q)
        }

        let newRecs = Set(result.filter { $0.predictedScore >= 70 }
            .sorted { $0.predictedScore > $1.predictedScore }
            .prefix(2).map(\.id))
        previousRecommendations = newRecs

        return result
    }

    private func predictAPCount(_ h: ChannelHistory) -> Double {
        guard !h.apCounts.isEmpty else { return 0 }
        var ema = Double(h.apCounts[0])
        for i in 1..<h.apCounts.count {
            ema = emaAlpha * Double(h.apCounts[i]) + (1 - emaAlpha) * ema
        }
        return ema
    }

    private func estimateMigrationPressure(
        channelID: String, band: String, bandAPCounts: [String: Int]
    ) -> Double {
        guard previousRecommendations.contains(channelID) else { return 0 }
        let totalBandAPs = bandAPCounts[band] ?? 0
        guard totalBandAPs > 0 else { return 0 }
        return migrationFraction
    }

    private func computePredictedScore(
        currentScore: Int,
        currentAPs: Int,
        predictedAPs: Double,
        migrationPressure: Double,
        wasRecommended: Bool
    ) -> Int {
        let trendDelta = predictedAPs - Double(currentAPs)
        let trendPenalty = trendDelta > 0 ? trendDelta * 8.0 : 0

        let migrationPenalty: Double = {
            guard wasRecommended else { return 0 }
            let base = max(0, predictedAPs - Double(currentAPs))
            return max(3.0, base * 6.0 + migrationPressure * 15.0)
        }()

        let predicted = Double(currentScore) - trendPenalty - migrationPenalty
        return max(0, min(100, Int(predicted.rounded())))
    }

    private func computeBandTotalAPCounts(_ qualities: [ChannelQuality]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for q in qualities {
            counts[q.band, default: 0] += q.apCount
        }
        return counts
    }
}
