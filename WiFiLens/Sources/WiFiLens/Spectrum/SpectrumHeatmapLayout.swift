import CoreGraphics

struct SpectrumHeatmapFrequencyDomain: Equatable, Sendable {
    let minFrequencyMHz: Double
    let maxFrequencyMHz: Double
    let regions: [ClosedRange<Double>]
}

enum SpectrumHeatmapLayout {
    private static let interRegionGapRatio = 0.12
    private static let channelCoordinateSpacingMHz = 5.0
    static let fixedRSSIRange = (-100.0)...(-30.0)

    static func channelCenterFrequencyMHz(channel: Int, band: ChannelBand) -> Double? {
        frequencyMHz(forChannelCoordinate: Double(channel), band: band)
    }

    /// Kept as a compatibility spelling for existing callers; a legal channel
    /// number maps to its physical center frequency.
    static func channelEdgeFrequencyMHz(channel: Int, band: ChannelBand) -> Double? {
        channelCenterFrequencyMHz(channel: channel, band: band)
    }

    /// Converts the endpoints produced by `ChannelSpanCalculator` while
    /// preserving special physical centers such as JP 2.4 GHz channel 14.
    static func channelBlockFrequencyBounds(
        leftChannel: Int,
        rightChannel: Int,
        band: ChannelBand
    ) -> ClosedRange<Double>? {
        guard leftChannel <= rightChannel else { return nil }
        let centerChannel = (Double(leftChannel) + Double(rightChannel)) / 2.0
        guard let centerFrequency = frequencyMHz(
            forChannelCoordinate: centerChannel,
            band: band
        ) else { return nil }

        let halfWidth = Double(rightChannel - leftChannel) * channelCoordinateSpacingMHz / 2.0
        let lower = centerFrequency - halfWidth
        let upper = centerFrequency + halfWidth
        guard lower.isFinite, upper.isFinite, lower < upper else { return nil }
        return lower...upper
    }

    private static func frequencyMHz(forChannelCoordinate channel: Double, band: ChannelBand) -> Double? {
        guard channel.isFinite else { return nil }
        switch band {
        case .band24GHz:
            if channel == 14 { return 2484 }
            guard (-10...20).contains(channel) else { return nil }
            return 2407 + channel * channelCoordinateSpacingMHz
        case .band5GHz:
            guard (1...200).contains(channel) else { return nil }
            return 5000 + channel * channelCoordinateSpacingMHz
        case .band6GHz:
            guard (-10...240).contains(channel) else { return nil }
            return 5950 + channel * channelCoordinateSpacingMHz
        }
    }

    static func frequencyDomain(channels: [Int], band: ChannelBand) -> SpectrumHeatmapFrequencyDomain {
        let frequencies = Array(Set(channels.compactMap {
            channelCenterFrequencyMHz(channel: $0, band: band)
        })).sorted()
        guard let first = frequencies.first, let last = frequencies.last else {
            return SpectrumHeatmapFrequencyDomain(minFrequencyMHz: 0, maxFrequencyMHz: 1, regions: [])
        }

        let halfStep = nominalChannelSpacingMHz(for: band) / 2
        var regions: [ClosedRange<Double>] = []
        var regionStart = first
        var previous = first
        for frequency in frequencies.dropFirst() {
            if frequency - previous > nominalChannelSpacingMHz(for: band) {
                regions.append((regionStart - halfStep)...(previous + halfStep))
                regionStart = frequency
            }
            previous = frequency
        }
        regions.append((regionStart - halfStep)...(previous + halfStep))

        return SpectrumHeatmapFrequencyDomain(
            minFrequencyMHz: first - halfStep,
            maxFrequencyMHz: last + halfStep,
            regions: regions
        )
    }

    static func xPosition(forFrequencyMHz frequencyMHz: Double, domain: SpectrumHeatmapFrequencyDomain, in rect: CGRect) -> CGFloat? {
        guard rect.width > 0, frequencyMHz.isFinite else { return nil }
        return projectionSegments(domain: domain, in: rect).first {
            $0.frequencyRange.contains(frequencyMHz)
        }.map { segment in
            segment.xStart + CGFloat((frequencyMHz - segment.frequencyRange.lowerBound) /
                (segment.frequencyRange.upperBound - segment.frequencyRange.lowerBound)) *
                (segment.xEnd - segment.xStart)
        }
    }

    static func frequencyMHz(forX x: CGFloat, domain: SpectrumHeatmapFrequencyDomain, in rect: CGRect) -> Double? {
        guard rect.width > 0, rect.height > 0,
              x >= rect.minX, x <= rect.maxX else { return nil }
        return projectionSegments(domain: domain, in: rect).first {
            $0.xRange.contains(x)
        }.map { segment in
            let normalized = Double((x - segment.xStart) / (segment.xEnd - segment.xStart))
            return segment.frequencyRange.lowerBound + normalized *
                (segment.frequencyRange.upperBound - segment.frequencyRange.lowerBound)
        }
    }

    static func yPosition(forRSSI rssi: Double, in rect: CGRect, rssiRange: ClosedRange<Double>) -> CGFloat? {
        guard rect.height > 0, rssi.isFinite, rssiRange.lowerBound <= rssiRange.upperBound else { return nil }
        let clamped = min(fixedRSSIRange.upperBound, max(fixedRSSIRange.lowerBound, rssi))
        let normalized = (clamped - fixedRSSIRange.lowerBound) /
            (fixedRSSIRange.upperBound - fixedRSSIRange.lowerBound)
        return rect.maxY - CGFloat(normalized) * rect.height
    }

    static func rssi(forY y: CGFloat, in rect: CGRect, rssiRange: ClosedRange<Double>) -> Double? {
        guard rect.height > 0, y >= rect.minY, y <= rect.maxY,
              rssiRange.lowerBound <= rssiRange.upperBound else {
            return nil
        }
        let normalized = Double((rect.maxY - y) / rect.height)
        return fixedRSSIRange.lowerBound + normalized *
            (fixedRSSIRange.upperBound - fixedRSSIRange.lowerBound)
    }

    static func channelTicks(channels: [Int], band: ChannelBand, in rect: CGRect, maximumCount: Int = 10) -> [(channel: Int, x: CGFloat)] {
        let sorted = Array(Set(channels)).sorted()
        let count = min(10, maximumCount, sorted.count)
        guard count > 0 else { return [] }
        let domain = frequencyDomain(channels: sorted, band: band)
        let indexes = (0..<count).map { offset in
            Int((Double(offset) * Double(sorted.count - 1) / Double(max(1, count - 1))).rounded())
        }
        return indexes.compactMap { index in
            guard let frequency = channelCenterFrequencyMHz(channel: sorted[index], band: band),
                  let x = xPosition(forFrequencyMHz: frequency, domain: domain, in: rect) else { return nil }
            return (channel: sorted[index], x: x)
        }
    }

    private struct ProjectionSegment {
        let frequencyRange: ClosedRange<Double>
        let xStart: CGFloat
        let xEnd: CGFloat
        var xRange: ClosedRange<CGFloat> { xStart...xEnd }
    }

    private static func projectionSegments(domain: SpectrumHeatmapFrequencyDomain, in rect: CGRect) -> [ProjectionSegment] {
        guard rect.width > 0, !domain.regions.isEmpty else { return [] }
        let physicalSpan = domain.regions.reduce(0.0) { $0 + $1.upperBound - $1.lowerBound }
        guard physicalSpan > 0 else { return [] }
        let gapWidth = rect.width * CGFloat(interRegionGapRatio)
        let usableWidth = rect.width - CGFloat(max(0, domain.regions.count - 1)) * gapWidth
        guard usableWidth > 0 else { return [] }

        var cursor = rect.minX
        return domain.regions.map { region in
            let width = usableWidth * CGFloat((region.upperBound - region.lowerBound) / physicalSpan)
            defer { cursor += width + gapWidth }
            return ProjectionSegment(frequencyRange: region, xStart: cursor, xEnd: cursor + width)
        }
    }

    private static func nominalChannelSpacingMHz(for band: ChannelBand) -> Double {
        band == .band24GHz ? 5 : 20
    }
}
