import Testing
import Foundation
@testable import WiFi_Lens

// MARK: - DynamicChannelScorer

@MainActor
struct DynamicChannelScorerTests {

    private func makeQuality(
        channel: Int,
        band: String = "5",
        score: Int,
        apCount: Int
    ) -> ChannelQuality {
        ChannelQuality(
            channel: channel,
            band: band,
            bandDisplay: band == "5" ? "5 GHz" : "2.4 GHz",
            qualityScore: score,
            qualityLevel: .from(score: score),
            apCount: apCount,
            coChannelCount: apCount,
            adjacentCount: 0,
            interferenceScore: 100 - score,
            overlapLevel: apCount <= 1 ? .low : .moderate,
            strongestNeighborRSSI: -50,
            isRecommended: false,
            isCurrentChannel: false,
            showInSimpleView: true,
            predictedScore: score
        )
    }

    @Test func firstScanPreservesOriginalScores() {
        let scorer = DynamicChannelScorer()
        let qualities = [
            makeQuality(channel: 36, score: 95, apCount: 0),
            makeQuality(channel: 40, score: 80, apCount: 2),
            makeQuality(channel: 44, score: 60, apCount: 4),
        ]
        let result = scorer.computePredictedScores(qualities)
        #expect(result[0].predictedScore == 95)
        #expect(result[1].predictedScore == 80)
        #expect(result[2].predictedScore == 60)
    }

    @Test func recommendedChannelPenalizedOnSecondScan() {
        let scorer = DynamicChannelScorer()
        // Scan 1: ch36 is best (empty), ch40 has 1 AP
        let scan1 = [
            makeQuality(channel: 36, score: 100, apCount: 0),
            makeQuality(channel: 40, score: 85, apCount: 1),
        ]
        let result1 = scorer.computePredictedScores(scan1)
        // ch36 should be recommended (highest predicted score)
        #expect(result1[0].channel == 36)
        #expect(result1[0].predictedScore >= result1[1].predictedScore)

        // Scan 2: ch36 now has 1 AP (someone migrated), ch40 unchanged
        let scan2 = [
            makeQuality(channel: 36, score: 85, apCount: 1),
            makeQuality(channel: 40, score: 85, apCount: 1),
        ]
        let result2 = scorer.computePredictedScores(scan2)
        // ch36 should be penalized because it was previously recommended
        // and gained an AP (migration effect)
        let ch36Predicted = result2.first { $0.channel == 36 }!
        let ch40Predicted = result2.first { $0.channel == 40 }!
        #expect(ch36Predicted.predictedScore < ch40Predicted.predictedScore)
    }

    @Test func nonRecommendedChannelNotPenalized() {
        let scorer = DynamicChannelScorer()
        // Scan 1: ch36 recommended, ch40 not
        let scan1 = [
            makeQuality(channel: 36, score: 100, apCount: 0),
            makeQuality(channel: 40, score: 70, apCount: 3),
        ]
        let _ = scorer.computePredictedScores(scan1)

        // Scan 2: ch40 gains APs (natural fluctuation, not migration)
        let scan2 = [
            makeQuality(channel: 36, score: 100, apCount: 0),
            makeQuality(channel: 40, score: 65, apCount: 4),
        ]
        let result2 = scorer.computePredictedScores(scan2)
        // ch40 should not be extra-penalized (wasn't recommended)
        let ch40Predicted = result2.first { $0.channel == 40 }!
        #expect(ch40Predicted.predictedScore >= 50)
    }

    @Test func emaSmoothsNoisyHistory() {
        let scorer = DynamicChannelScorer()
        // Feed noisy AP count history: 0, 5, 0, 5, 0
        let channels = (0..<5).map { i -> ChannelQuality in
            let aps = i % 2 == 0 ? 0 : 5
            let score = 100 - aps * 10
            return makeQuality(channel: 36, score: score, apCount: aps)
        }
        var lastResult: [ChannelQuality] = []
        for ch in channels {
            lastResult = scorer.computePredictedScores([ch])
        }
        // EMA should smooth the oscillation — predicted APs shouldn't swing wildly
        let predicted = lastResult[0].predictedScore
        #expect(predicted > 40 && predicted < 100)
    }

    @Test func multipleBandsScoredIndependently() {
        let scorer = DynamicChannelScorer()
        let qualities = [
            makeQuality(channel: 1, band: "24", score: 90, apCount: 1),
            makeQuality(channel: 36, band: "5", score: 95, apCount: 0),
        ]
        let result = scorer.computePredictedScores(qualities)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.predictedScore > 0 })
    }

    @Test func resetClearsHistory() {
        let scorer = DynamicChannelScorer()
        let scan1 = [makeQuality(channel: 36, score: 100, apCount: 0)]
        let _ = scorer.computePredictedScores(scan1)
        scorer.reset()
        // After reset, next scan should behave like first scan
        let scan2 = [makeQuality(channel: 36, score: 100, apCount: 0)]
        let result = scorer.computePredictedScores(scan2)
        #expect(result[0].predictedScore == 100)
    }

    @Test func predictedScoreBounded0to100() {
        let scorer = DynamicChannelScorer()
        // Simulate extreme degradation over multiple scans
        for aps in [0, 10, 20, 30, 40] {
            let q = makeQuality(channel: 36, score: max(0, 100 - aps * 3), apCount: aps)
            let result = scorer.computePredictedScores([q])
            #expect(result[0].predictedScore >= 0)
            #expect(result[0].predictedScore <= 100)
        }
    }
}
