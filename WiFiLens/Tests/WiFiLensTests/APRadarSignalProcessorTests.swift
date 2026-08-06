import Foundation
import Testing
@testable import WiFi_Lens

// MARK: - RSSI smoothing

@Suite("APRadarSignalProcessor RSSI smoothing")
struct APRadarSignalProcessorSmoothingTests {

    @Test("first valid sample becomes the smoothed value directly")
    func firstSampleBecomesBaseline() {
        var processor = APRadarSignalProcessor()
        let date = Date(timeIntervalSince1970: 100)

        let result = processor.ingest(rawRSSI: -60, at: date)

        #expect(result == -60)
        #expect(processor.smoothedRSSI == -60)
        #expect(processor.rawRSSI == -60)
        #expect(processor.sampleCount == 1)
    }

    @Test("subsequent samples update with alpha 0.30")
    func emaUsesAlphaPointThree() {
        var processor = APRadarSignalProcessor()
        let date = Date(timeIntervalSince1970: 100)

        _ = processor.ingest(rawRSSI: -60, at: date)
        let result = processor.ingest(rawRSSI: -50, at: date.addingTimeInterval(1))

        // 0.30 * (-50) + 0.70 * (-60) = -57
        #expect(abs((result ?? .nan) - (-57)) < 0.0001)
        #expect(abs((processor.smoothedRSSI ?? .nan) - (-57)) < 0.0001)
    }

    @Test("invalid RSSI values are ignored")
    func invalidSamplesAreIgnored() {
        var processor = APRadarSignalProcessor()
        let date = Date(timeIntervalSince1970: 100)

        #expect(processor.ingest(rawRSSI: 5, at: date) == nil)
        #expect(processor.ingest(rawRSSI: -101, at: date) == nil)
        #expect(processor.ingest(rawRSSI: -1000, at: date) == nil)
        #expect(processor.rawRSSI == nil)
        #expect(processor.smoothedRSSI == nil)
        #expect(processor.sampleCount == 0)

        _ = processor.ingest(rawRSSI: -70, at: date)
        let invalidFollowUp = processor.ingest(rawRSSI: 5, at: date.addingTimeInterval(1))
        #expect(invalidFollowUp == nil)
        // State unchanged after the rejected sample.
        #expect(processor.smoothedRSSI == -70)
        #expect(processor.sampleCount == 1)
    }

    @Test("reset clears state so the next sample does not inherit the old value")
    func resetDoesNotInherit() {
        var processor = APRadarSignalProcessor()
        let date = Date(timeIntervalSince1970: 100)

        _ = processor.ingest(rawRSSI: -60, at: date)
        _ = processor.ingest(rawRSSI: -50, at: date.addingTimeInterval(1))

        processor.reset()

        #expect(processor.smoothedRSSI == nil)
        #expect(processor.rawRSSI == nil)
        #expect(processor.sampleCount == 0)

        let firstAfterReset = processor.ingest(rawRSSI: -80, at: date.addingTimeInterval(2))
        #expect(firstAfterReset == -80)
    }
}

// MARK: - Interval mapping

@Suite("APRadarPulseInterval mapping")
struct APRadarPulseIntervalTests {

    @Test("all anchor points map to their specified intervals")
    func anchorPoints() {
        #expect(APRadarPulseInterval.intervalSeconds(forRSSI: -42) == 0.18)
        #expect(APRadarPulseInterval.intervalSeconds(forRSSI: -50) == 0.28)
        #expect(APRadarPulseInterval.intervalSeconds(forRSSI: -60) == 0.48)
        #expect(APRadarPulseInterval.intervalSeconds(forRSSI: -70) == 0.80)
        #expect(APRadarPulseInterval.intervalSeconds(forRSSI: -80) == 1.20)
        #expect(APRadarPulseInterval.intervalSeconds(forRSSI: -90) == 1.60)
    }

    @Test("midpoints interpolate linearly between anchors")
    func interpolation() {
        #expect(abs(APRadarPulseInterval.intervalSeconds(forRSSI: -55) - 0.38) < 0.0001)
        #expect(abs(APRadarPulseInterval.intervalSeconds(forRSSI: -65) - 0.64) < 0.0001)
        #expect(abs(APRadarPulseInterval.intervalSeconds(forRSSI: -75) - 1.00) < 0.0001)
        // Quarter points.
        #expect(abs(APRadarPulseInterval.intervalSeconds(forRSSI: -52.5) - 0.33) < 0.0001)
        #expect(abs(APRadarPulseInterval.intervalSeconds(forRSSI: -87) - 1.48) < 0.0001)
    }

    @Test("values beyond the anchors are clamped to the endpoints")
    func clamping() {
        #expect(APRadarPulseInterval.intervalSeconds(forRSSI: -20) == 0.18)
        #expect(APRadarPulseInterval.intervalSeconds(forRSSI: 10) == 0.18)
        #expect(APRadarPulseInterval.intervalSeconds(forRSSI: -95) == 1.60)
        #expect(APRadarPulseInterval.intervalSeconds(forRSSI: -200) == 1.60)
    }

    @Test("non-finite input never produces NaN or infinity")
    func nonFiniteInput() {
        let nanResult = APRadarPulseInterval.intervalSeconds(forRSSI: .nan)
        #expect(nanResult.isFinite)
        #expect(nanResult == 1.60)

        let plusInfinity = APRadarPulseInterval.intervalSeconds(forRSSI: .infinity)
        #expect(plusInfinity == 0.18)
        let minusInfinity = APRadarPulseInterval.intervalSeconds(forRSSI: -.infinity)
        #expect(minusInfinity == 1.60)
    }

    @Test("duration form matches seconds form")
    func durationForm() {
        let duration = APRadarPulseInterval.pulseInterval(forRSSI: -55)
        #expect(duration.components.seconds == 0)
        #expect(abs(Double(duration.components.attoseconds) / 1e18 - 0.38) < 0.0001)
    }
}

// MARK: - Signal trend

@Suite("APRadarSignalProcessor trend")
struct APRadarSignalProcessorTrendTests {
    private let t0 = Date(timeIntervalSince1970: 1000)

    @Test("getting closer when smoothed signal gains at least 3 dB over 3 seconds")
    func gettingCloser() {
        var processor = APRadarSignalProcessor()
        _ = processor.ingest(rawRSSI: -60, at: t0)
        _ = processor.ingest(rawRSSI: -40, at: t0.addingTimeInterval(3))

        // Smoothed: -60 -> 0.3*(-40) + 0.7*(-60) = -54, delta +6.
        #expect(processor.trend(at: t0.addingTimeInterval(3)) == .gettingCloser)
    }

    @Test("moving away when smoothed signal drops at least 3 dB over 3 seconds")
    func movingAway() {
        var processor = APRadarSignalProcessor()
        _ = processor.ingest(rawRSSI: -50, at: t0)
        _ = processor.ingest(rawRSSI: -70, at: t0.addingTimeInterval(3))

        // Smoothed: -50 -> -56, delta -6.
        #expect(processor.trend(at: t0.addingTimeInterval(3)) == .movingAway)
    }

    @Test("stable when smoothed change is smaller than 3 dB")
    func stable() {
        var processor = APRadarSignalProcessor()
        _ = processor.ingest(rawRSSI: -60, at: t0)
        _ = processor.ingest(rawRSSI: -58, at: t0.addingTimeInterval(3))

        // Smoothed: -60 -> -59.4, delta +0.6.
        #expect(processor.trend(at: t0.addingTimeInterval(3)) == .stable)
    }

    @Test("measuring while history is younger than 2 seconds or absent")
    func measuring() {
        var empty = APRadarSignalProcessor()
        #expect(empty.trend(at: t0) == .measuring)

        var fresh = APRadarSignalProcessor()
        _ = fresh.ingest(rawRSSI: -60, at: t0)
        _ = fresh.ingest(rawRSSI: -50, at: t0.addingTimeInterval(1))
        #expect(fresh.trend(at: t0.addingTimeInterval(1)) == .measuring)
    }

    @Test("trend uses smoothed values, not single raw samples")
    func trendUsesSmoothedValues() {
        var processor = APRadarSignalProcessor()
        _ = processor.ingest(rawRSSI: -60, at: t0)
        // A raw jump of +4 dB would be "getting closer" if raw values were
        // used, but the smoothed delta (+1.2 dB) keeps the trend stable.
        _ = processor.ingest(rawRSSI: -56, at: t0.addingTimeInterval(3))

        let smoothed = processor.smoothedRSSI ?? .nan
        #expect(abs(smoothed - (-58.8)) < 0.0001)
        #expect(processor.trend(at: t0.addingTimeInterval(3)) == .stable)
    }
}
