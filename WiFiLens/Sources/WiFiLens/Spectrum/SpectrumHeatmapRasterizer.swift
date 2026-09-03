import CoreGraphics

struct SpectrumHeatmapResolution: Equatable, Sendable {
    static let standard = SpectrumHeatmapResolution(width: 640, height: 256)

    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        let sanitizedWidth = max(0, width)
        let sanitizedHeight = max(0, height)

        guard sanitizedWidth > 0, sanitizedHeight > 0 else {
            self.width = sanitizedWidth
            self.height = sanitizedHeight
            return
        }

        let product = sanitizedWidth.multipliedReportingOverflow(by: sanitizedHeight)
        guard !product.overflow else {
            self.width = 0
            self.height = 0
            return
        }

        self.width = sanitizedWidth
        self.height = sanitizedHeight
    }

    var storageCount: Int {
        guard width > 0, height > 0 else { return 0 }
        let count = width.multipliedReportingOverflow(by: height)
        guard !count.overflow else {
            return 0
        }
        return count.partialValue
    }
}

struct SpectrumHeatmapRaster: Equatable, Sendable {
    let width: Int
    let height: Int
    let values: [Float]

    init(width: Int, height: Int, values: [Float]) {
        let resolution = SpectrumHeatmapResolution(width: width, height: height)
        self.width = resolution.width
        self.height = resolution.height

        let expectedCount = resolution.storageCount
        if values.count == expectedCount {
            self.values = values
        } else if values.count > expectedCount {
            self.values = Array(values.prefix(expectedCount))
        } else {
            self.values = values + Array(repeating: 0, count: expectedCount - values.count)
        }
    }

    func value(x: Int, y: Int) -> Float {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return 0 }
        return values[y * width + x]
    }
}

struct SpectrumHeatmapRenderKey: Equatable, Sendable {
    let model: SpectrumHeatmapModel
    let domain: SpectrumHeatmapFrequencyDomain
    let rssiRange: ClosedRange<Double>
    let resolution: SpectrumHeatmapResolution
}

/// Retains the last field result for a panel. The key includes every input to
/// field generation and smoothing, so SwiftUI body reevaluation cannot repeat
/// identical CPU work.
final class SpectrumHeatmapRenderCache {
    private struct Entry {
        let key: SpectrumHeatmapRenderKey
        let raster: SpectrumHeatmapRaster
    }

    private var entry: Entry?

    func smoothedRaster(
        for key: SpectrumHeatmapRenderKey,
        generate: () -> SpectrumHeatmapRaster,
        smooth: (SpectrumHeatmapRaster) -> SpectrumHeatmapRaster
    ) -> SpectrumHeatmapRaster {
        if let entry, entry.key == key {
            return entry.raster
        }

        let raster = generate()
        let smoothed = smooth(raster)
        entry = Entry(key: key, raster: smoothed)
        return smoothed
    }
}

enum SpectrumHeatmapRasterizer {
    static let resolution = SpectrumHeatmapResolution.standard

    /// Applies a small spatial blur without sampling across a discontinuous
    /// frequency region. The temporal axis was removed from the heatmap, so
    /// this operation only considers nearby raster pixels.
    static func smooth(
        _ raster: SpectrumHeatmapRaster,
        domain: SpectrumHeatmapFrequencyDomain
    ) -> SpectrumHeatmapRaster {
        guard raster.width > 0, raster.height > 0 else { return raster }

        let rect = CGRect(x: 0, y: 0, width: raster.width, height: raster.height)
        var output = Array(repeating: Float(0), count: raster.values.count)

        for y in 0..<raster.height {
            for x in 0..<raster.width {
                guard let frequency = SpectrumHeatmapLayout.frequencyMHz(
                    forX: CGFloat(x) + 0.5,
                    domain: domain,
                    in: rect
                ), let region = regionIndex(for: frequency, in: domain.regions) else {
                    continue
                }

                var sum = 0.0
                var count = 0.0
                for sampleY in max(0, y - 1)...min(raster.height - 1, y + 1) {
                    for sampleX in max(0, x - 2)...min(raster.width - 1, x + 2) {
                        guard let sampleFrequency = SpectrumHeatmapLayout.frequencyMHz(
                            forX: CGFloat(sampleX) + 0.5,
                            domain: domain,
                            in: rect
                        ), regionIndex(for: sampleFrequency, in: domain.regions) == region else {
                            continue
                        }
                        sum += Double(raster.value(x: sampleX, y: sampleY))
                        count += 1
                    }
                }

                let average = count > 0 ? sum / count : 0
                output[y * raster.width + x] = Float(min(1, max(0, average)))
            }
        }

        return SpectrumHeatmapRaster(width: raster.width, height: raster.height, values: output)
    }

    private static func regionIndex(
        for frequency: Double,
        in regions: [ClosedRange<Double>]
    ) -> Int? {
        regions.firstIndex { $0.contains(frequency) }
    }
}
