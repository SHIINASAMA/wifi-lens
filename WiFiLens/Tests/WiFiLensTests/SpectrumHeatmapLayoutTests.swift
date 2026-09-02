import CoreGraphics
import Testing
@testable import WiFi_Lens

@Suite struct SpectrumHeatmapLayoutTests {
    private let rect = CGRect(x: 0, y: 0, width: 500, height: 200)

    @Test func frequencyDomainPreservesDiscontinuousFiveGHzGap() {
        let domain = SpectrumHeatmapLayout.frequencyDomain(
            channels: [36, 40, 44, 48, 149, 153, 157, 161, 165],
            band: .band5GHz
        )
        let ch48 = SpectrumHeatmapLayout.xPosition(
            forFrequencyMHz: 5000 + 48 * 5,
            domain: domain,
            in: rect
        )!
        let ch149 = SpectrumHeatmapLayout.xPosition(
            forFrequencyMHz: 5000 + 149 * 5,
            domain: domain,
            in: rect
        )!
        let ch153 = SpectrumHeatmapLayout.xPosition(
            forFrequencyMHz: 5000 + 153 * 5,
            domain: domain,
            in: rect
        )!

        #expect(ch48 < ch149)
        #expect(ch149 - ch48 > ch153 - ch149)
        #expect(domain.regions.count == 2)
    }

    @Test func frequencyMappingHasAnInverse() {
        let domain = SpectrumHeatmapLayout.frequencyDomain(
            channels: [1, 6, 11],
            band: .band24GHz
        )
        let frequency = 2437.0
        let x = SpectrumHeatmapLayout.xPosition(forFrequencyMHz: frequency, domain: domain, in: rect)!
        let roundTrip = SpectrumHeatmapLayout.frequencyMHz(forX: x, domain: domain, in: rect)!

        #expect(abs(roundTrip - frequency) < 0.0001)
    }

    @Test func channelTicksUseOnlyProvidedLegalChannels() {
        let ticks = SpectrumHeatmapLayout.channelTicks(
            channels: [36, 40, 44, 48, 149, 153, 157, 161, 165],
            band: .band5GHz,
            in: rect,
            maximumCount: 4
        )

        #expect(!ticks.isEmpty)
        #expect(ticks.allSatisfy { [36, 40, 44, 48, 149, 153, 157, 161, 165].contains($0.channel) })
        #expect(ticks.last?.channel == 165)
    }

    @Test func invalidGeometryReturnsNoMapping() {
        let domain = SpectrumHeatmapLayout.frequencyDomain(channels: [], band: .band5GHz)
        #expect(SpectrumHeatmapLayout.xPosition(forFrequencyMHz: 5000, domain: domain, in: rect) == nil)
        #expect(SpectrumHeatmapLayout.frequencyMHz(forX: -1, domain: domain, in: rect) == nil)
    }
}
