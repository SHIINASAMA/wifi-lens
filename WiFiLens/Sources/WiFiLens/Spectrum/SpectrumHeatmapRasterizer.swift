import CoreGraphics
import Foundation

struct SpectrumHeatmapTimeDomain: Equatable, Sendable {
    let start: Date
    let end: Date

    var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }
}

struct SpectrumHeatmapRaster: Equatable, Sendable {
    let width: Int
    let height: Int
    let values: [Double]

    init(width: Int, height: Int, values: [Double]) {
        self.width = max(0, width)
        self.height = max(0, height)
        self.values = values.count == self.width * self.height
            ? values
            : Array(values.prefix(self.width * self.height))
                + Array(repeating: 0, count: max(0, self.width * self.height - values.count))
    }

    func value(x: Int, y: Int) -> Double {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return 0 }
        return values[y * width + x]
    }
}

enum SpectrumHeatmapRasterizer {
    static let maxResolution = (width: 320, height: 96)

    static func resolution(for displaySize: CGSize) -> (width: Int, height: Int) {
        let width = min(maxResolution.width, max(1, Int(displaySize.width.rounded(.up))))
        let height = min(maxResolution.height, max(1, Int(displaySize.height.rounded(.up))))
        return (width, height)
    }

    static func rasterize(
        frames: [SpectrumHeatmapFrame],
        domain: SpectrumHeatmapFrequencyDomain,
        timeDomain: SpectrumHeatmapTimeDomain,
        size: CGSize
    ) -> SpectrumHeatmapRaster {
        let outputSize = resolution(for: size)
        guard !frames.isEmpty, timeDomain.duration > 0 else {
            return SpectrumHeatmapRaster(
                width: outputSize.width,
                height: outputSize.height,
                values: Array(repeating: 0, count: outputSize.width * outputSize.height)
            )
        }

        let sortedFrames = frames.sorted { $0.timestamp < $1.timestamp }
        let rasterRect = CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height)
        var values = Array(repeating: 0.0, count: outputSize.width * outputSize.height)

        for y in 0..<outputSize.height {
            let yFraction = outputSize.height == 1 ? 1.0 : Double(y) / Double(outputSize.height - 1)
            let timestamp = timeDomain.start.addingTimeInterval(yFraction * timeDomain.duration)
            for x in 0..<outputSize.width {
                guard let frequency = SpectrumHeatmapLayout.frequencyMHz(
                    forX: CGFloat(x) + 0.5,
                    domain: domain,
                    in: rasterRect
                ) else { continue }
                let activity = interpolatedActivity(
                    at: timestamp,
                    frequencyMHz: frequency,
                    frames: sortedFrames
                )
                values[y * outputSize.width + x] = SpectrumHeatmapActivity.normalizedIntensity(forActivity: activity)
            }
        }

        return SpectrumHeatmapRaster(width: outputSize.width, height: outputSize.height, values: values)
    }

    /// Applies a small spatial/temporal blur while refusing to sample across
    /// discontinuous frequency regions. The renderer can use this for its glow
    /// pass without inventing activity in the large 5 GHz gap.
    static func smooth(
        _ raster: SpectrumHeatmapRaster,
        domain: SpectrumHeatmapFrequencyDomain
    ) -> SpectrumHeatmapRaster {
        guard raster.width > 0, raster.height > 0 else { return raster }
        let rect = CGRect(x: 0, y: 0, width: raster.width, height: raster.height)
        var output = Array(repeating: 0.0, count: raster.width * raster.height)

        for y in 0..<raster.height {
            for x in 0..<raster.width {
                guard let frequency = SpectrumHeatmapLayout.frequencyMHz(
                    forX: CGFloat(x) + 0.5,
                    domain: domain,
                    in: rect
                ), domain.regions.contains(where: { $0.contains(frequency) }) else { continue }

                var sum = 0.0
                var count = 0.0
                for sampleY in max(0, y - 1)...min(raster.height - 1, y + 1) {
                    for sampleX in max(0, x - 2)...min(raster.width - 1, x + 2) {
                        guard let sampleFrequency = SpectrumHeatmapLayout.frequencyMHz(
                            forX: CGFloat(sampleX) + 0.5,
                            domain: domain,
                            in: rect
                        ), domain.regions.contains(where: { $0.contains(sampleFrequency) }) else { continue }
                        sum += raster.value(x: sampleX, y: sampleY)
                        count += 1
                    }
                }
                output[y * raster.width + x] = count > 0 ? sum / count : 0
            }
        }

        return SpectrumHeatmapRaster(width: raster.width, height: raster.height, values: output)
    }

    private static func interpolatedActivity(
        at timestamp: Date,
        frequencyMHz: Double,
        frames: [SpectrumHeatmapFrame]
    ) -> Double {
        guard let first = frames.first, let last = frames.last,
              timestamp >= first.timestamp, timestamp <= last.timestamp else { return 0 }
        if timestamp == first.timestamp { return activity(at: frequencyMHz, in: first) }
        if timestamp == last.timestamp { return activity(at: frequencyMHz, in: last) }

        guard let upperIndex = frames.firstIndex(where: { $0.timestamp >= timestamp }) else { return 0 }
        let upper = frames[upperIndex]
        let lower = frames[upperIndex - 1]
        let duration = upper.timestamp.timeIntervalSince(lower.timestamp)
        guard duration > 0 else { return activity(at: frequencyMHz, in: upper) }
        let fraction = timestamp.timeIntervalSince(lower.timestamp) / duration
        let lowerActivity = activity(at: frequencyMHz, in: lower)
        let upperActivity = activity(at: frequencyMHz, in: upper)
        return lowerActivity + (upperActivity - lowerActivity) * fraction
    }

    private static func activity(
        at frequencyMHz: Double,
        in frame: SpectrumHeatmapFrame
    ) -> Double {
        frame.spans.reduce(into: 0) { total, span in
            if span.lowerFrequencyMHz...span.upperFrequencyMHz ~= frequencyMHz {
                total += span.weight
            }
        }
    }
}
