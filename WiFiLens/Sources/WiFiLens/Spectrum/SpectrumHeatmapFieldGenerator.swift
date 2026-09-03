import CoreGraphics
import Foundation

protocol SpectrumHeatmapFieldGenerating: Sendable {
    func generate(
        envelopes: [SpectrumHeatmapEnvelope],
        domain: SpectrumHeatmapChannelDomain,
        rssiRange: ClosedRange<Double>,
        resolution: SpectrumHeatmapResolution
    ) -> SpectrumHeatmapRaster
}

struct CPUHeatmapFieldGenerator: SpectrumHeatmapFieldGenerating, Sendable {
    private static let verticalDecayTauDB = 10.0
    private static let edgeFadeDB = 3.0

    init() {}

    func generate(
        envelopes: [SpectrumHeatmapEnvelope],
        domain: SpectrumHeatmapChannelDomain,
        rssiRange: ClosedRange<Double>,
        resolution: SpectrumHeatmapResolution
    ) -> SpectrumHeatmapRaster {
        let storageCount = resolution.storageCount
        guard storageCount > 0,
              domain.span > 0,
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
        var values = Array(repeating: Float(0), count: storageCount)

        for y in 0..<resolution.height {
            guard let rssi = SpectrumHeatmapLayout.rssi(
                forY: CGFloat(y) + 0.5,
                in: rect,
                rssiRange: rssiRange
            ) else { continue }

            for x in 0..<resolution.width {
                guard let channel = SpectrumHeatmapLayout.channelCoordinate(
                    forX: CGFloat(x) + 0.5,
                    domain: domain,
                    in: rect
                ) else { continue }

                var density = 0.0
                for envelope in envelopes {
                    guard channel >= envelope.leftX, channel <= envelope.rightX else { continue }
                    let gaussian = envelope.gaussian
                    let curve = gaussian.value(atX: channel)
                    let depthDB = curve - rssi
                    if depthDB >= 0 {
                        density += exp(-depthDB / Self.verticalDecayTauDB)
                    } else if depthDB >= -Self.edgeFadeDB {
                        let edge = (depthDB + Self.edgeFadeDB) / Self.edgeFadeDB
                        density += smoothstep(edge)
                    }
                }

                let normalized = sqrt(max(0, min(density / 4.0, 1.0)))
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
