import Foundation

/// Pure RSSI processing for AP Radar: validation, exponential moving average,
/// bounded sample cache, trend calculation, and loss-recovery reset.
///
/// Deliberately free of UI, audio, and scanning concerns so it can be unit
/// tested in isolation.
struct APRadarSignalProcessor {
    /// Smoothing factor for the exponential moving average.
    static let alpha: Double = 0.30

    /// Accepted raw RSSI range. Out-of-range samples are ignored.
    static let validRSSIRange: ClosedRange<Int> = -100...0

    /// Samples older than this are pruned from the trend cache.
    static let cacheWindow: TimeInterval = 10

    /// Hard cap on cached samples.
    static let maxCachedSamples = 20

    /// Trend compares the current sample against the sample closest to this
    /// age in the past.
    static let trendLookback: TimeInterval = 3

    /// History younger than this cannot produce a trend yet.
    static let minimumTrendHistory: TimeInterval = 2

    /// Delta (in dB) at or above which the trend is "getting closer".
    static let trendThreshold: Double = 3

    private struct Sample: Equatable {
        let date: Date
        let smoothed: Double
    }

    private var samples: [Sample] = []

    /// Latest accepted raw RSSI.
    private(set) var rawRSSI: Int?

    /// Current exponential moving average of RSSI.
    private(set) var smoothedRSSI: Double?

    /// Number of valid samples ingested since the last reset.
    private(set) var sampleCount: Int = 0

    /// Clears every sample and the current estimate. The next accepted sample
    /// becomes the new baseline (no inheritance from previous state).
    mutating func reset() {
        samples.removeAll()
        rawRSSI = nil
        smoothedRSSI = nil
        sampleCount = 0
    }

    /// Feeds one raw RSSI sample. Invalid values are ignored and leave state
    /// untouched. Returns the new smoothed value, or nil when the sample was
    /// rejected.
    @discardableResult
    mutating func ingest(rawRSSI raw: Int, at date: Date) -> Double? {
        guard Self.validRSSIRange.contains(raw) else { return nil }

        let nextSmoothed: Double
        if let previous = smoothedRSSI {
            nextSmoothed = Self.alpha * Double(raw) + (1 - Self.alpha) * previous
        } else {
            nextSmoothed = Double(raw)
        }

        rawRSSI = raw
        smoothedRSSI = nextSmoothed
        sampleCount += 1
        samples.append(Sample(date: date, smoothed: nextSmoothed))
        pruneSamples(now: date)
        return nextSmoothed
    }

    /// Current signal trend based on smoothed samples only.
    func trend(at date: Date) -> SignalTrend {
        guard let current = smoothedRSSI else { return .measuring }
        guard let reference = closestSample(toAge: Self.trendLookback, at: date) else {
            return .measuring
        }
        let age = date.timeIntervalSince(reference.date)
        guard age >= Self.minimumTrendHistory else { return .measuring }

        let delta = current - reference.smoothed
        if delta >= Self.trendThreshold {
            return .gettingCloser
        }
        if delta <= -Self.trendThreshold {
            return .movingAway
        }
        return .stable
    }

    /// Oldest cached sample date, used to decide whether a lost target should
    /// reset the smoother after a long absence.
    func oldestSampleDate() -> Date? {
        samples.first?.date
    }

    /// Returns the smoothed sample closest to `age` seconds before `date`.
    private func closestSample(toAge age: TimeInterval, at date: Date) -> Sample? {
        samples.min { lhs, rhs in
            let lhsDistance = abs(date.timeIntervalSince(lhs.date) - age)
            let rhsDistance = abs(date.timeIntervalSince(rhs.date) - age)
            return lhsDistance < rhsDistance
        }
    }

    private mutating func pruneSamples(now: Date) {
        samples.removeAll { now.timeIntervalSince($0.date) > Self.cacheWindow }
        if samples.count > Self.maxCachedSamples {
            samples.removeFirst(samples.count - Self.maxCachedSamples)
        }
    }
}

/// Maps smoothed RSSI (dBm) to a pulse interval.
///
/// Piecewise-linear interpolation across the anchors below, clamped to
/// 0.18...1.60 seconds.
enum APRadarPulseInterval {
    struct Anchor: Equatable {
        let rssi: Double
        let interval: Double
    }

    static let anchors: [Anchor] = [
        Anchor(rssi: -42, interval: 0.18),
        Anchor(rssi: -50, interval: 0.28),
        Anchor(rssi: -60, interval: 0.48),
        Anchor(rssi: -70, interval: 0.80),
        Anchor(rssi: -80, interval: 1.20),
        Anchor(rssi: -90, interval: 1.60),
    ]

    static let minimumInterval: Double = 0.18
    static let maximumInterval: Double = 1.60

    /// Pure mapping used by the pulse scheduler and by unit tests.
    static func intervalSeconds(forRSSI rssi: Double) -> Double {
        guard !rssi.isNaN else { return maximumInterval }
        if rssi >= anchors[0].rssi { return anchors[0].interval }
        if rssi <= anchors[anchors.count - 1].rssi { return anchors[anchors.count - 1].interval }

        for index in 1..<anchors.count {
            let upper = anchors[index]
            let lower = anchors[index - 1]
            if rssi <= lower.rssi && rssi >= upper.rssi {
                let progress = (lower.rssi - rssi) / (lower.rssi - upper.rssi)
                let interval = lower.interval + progress * (upper.interval - lower.interval)
                return min(max(interval, minimumInterval), maximumInterval)
            }
        }
        return maximumInterval
    }

    /// Duration form of `intervalSeconds(forRSSI:)`.
    static func pulseInterval(forRSSI rssi: Double) -> Duration {
        .seconds(intervalSeconds(forRSSI: rssi))
    }
}
