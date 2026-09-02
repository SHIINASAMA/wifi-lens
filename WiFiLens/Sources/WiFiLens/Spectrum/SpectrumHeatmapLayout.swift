import CoreGraphics

struct SpectrumHeatmapFrequencyDomain: Equatable, Sendable {
    let minFrequencyMHz: Double
    let maxFrequencyMHz: Double
    let regions: [ClosedRange<Double>]
}

enum SpectrumHeatmapLayout {
    static func channelEdgeFrequencyMHz(channel: Int, band: ChannelBand) -> Double? {
        switch band {
        case .band24GHz:
            if channel == 14 { return 2484 }
            // Span edges can sit outside the legal primary-channel set (for
            // example channel 1's 20 MHz interval begins at the -1 step).
            guard (-10...20).contains(channel) else { return nil }
            return 2407 + Double(channel) * 5
        case .band5GHz:
            guard (1...200).contains(channel) else { return nil }
            return 5000 + Double(channel) * 5
        case .band6GHz:
            guard (-10...240).contains(channel) else { return nil }
            return 5950 + Double(channel) * 5
        }
    }

    static func frequencyDomain(
        channels: [Int],
        band: ChannelBand
    ) -> SpectrumHeatmapFrequencyDomain {
        let frequencies = channels.compactMap { channelEdgeFrequencyMHz(channel: $0, band: band) }.sorted()
        guard let first = frequencies.first, let last = frequencies.last else {
            return SpectrumHeatmapFrequencyDomain(minFrequencyMHz: 0, maxFrequencyMHz: 1, regions: [])
        }

        let step = nominalChannelSpacingMHz(for: band)
        let halfStep = step / 2
        var regions: [ClosedRange<Double>] = []
        var regionStart = first
        var previous = first
        for frequency in frequencies.dropFirst() {
            if frequency - previous > step * 1.5 {
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

    static func xPosition(
        forFrequencyMHz frequencyMHz: Double,
        domain: SpectrumHeatmapFrequencyDomain,
        in rect: CGRect
    ) -> CGFloat? {
        guard
            rect.width > 0,
            domain.maxFrequencyMHz > domain.minFrequencyMHz,
            frequencyMHz.isFinite,
            frequencyMHz >= domain.minFrequencyMHz,
            frequencyMHz <= domain.maxFrequencyMHz
        else { return nil }
        let normalized = (frequencyMHz - domain.minFrequencyMHz)
            / (domain.maxFrequencyMHz - domain.minFrequencyMHz)
        return rect.minX + CGFloat(normalized) * rect.width
    }

    static func frequencyMHz(
        forX x: CGFloat,
        domain: SpectrumHeatmapFrequencyDomain,
        in rect: CGRect
    ) -> Double? {
        guard
            rect.width > 0,
            rect.contains(CGPoint(x: x, y: rect.midY)),
            domain.maxFrequencyMHz > domain.minFrequencyMHz
        else { return nil }
        let normalized = Double((x - rect.minX) / rect.width)
        return domain.minFrequencyMHz + normalized * (domain.maxFrequencyMHz - domain.minFrequencyMHz)
    }

    static func channelTicks(
        channels: [Int],
        band: ChannelBand,
        in rect: CGRect,
        maximumCount: Int = 12
    ) -> [(channel: Int, x: CGFloat)] {
        guard maximumCount > 0 else { return [] }
        let sorted = Array(Set(channels)).sorted()
        guard !sorted.isEmpty else { return [] }
        let domain = frequencyDomain(channels: sorted, band: band)
        let stepCount = max(1, Int(ceil(Double(sorted.count) / Double(maximumCount))))
        var selected = Array(Swift.stride(from: 0, through: sorted.count - 1, by: stepCount))
        if selected.last != sorted.count - 1 { selected.append(sorted.count - 1) }
        return selected.compactMap { index in
            guard let frequency = channelEdgeFrequencyMHz(channel: sorted[index], band: band),
                  let x = xPosition(forFrequencyMHz: frequency, domain: domain, in: rect)
            else { return nil }
            return (channel: sorted[index], x: x)
        }
    }

    private static func nominalChannelSpacingMHz(for band: ChannelBand) -> Double {
        band == .band24GHz ? 5 : 20
    }
}
