import Foundation
import SwiftUI

struct BandChartLayout {
    struct HeatmapBar {
        let offset: CGFloat
        let color: Color
    }

    struct HeatmapBin {
        let apex: Int
        let colors: [Color]

        func bars(barWidth: CGFloat, barGap: CGFloat) -> [HeatmapBar] {
            colors.enumerated().map { index, color in
                let offset = CGFloat(index) * (barWidth + barGap) - CGFloat(colors.count - 1) * (barWidth + barGap) / 2
                return HeatmapBar(offset: offset, color: color)
            }
        }
    }

    struct Heatmap {
        let bins: [HeatmapBin]
        let maxCount: Int
    }

    struct LabelPlacement {
        let series: ChartSeriesData
        let x: CGFloat
        let y: CGFloat
        let opacity: Double
    }

    static func axisTickValues(xMin: Double, xMax: Double, maxChannel: Int, axisTickStartChannel: Int) -> [Int] {
        let desiredTicks = max(1, min(maxChannel - Int(xMin), 15))
        let rawStep = max(1, Int((xMax - xMin) / Double(desiredTicks)))
        let step = max(1, rawStep)
        return stride(from: Int(xMin), through: Int(xMax), by: step).filter { $0 >= axisTickStartChannel }
    }

    static func heatmapBins(series: [ChartSeriesData]) -> Heatmap {
        let grouped = Dictionary(grouping: series) { Int($0.apex.rounded()) }
        let bins = grouped.keys.sorted().map { apex in
            HeatmapBin(apex: apex, colors: grouped[apex]?.map(\.color) ?? [])
        }
        return Heatmap(bins: bins, maxCount: max(1, bins.map(\.colors.count).max() ?? 1))
    }

    static func placeLabels(
        seriesData: [ChartSeriesData],
        chartRect: CGRect,
        xMin: Double,
        scaleX: CGFloat,
        scaleY: CGFloat,
        yMin: Double,
        selectedNetworkID: String?
    ) -> [LabelPlacement] {
        let labelEstWidth: CGFloat = 100
        let labelEstHeight: CGFloat = 14
        let lineHeight: CGFloat = labelEstHeight + 2
        let hasSelection = selectedNetworkID != nil

        let candidates = seriesData
            .filter { ($0.isVisible && !$0.isFilteredOut) || $0.id == selectedNetworkID }
            .sorted { a, b in
                if a.id == selectedNetworkID { return true }
                if b.id == selectedNetworkID { return false }
                return a.rssi > b.rssi
            }

        var placed: [LabelPlacement] = []
        var occupied: [CGRect] = []

        for series in candidates {
            let px = chartRect.minX + (series.apex - xMin) * scaleX
            let naturalY = chartRect.maxY - (series.displayRSSI - yMin) * scaleY - 8
            let isSelected = series.id == selectedNetworkID
            let opacity: Double = hasSelection ? (isSelected ? 1.0 : 0.25) : 1.0

            var labelY = naturalY
            var fits = false
            for _ in 0..<6 {
                let rect = CGRect(
                    x: px - labelEstWidth / 2,
                    y: labelY - labelEstHeight,
                    width: labelEstWidth,
                    height: labelEstHeight
                )
                if !occupied.contains(where: { $0.intersects(rect) }) {
                    occupied.append(rect)
                    fits = true
                    break
                }
                labelY -= lineHeight
            }
            if !fits && !isSelected { continue }
            if !fits { labelY = naturalY }

            placed.append(LabelPlacement(series: series, x: px, y: labelY, opacity: opacity))
        }
        return placed
    }

    static func nearestSeries(at location: CGPoint, in series: [ChartSeriesData], geometry: ChartGeometry, radius: CGFloat) -> (ChartSeriesData, CGPoint)? {
        guard geometry.chartRect.contains(location) else { return nil }
        var best: (ChartSeriesData, CGPoint)?
        var bestDist: CGFloat = radius

        for s in series {
            let leftX = geometry.dataToPoint(x: Double(s.left), y: geometry.yMin).x
            let rightX = geometry.dataToPoint(x: Double(s.right), y: geometry.yMin).x
            if location.x < leftX - radius || location.x > rightX + radius { continue }

            for pt in s.displayCurvePoints {
                let screenPt = geometry.dataToPoint(x: pt.x, y: pt.y)
                let dx = screenPt.x - location.x
                let dy = screenPt.y - location.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < bestDist {
                    bestDist = dist
                    best = (s, screenPt)
                }
            }
        }
        return best
    }
}
