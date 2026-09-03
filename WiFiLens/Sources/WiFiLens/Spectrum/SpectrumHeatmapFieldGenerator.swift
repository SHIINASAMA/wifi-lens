import CoreGraphics
import Foundation
import ChartLens

protocol SpectrumHeatmapFieldGenerating: Sendable {
    func generate(
        envelopes: [SpectrumHeatmapEnvelope],
        domain: SpectrumHeatmapFrequencyDomain,
        rssiRange: ClosedRange<Double>,
        resolution: SpectrumHeatmapResolution
    ) -> SpectrumHeatmapRaster
}

struct CPUHeatmapFieldGenerator: SpectrumHeatmapFieldGenerating, Sendable {
    init() {}

    func generate(
        envelopes: [SpectrumHeatmapEnvelope],
        domain: SpectrumHeatmapFrequencyDomain,
        rssiRange: ClosedRange<Double>,
        resolution: SpectrumHeatmapResolution
    ) -> SpectrumHeatmapRaster {
        let storageCount = resolution.storageCount
        guard storageCount > 0,
              !domain.regions.isEmpty,
              rssiRange.lowerBound.isFinite,
              rssiRange.upperBound.isFinite,
              rssiRange.lowerBound <= rssiRange.upperBound else {
            return SpectrumHeatmapRaster(
                width: resolution.width,
                height: resolution.height,
                values: Array(repeating: 0, count: storageCount)
            )
        }

        let rect = CGRect(x: 0, y: 0, width: resolution.width, height: resolution.height)
        let gaussians = envelopes.map { envelope in
            GaussianEnvelope(
                leftX: envelope.lowerFrequencyMHz,
                rightX: envelope.upperFrequencyMHz,
                peakY: envelope.peakRSSI,
                baselineY: Double(Constants.rssiNoiseFloor),
                sigma: envelope.sigmaMHz
            )
        }
        var values = Array(repeating: Float(0), count: storageCount)

        for y in 0..<resolution.height {
            guard let rssi = SpectrumHeatmapLayout.rssi(
                forY: CGFloat(y) + 0.5,
                in: rect,
                rssiRange: rssiRange
            ) else { continue }

            for x in 0..<resolution.width {
                guard let frequency = SpectrumHeatmapLayout.frequencyMHz(
                    forX: CGFloat(x) + 0.5,
                    domain: domain,
                    in: rect
                ) else { continue }

                var density = 0.0
                for (index, gaussian) in gaussians.enumerated() {
                    let curve = gaussian.value(atX: frequency)
                    let coverage: Double
                    if rssi <= curve - 3 {
                        coverage = 1
                    } else if rssi <= curve {
                        coverage = smoothstep((curve - rssi) / 3)
                    } else {
                        coverage = 0
                    }
                    density += coverage * Double(envelopes[index].weight)
                }

                let normalized = sqrt(max(0, min(density / 3.0, 1.0)))
                values[y * resolution.width + x] = Float(min(1, max(0, normalized)))
            }
        }

        return SpectrumHeatmapRaster(
            width: resolution.width,
            height: resolution.height,
            values: values
        )
    }

    private func smoothstep(_ value: Double) -> Double {
        let clamped = min(1, max(0, value))
        return clamped * clamped * (3 - 2 * clamped)
    }
}
