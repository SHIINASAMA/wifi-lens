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

        let ch36 = SpectrumHeatmapLayout.xPosition(
            forFrequencyMHz: 5180,
            domain: domain,
            in: rect
        )!
        let ch40 = SpectrumHeatmapLayout.xPosition(
            forFrequencyMHz: 5200,
            domain: domain,
            in: rect
        )!
        let firstRegionDelta = ch40 - ch36
        let firstFrequencyDelta = 5200.0 - 5180.0
        let ch157 = SpectrumHeatmapLayout.xPosition(
            forFrequencyMHz: 5000 + 157 * 5,
            domain: domain,
            in: rect
        )!
        let secondRegionDelta = ch157 - ch153
        let secondFrequencyDelta = 5785.0 - 5765.0
        #expect(abs(Double(firstRegionDelta) / firstFrequencyDelta - Double(secondRegionDelta) / secondFrequencyDelta) < 0.01)

        let gapStart = SpectrumHeatmapLayout.xPosition(
            forFrequencyMHz: domain.regions[0].upperBound,
            domain: domain,
            in: rect
        )!
        let gapEnd = SpectrumHeatmapLayout.xPosition(
            forFrequencyMHz: domain.regions[1].lowerBound,
            domain: domain,
            in: rect
        )!
        #expect(gapEnd - gapStart > rect.width * 0.1)
        #expect(SpectrumHeatmapLayout.frequencyMHz(
            forX: (gapStart + gapEnd) / 2,
            domain: domain,
            in: rect
        ) == nil)

        for frequency in [5180.0, 5200.0, 5745.0, 5805.0] {
            let x = SpectrumHeatmapLayout.xPosition(forFrequencyMHz: frequency, domain: domain, in: rect)!
            let roundTrip = SpectrumHeatmapLayout.frequencyMHz(forX: x, domain: domain, in: rect)!
            #expect(abs(roundTrip - frequency) < 0.0001)
        }

        let rightmostX = SpectrumHeatmapLayout.xPosition(
            forFrequencyMHz: domain.regions[1].upperBound,
            domain: domain,
            in: rect
        )!
        #expect(rightmostX == rect.maxX)
        #expect(SpectrumHeatmapLayout.frequencyMHz(forX: rightmostX, domain: domain, in: rect) == domain.regions[1].upperBound)
    }

    @Test func frequencyDomainHandlesSingletonAndEmptyInput() {
        let singleton = SpectrumHeatmapLayout.frequencyDomain(channels: [36], band: .band5GHz)
        #expect(singleton.regions.count == 1)
        #expect(SpectrumHeatmapLayout.xPosition(forFrequencyMHz: 5180, domain: singleton, in: rect) == rect.midX)

        let empty = SpectrumHeatmapLayout.frequencyDomain(channels: [], band: .band5GHz)
        #expect(empty.regions.isEmpty)
        #expect(SpectrumHeatmapLayout.xPosition(forFrequencyMHz: 0, domain: empty, in: rect) == nil)
    }

    @Test func frequencyDomainUsesBandSpecificPhysicalSpacing() {
        let band24 = SpectrumHeatmapLayout.frequencyDomain(channels: [1, 2, 3], band: .band24GHz)
        let band6 = SpectrumHeatmapLayout.frequencyDomain(channels: [1, 5, 9], band: .band6GHz)
        #expect(band24.regions[0].upperBound - band24.regions[0].lowerBound == 15)
        #expect(band6.regions[0].upperBound - band6.regions[0].lowerBound == 60)

        let fiveGHzBreak = SpectrumHeatmapLayout.frequencyDomain(
            channels: [140, 144, 149],
            band: .band5GHz
        )
        #expect(fiveGHzBreak.regions.count == 2)
    }

    @Test func legalJapaneseChannel14EnvelopeStaysCenteredOn2484MHz() {
        let legalJapaneseChannels = RegulatoryDatabase.rules[.JP]?["24"]?.allowedChannels ?? []
        #expect(legalJapaneseChannels.contains(14))

        let network = WiFiNetwork(
            ssid: "JP",
            bssid: "aa:bb:cc:dd:ee:14",
            rssi: -50,
            channel: WiFiChannel(band: .band24GHz, channelNumber: 14, channelWidthMHz: 20)
        )
        let envelope = SpectrumHeatmapActivity.envelope(for: network, band: .band24GHz)

        #expect(envelope?.lowerFrequencyMHz == 2474)
        #expect(envelope?.upperFrequencyMHz == 2494)
        #expect(envelope.map { ($0.lowerFrequencyMHz + $0.upperFrequencyMHz) / 2 } == 2484)
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

    @Test func channelTicksAreCappedAndUseBrokenProjection() {
        let channels = [36, 40, 44, 48, 149, 153, 157, 161, 165, 169, 173, 177]
        let ticks = SpectrumHeatmapLayout.channelTicks(
            channels: channels,
            band: .band5GHz,
            in: rect,
            maximumCount: 20
        )
        #expect(ticks.count <= 10)
        #expect(ticks.first?.channel == 36)
        #expect(ticks.last?.channel == 177)
    }

    @Test func fixedRSSIProjectionHasExactRoundTrips() {
        let rssiRange = -100.0...(-30.0)
        for rssi in [-100.0, -70.0, -30.0] {
            let y = SpectrumHeatmapLayout.yPosition(forRSSI: rssi, in: rect, rssiRange: rssiRange)!
            let roundTrip = SpectrumHeatmapLayout.rssi(forY: y, in: rect, rssiRange: rssiRange)!
            #expect(abs(roundTrip - rssi) < 0.0001)
        }
        let bottomY = SpectrumHeatmapLayout.yPosition(forRSSI: -100, in: rect, rssiRange: rssiRange)!
        #expect(bottomY == rect.maxY)
        #expect(SpectrumHeatmapLayout.rssi(forY: bottomY, in: rect, rssiRange: rssiRange) == -100)
        #expect(SpectrumHeatmapLayout.yPosition(forRSSI: -120, in: rect, rssiRange: rssiRange) == rect.maxY)
        #expect(SpectrumHeatmapLayout.yPosition(forRSSI: -10, in: rect, rssiRange: rssiRange) == rect.minY)
    }

    @Test func inverseRSSIProjectionRejectsOutsidePlot() {
        let rssiRange = -100.0...(-30.0)
        #expect(SpectrumHeatmapLayout.rssi(forY: rect.minY - 1, in: rect, rssiRange: rssiRange) == nil)
        #expect(SpectrumHeatmapLayout.rssi(forY: rect.maxY + 1, in: rect, rssiRange: rssiRange) == nil)
    }

    @Test func invalidGeometryReturnsNoMapping() {
        let domain = SpectrumHeatmapLayout.frequencyDomain(channels: [], band: .band5GHz)
        #expect(SpectrumHeatmapLayout.xPosition(forFrequencyMHz: 5000, domain: domain, in: rect) == nil)
        #expect(SpectrumHeatmapLayout.frequencyMHz(forX: -1, domain: domain, in: rect) == nil)
    }
}
