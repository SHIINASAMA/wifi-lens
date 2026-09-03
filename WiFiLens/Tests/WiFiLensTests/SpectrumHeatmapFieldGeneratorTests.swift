import CoreGraphics
import Testing
@testable import WiFi_Lens

@Suite struct SpectrumHeatmapFieldGeneratorTests {
    private let generator = CPUHeatmapFieldGenerator()
    private let resolution = SpectrumHeatmapResolution(width: 640, height: 256)
    private let rssiRange = (-100.0)...(-30.0)

    private var singleRegionDomain: SpectrumHeatmapFrequencyDomain {
        SpectrumHeatmapFrequencyDomain(
            minFrequencyMHz: 2400,
            maxFrequencyMHz: 2440,
            regions: [2400...2440]
        )
    }

    private func envelope(
        lower: Double = 2408,
        upper: Double = 2432,
        peakRSSI: Double = -50,
        sigma: Double = 3,
        weight: Float = 1
    ) -> SpectrumHeatmapEnvelope {
        SpectrumHeatmapEnvelope(
            lowerFrequencyMHz: lower,
            upperFrequencyMHz: upper,
            peakRSSI: peakRSSI,
            sigmaMHz: sigma,
            weight: weight
        )
    }

    private func pixel(
        forFrequency frequency: Double,
        rssi: Double,
        domain: SpectrumHeatmapFrequencyDomain = SpectrumHeatmapFrequencyDomain(
            minFrequencyMHz: 2400,
            maxFrequencyMHz: 2440,
            regions: [2400...2440]
        )
    ) -> (x: Int, y: Int) {
        let rect = CGRect(x: 0, y: 0, width: resolution.width, height: resolution.height)
        let x = Int((SpectrumHeatmapLayout.xPosition(forFrequencyMHz: frequency, domain: domain, in: rect)! - 0.5).rounded())
        let y = Int((SpectrumHeatmapLayout.yPosition(forRSSI: rssi, in: rect, rssiRange: rssiRange)! - 0.5).rounded())
        return (
            min(max(0, x), resolution.width - 1),
            min(max(0, y), resolution.height - 1)
        )
    }

    @Test func producesExactFloat32StorageAndBoundsSafeReads() {
        let raster = generator.generate(
            envelopes: [],
            domain: singleRegionDomain,
            rssiRange: rssiRange,
            resolution: resolution
        )

        #expect(raster.width == 640)
        #expect(raster.height == 256)
        #expect(raster.values.count == 640 * 256)
        #expect(raster.value(x: -1, y: 0) == 0)
        #expect(raster.value(x: 640, y: 0) == 0)
        #expect(raster.value(x: 0, y: -1) == 0)
        #expect(raster.value(x: 0, y: 256) == 0)
    }

    @Test func overflowedDimensionsAreSanitizedBeforeBoundsChecks() {
        let raster = SpectrumHeatmapRaster(width: Int.max, height: 2, values: [])

        #expect(raster.width == 0)
        #expect(raster.height == 0)
        #expect(raster.values.isEmpty)
        #expect(raster.value(x: 0, y: 0) == 0)
    }

    @Test func repeatedGenerationIsDeterministic() {
        let envelopes = [envelope(), envelope(lower: 2418, upper: 2442, peakRSSI: -65, weight: 0.5)]

        let first = generator.generate(
            envelopes: envelopes,
            domain: singleRegionDomain,
            rssiRange: rssiRange,
            resolution: resolution
        )
        let second = generator.generate(
            envelopes: envelopes,
            domain: singleRegionDomain,
            rssiRange: rssiRange,
            resolution: resolution
        )

        #expect(first == second)
    }

    @Test func emptyEnvelopeListProducesOnlyZeroValues() {
        let raster = generator.generate(
            envelopes: [],
            domain: singleRegionDomain,
            rssiRange: rssiRange,
            resolution: resolution
        )

        #expect(raster.values.allSatisfy { $0 == 0 })
    }

    @Test func singleGaussianOnlyCoversRSSIAtOrBelowItsCurve() {
        let raster = generator.generate(
            envelopes: [envelope()],
            domain: singleRegionDomain,
            rssiRange: rssiRange,
            resolution: resolution
        )
        let center = pixel(forFrequency: 2420, rssi: -50)
        let aboveCurve = pixel(forFrequency: 2420, rssi: -45)
        let belowCurve = pixel(forFrequency: 2420, rssi: -90)

        #expect(raster.value(x: center.x, y: aboveCurve.y) == 0)
        #expect(raster.value(x: center.x, y: belowCurve.y) > 0)
    }

    @Test func sampledPixelsAboveTheGaussianCurveRemainZero() {
        let testEnvelope = envelope()
        let raster = generator.generate(
            envelopes: [testEnvelope],
            domain: singleRegionDomain,
            rssiRange: rssiRange,
            resolution: resolution
        )
        let rect = CGRect(x: 0, y: 0, width: resolution.width, height: resolution.height)
        let gaussian = SpectrumHeatmapActivity.gaussianEnvelope(for: testEnvelope)

        for x in stride(from: 0, to: resolution.width, by: 37) {
            guard let frequency = SpectrumHeatmapLayout.frequencyMHz(
                forX: CGFloat(x) + 0.5,
                domain: singleRegionDomain,
                in: rect
            ) else { continue }
            let curve = gaussian.value(atX: frequency)
            for y in stride(from: 0, to: resolution.height, by: 11) {
                guard let rssi = SpectrumHeatmapLayout.rssi(
                    forY: CGFloat(y) + 0.5,
                    in: rect,
                    rssiRange: rssiRange
                ) else { continue }
                if rssi > curve {
                    #expect(raster.value(x: x, y: y) == 0)
                }
            }
        }
    }

    @Test func strongerEnvelopeIsBrighterThanWeakerEnvelope() {
        let strong = generator.generate(
            envelopes: [envelope(peakRSSI: -45, weight: 1)],
            domain: singleRegionDomain,
            rssiRange: rssiRange,
            resolution: resolution
        )
        let weak = generator.generate(
            envelopes: [envelope(peakRSSI: -90, weight: 0.15)],
            domain: singleRegionDomain,
            rssiRange: rssiRange,
            resolution: resolution
        )
        let sample = pixel(forFrequency: 2420, rssi: -95)

        #expect(strong.value(x: sample.x, y: sample.y) > weak.value(x: sample.x, y: sample.y))
    }

    @Test func overlappingEnvelopesAccumulateAtTheSamePixel() {
        let one = generator.generate(
            envelopes: [envelope()],
            domain: singleRegionDomain,
            rssiRange: rssiRange,
            resolution: resolution
        )
        let two = generator.generate(
            envelopes: [envelope(), envelope()],
            domain: singleRegionDomain,
            rssiRange: rssiRange,
            resolution: resolution
        )
        let sample = pixel(forFrequency: 2420, rssi: -95)

        #expect(two.value(x: sample.x, y: sample.y) > one.value(x: sample.x, y: sample.y))
        #expect(abs(Double(one.value(x: sample.x, y: sample.y)) - sqrt(1.0 / 3.0)) < 0.01)
        #expect(abs(Double(two.value(x: sample.x, y: sample.y)) - sqrt(2.0 / 3.0)) < 0.01)
    }

    @Test func aggregateDensityAtLeastThreeSaturatesNormalization() {
        let raster = generator.generate(
            envelopes: [envelope(), envelope(), envelope()],
            domain: singleRegionDomain,
            rssiRange: rssiRange,
            resolution: resolution
        )
        let sample = pixel(forFrequency: 2420, rssi: -95)

        #expect(raster.value(x: sample.x, y: sample.y) == 1)
    }

    @Test func disjointEnvelopesProduceUnionCoverage() {
        let domain = SpectrumHeatmapFrequencyDomain(
            minFrequencyMHz: 2390,
            maxFrequencyMHz: 2470,
            regions: [2390...2470]
        )
        let raster = generator.generate(
            envelopes: [
                envelope(lower: 2400, upper: 2410, sigma: 0.5),
                envelope(lower: 2450, upper: 2460, sigma: 0.5)
            ],
            domain: domain,
            rssiRange: rssiRange,
            resolution: resolution
        )
        let left = pixel(forFrequency: 2405, rssi: -95, domain: domain)
        let right = pixel(forFrequency: 2455, rssi: -95, domain: domain)
        let middle = pixel(forFrequency: 2430, rssi: -95, domain: domain)

        #expect(raster.value(x: left.x, y: left.y) > 0)
        #expect(raster.value(x: right.x, y: right.y) > 0)
        #expect(raster.value(x: middle.x, y: middle.y) == 0)
    }

    @Test func threeDecibelCoverageEdgeIsZeroAndTransitionIsMonotonic() {
        let domain = singleRegionDomain
        let rect = CGRect(x: 0, y: 0, width: resolution.width, height: resolution.height)
        let curveRSSI = SpectrumHeatmapLayout.rssi(
            forY: 100.5,
            in: rect,
            rssiRange: rssiRange
        )!
        let raster = generator.generate(
            envelopes: [envelope(peakRSSI: curveRSSI)],
            domain: domain,
            rssiRange: rssiRange,
            resolution: resolution
        )
        let x = pixel(forFrequency: 2420, rssi: curveRSSI, domain: domain).x

        #expect(raster.value(x: x, y: 100) == 0)
        #expect(raster.value(x: x, y: 130) > 0)
        for y in 100..<130 {
            #expect(raster.value(x: x, y: y) <= raster.value(x: x, y: y + 1) + 0.0001)
        }
    }

    @Test func gapPixelsRemainZeroForBrokenFrequencyDomain() {
        let domain = SpectrumHeatmapLayout.frequencyDomain(
            channels: [36, 40, 44, 48, 149, 153, 157, 161, 165],
            band: .band5GHz
        )
        let raster = generator.generate(
            envelopes: [envelope(lower: 5170, upper: 5240, peakRSSI: -45, sigma: 4)],
            domain: domain,
            rssiRange: rssiRange,
            resolution: resolution
        )
        let rect = CGRect(x: 0, y: 0, width: resolution.width, height: resolution.height)
        let gapColumns = (0..<resolution.width).filter { x in
            SpectrumHeatmapLayout.frequencyMHz(forX: CGFloat(x) + 0.5, domain: domain, in: rect) == nil
        }

        #expect(!gapColumns.isEmpty)
        #expect(gapColumns.allSatisfy { x in
            (0..<resolution.height).allSatisfy { y in raster.value(x: x, y: y) == 0 }
        })
    }

    @Test func smoothingStaysWithinContiguousRegionsAndClampsOutput() {
        let domain = SpectrumHeatmapFrequencyDomain(
            minFrequencyMHz: 0,
            maxFrequencyMHz: 100,
            regions: [0...20, 80...100]
        )
        let raw = SpectrumHeatmapRaster(
            width: 100,
            height: 5,
            values: {
                var values = Array(repeating: Float(0), count: 500)
                values[2 * 100 + 20] = 1
                return values
            }()
        )

        let smoothed = SpectrumHeatmapRasterizer.smooth(raw, domain: domain)

        #expect(smoothed.value(x: 19, y: 2) > 0)
        #expect((45...55).allSatisfy { x in
            (0..<5).allSatisfy { y in smoothed.value(x: x, y: y) == 0 }
        })
        #expect(smoothed.values.allSatisfy { (0...1).contains($0) })
    }
}
