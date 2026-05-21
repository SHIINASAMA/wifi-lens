import Testing
@testable import WiFiLens

struct ChannelQualityCalculatorTests {

    private enum TestChannelWidth: String {
        case mhz20 = "20"
        case mhz80 = "80"
        case mhz160 = "160"
    }

    private func ap(
        _ channel: Int,
        _ rssi: Int,
        width: TestChannelWidth = .mhz20,
        band: ChannelBand = .band5GHz,
        apex: Double = 0
    ) -> ChannelQualityCalculator.APInfo {
        ChannelQualityCalculator.APInfo(
            channel: channel,
            rssi: rssi,
            channelWidth: width.rawValue,
            band: band.id,
            apex: apex
        )
    }

    // MARK: - Scoring formula

    @Test func singleAP20MHz5GHz() async throws {
        // ch 44, rssi -50, 20 MHz, 5 GHz
        // rssiWeight = (50)/70 = 0.714..., widthMul=1.0, bandMul=1.0, overlap=1.0
        // penalty = 1.0 * 0.714 * 1.0 * 1.0 * 18.0 ≈ 12.9 → 13, score = 87
        let result = ChannelQualityCalculator.compute(aps: [ap(44, -50)], currentChannel: nil)
        #expect(result.first(where: { $0.channel == 44 })?.qualityScore == 87)
        #expect(result.first(where: { $0.channel == 44 })?.qualityLevel == .good)
    }

    @Test func multipleCoChannelAPsAdditivePenalty() async throws {
        // Two identical 20 MHz APs on ch 44 → double penalty
        let result = ChannelQualityCalculator.compute(aps: [ap(44, -50), ap(44, -50)], currentChannel: nil)
        // Each: 13 penalty, total 26, score 74
        #expect(result.first(where: { $0.channel == 44 })?.qualityScore == 74)
        #expect(result.first(where: { $0.channel == 44 })?.qualityLevel == .good)
    }

    @Test func wideChannelMultiplier() async throws {
        // 80 MHz AP: widthMul=1.5, co-channel
        // rssiWeight = 1.0 (rssi=-30), penalty = 1.0*1.0*1.5*1.0*18.0 = 27
        let r80 = ChannelQualityCalculator.compute(aps: [ap(44, -30, width: .mhz80)], currentChannel: nil)
        #expect(r80.first(where: { $0.channel == 44 })?.qualityScore == 73)

        // 160 MHz AP: widthMul=2.0
        // penalty = 1.0*1.0*2.0*1.0*18.0 = 36
        let r160 = ChannelQualityCalculator.compute(aps: [ap(44, -30, width: .mhz160)], currentChannel: nil)
        #expect(r160.first(where: { $0.channel == 44 })?.qualityScore == 64)
    }

    @Test func band24Multiplier() async throws {
        // 2.4 GHz band: bandMul=1.8
        // rssiWeight = (50)/70 = 0.714, penalty = 1.0*0.714*1.0*1.8*18.0 ≈ 23.1 → 23, score = 77
        let r24 = ChannelQualityCalculator.compute(aps: [ap(6, -50, band: .band24GHz)], currentChannel: nil)
        #expect(r24.first(where: { $0.channel == 6 })?.qualityScore == 77)

        // Same AP on 5 GHz: bandMul=1.0, score should be higher
        let r5 = ChannelQualityCalculator.compute(aps: [ap(44, -50, band: .band5GHz)], currentChannel: nil)
        let score24 = r24.first(where: { $0.channel == 6 })!.qualityScore
        let score5 = r5.first(where: { $0.channel == 44 })!.qualityScore
        #expect(score5 > score24)
    }

    @Test func rssiEdgeCases() async throws {
        // rssi=-100: rssiWeight=0 → no penalty → score=100
        let floor = ChannelQualityCalculator.compute(aps: [ap(44, -100)], currentChannel: nil)
        #expect(floor.first(where: { $0.channel == 44 })?.qualityScore == 100)

        // rssi=-30: rssiWeight=1.0 → max penalty
        // penalty = 1.0*1.0*1.0*1.0*18.0 = 18, score = 82
        let maxRssi = ChannelQualityCalculator.compute(aps: [ap(44, -30)], currentChannel: nil)
        #expect(maxRssi.first(where: { $0.channel == 44 })?.qualityScore == 82)

        // rssi=-120 (below floor): rssiWeight clamped to 0
        let belowFloor = ChannelQualityCalculator.compute(aps: [ap(44, -120)], currentChannel: nil)
        #expect(belowFloor.first(where: { $0.channel == 44 })?.qualityScore == 100)

        // rssi=-20 (above -30): rssiWeight clamped to 1.0, same as -30
        let aboveMax = ChannelQualityCalculator.compute(aps: [ap(44, -20)], currentChannel: nil)
        #expect(aboveMax.first(where: { $0.channel == 44 })?.qualityScore == 82)
    }

    @Test func zeroAPsAllChannelsExcellent() async throws {
        let result = ChannelQualityCalculator.compute(aps: [], currentChannel: nil)
        for ch in result {
            #expect(ch.qualityScore == 100)
            #expect(ch.qualityLevel == .excellent)
        }
    }

    // MARK: - 2.4 GHz overlap factors (distance-based)

    @Test func overlap24GHz() async throws {
        // AP on ch 6 (2.4 GHz, 20 MHz, rssi=-50)
        let aps = [ap(6, -50, band: .band24GHz)]
        let result = ChannelQualityCalculator.compute(aps: aps, currentChannel: nil)

        // ch 6: co-channel → score = 77
        #expect(result.first(where: { $0.channel == 6 })!.qualityScore == 77)
        // ch 1 (dist 5): overlap=0 → score=100
        #expect(result.first(where: { $0.channel == 1 })!.qualityScore == 100)
    }

    // MARK: - 5/6 GHz overlap factors (width-based)

    @Test func overlap5GHz80MHz() async throws {
        // AP on ch 44, 80 MHz → halfSpan = 80/20/2 = 2
        let aps = [ap(44, -50, width: .mhz80, band: .band5GHz)]
        let result = ChannelQualityCalculator.compute(aps: aps, currentChannel: nil)

        // ch 44: co-channel (dist=0) → overlap=1.0
        let ch44 = result.first(where: { $0.channel == 44 })!
        #expect(ch44.qualityScore < 100)

        // ch 40 (dist 4): beyond halfSpan+1=3 → overlap=0, no penalty
        // 80 MHz spans channels 42-46 (left=42, right=46), but halfSpan in 5MHz steps = 2
        // Actually, ch 40 is 4 channels away from 44, halfSpan=2, halfSpan+1=3
        // dist=4 > 3 → overlap=0
        let ch40 = result.first(where: { $0.channel == 40 })!
        #expect(ch40.qualityScore == 100)
    }

    // MARK: - Quality level thresholds

    @Test(arguments: [
        (95, ChannelQuality.QualityLevel.excellent),
        (90, ChannelQuality.QualityLevel.excellent),
        (89, ChannelQuality.QualityLevel.good),
        (75, ChannelQuality.QualityLevel.good),
        (70, ChannelQuality.QualityLevel.good),
        (69, ChannelQuality.QualityLevel.moderate),
        (55, ChannelQuality.QualityLevel.moderate),
        (50, ChannelQuality.QualityLevel.moderate),
        (49, ChannelQuality.QualityLevel.busy),
        (35, ChannelQuality.QualityLevel.busy),
        (30, ChannelQuality.QualityLevel.busy),
        (29, ChannelQuality.QualityLevel.congested),
        (10, ChannelQuality.QualityLevel.congested),
        (0, ChannelQuality.QualityLevel.congested),
    ])
    func qualityLevelThresholds(score: Int, expected: ChannelQuality.QualityLevel) async throws {
        #expect(expected.scoreRange.contains(score))
    }

    // MARK: - Overlap level

    @Test func overlapLevel() async throws {
        // 0 APs → low
        let r0 = ChannelQualityCalculator.compute(aps: [], currentChannel: nil)
        #expect(r0.first(where: { $0.channel == 44 })!.overlapLevel == .low)
        #expect(r0.first(where: { $0.channel == 44 })!.apCount == 0)

        // 1 AP → low
        let r1 = ChannelQualityCalculator.compute(aps: [ap(44, -50)], currentChannel: nil)
        #expect(r1.first(where: { $0.channel == 44 })!.overlapLevel == .low)

        // 2 APs → moderate
        let r2 = ChannelQualityCalculator.compute(aps: [ap(44, -50), ap(44, -60)], currentChannel: nil)
        #expect(r2.first(where: { $0.channel == 44 })!.overlapLevel == .moderate)

        // 4 APs → high
        let r4 = ChannelQualityCalculator.compute(aps: [ap(44, -50), ap(44, -60), ap(44, -70), ap(44, -80)], currentChannel: nil)
        #expect(r4.first(where: { $0.channel == 44 })!.overlapLevel == .high)
    }

    // MARK: - AP count breakdown

    @Test func apCountBreakdown() async throws {
        let aps = [
            ap(44, -50, band: .band5GHz),  // co-channel
            ap(44, -60, "20", "5"),  // co-channel
            ap(40, -70, "80", "5"),  // adjacent (overlaps ch 44 via 80 MHz)
        ]
        let result = ChannelQualityCalculator.compute(aps: aps, currentChannel: nil)
        let ch44 = result.first(where: { $0.channel == 44 })!
        #expect(ch44.coChannelCount == 2)
        #expect(ch44.apCount >= 2)  // total overlapping
    }

    // MARK: - Current channel

    @Test func currentChannelMarking() async throws {
        let result = ChannelQualityCalculator.compute(aps: [ap(44, -50)], currentChannel: 44)
        #expect(result.first(where: { $0.channel == 44 })!.isCurrentChannel == true)
        #expect(result.first(where: { $0.channel == 40 })!.isCurrentChannel == false)
    }

    @Test func currentChannelNil() async throws {
        let result = ChannelQualityCalculator.compute(aps: [ap(44, -50)], currentChannel: nil)
        for ch in result {
            #expect(ch.isCurrentChannel == false)
        }
    }

    // MARK: - Recommendations

    @Test func recommendsCleanChannelsOverOccupied() async throws {
        // 3 APs on different 5 GHz channels with moderate signal
        let aps = [
            ap(36, -30, "20", "5"),
            ap(40, -35, "20", "5"),
            ap(44, -40, "20", "5"),
        ]
        let result = ChannelQualityCalculator.compute(aps: aps, currentChannel: nil)
        let recommended = result.filter { $0.band == "5" && $0.isRecommended }
        // Top 2 by score: empty channels (score=100) are recommended over occupied ones
        #expect(recommended.count == 2)
        #expect(recommended.allSatisfy { $0.qualityScore == 100 })
        #expect(recommended.allSatisfy { $0.apCount == 0 })
    }

    @Test func noRecommendationBelow70() async throws {
        // Six 160 MHz co-channel APs at strong RSSI → score well below 70
        let aps = (0..<6).map { _ in ap(36, -30, width: .mhz160, band: .band5GHz) }
        let result = ChannelQualityCalculator.compute(aps: aps, currentChannel: nil)
        let ch36 = result.first(where: { $0.channel == 36 })!
        #expect(ch36.qualityScore < 70)
        #expect(ch36.isRecommended == false)
    }

    // MARK: - Simple view filtering

    @Test func simpleViewShowsCurrentRecommendedAndOccupied() async throws {
        let aps = [
            ap(36, -50, "20", "5"),
            ap(40, -50, "20", "5"),
            ap(44, -50, band: .band5GHz),
        ]
        let result = ChannelQualityCalculator.compute(aps: aps, currentChannel: 48)
        // ch 48: current → shown
        #expect(result.first(where: { $0.channel == 48 })!.showInSimpleView == true)
        // ch 36: has AP → shown
        #expect(result.first(where: { $0.channel == 36 })!.showInSimpleView == true)
        // ch 56: no AP, not current, not in top 2 recommendations → hidden
        let ch56 = result.first(where: { $0.channel == 56 })!
        #expect(ch56.showInSimpleView == false)
    }

    // MARK: - Sort order

    @Test func currentChannelSortedFirst() async throws {
        let result = ChannelQualityCalculator.compute(aps: [ap(40, -50)], currentChannel: 44)
        #expect(result.first!.channel == 44)  // current channel first
        #expect(result.first!.isCurrentChannel == true)
    }

    // MARK: - Interference score field

    @Test func interferenceScoreField() async throws {
        let result = ChannelQualityCalculator.compute(aps: [ap(44, -50)], currentChannel: nil)
        let ch44 = result.first(where: { $0.channel == 44 })!
        #expect(ch44.interferenceScore > 0)
        #expect(ch44.qualityScore == 100 - ch44.interferenceScore)
    }

    // MARK: - Strongest neighbor RSSI

    @Test func strongestNeighborRSSI() async throws {
        let aps = [ap(44, -50), ap(44, -70)]
        let result = ChannelQualityCalculator.compute(aps: aps, currentChannel: nil)
        let ch44 = result.first(where: { $0.channel == 44 })!
        #expect(ch44.strongestNeighborRSSI == -50)  // strongest among overlapping
        // Non-overlapping channel gets default -100
        let ch40 = result.first(where: { $0.channel == 40 })!
        #expect(ch40.strongestNeighborRSSI == -100)
    }
}
