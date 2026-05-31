import SwiftUI

// MARK: - Chart Point

/// A single data point in chart data-space coordinates.
struct ChartPoint {
    var x: Double
    var y: Double
}

// MARK: - Chart Series

/// One renderable series — points + how to draw them.
struct ChartSeries {
    let id: String
    var points: [ChartPoint]
    var style: ChartSeriesStyle

    struct ChartSeriesStyle {
        var color: Color = .blue
        var lineWidth: CGFloat = 1.5
        var areaOpacity: Double = 0     // 0 = no fill below the curve
        var pointRadius: CGFloat = 0    // 0 = no dot markers
        var strokeOpacity: Double = 1.0
        var interpolation: Interpolation = .linear
        /// Y value for area fill baseline. nil = chart bottom (geo.chartRect.maxY).
        var baseline: Double? = nil

        static func area(color: Color, opacity: Double = 0.12, lineWidth: CGFloat = 1.5) -> ChartSeriesStyle {
            ChartSeriesStyle(color: color, lineWidth: lineWidth, areaOpacity: opacity, interpolation: .linear)
        }

        static func line(color: Color, lineWidth: CGFloat = 1.5) -> ChartSeriesStyle {
            ChartSeriesStyle(color: color, lineWidth: lineWidth, areaOpacity: 0, interpolation: .linear)
        }

        static func dots(color: Color, radius: CGFloat = 2) -> ChartSeriesStyle {
            ChartSeriesStyle(color: color, lineWidth: 0, areaOpacity: 0, pointRadius: radius, interpolation: .linear)
        }
    }

    enum Interpolation: Equatable {
        case linear
        case catmullRom
        case clampedCubic
        case step
        /// Gaussian bell curve — `width` is the sigma, `baseline` is the floor y value.
        case gaussian(sigma: Double, baseline: Double)
    }
}

// MARK: - Chart Axis Config

struct ChartAxisConfig {
    var yMin: Double? = nil       // nil = auto-compute from data
    var yMax: Double? = nil       // nil = auto-compute from data
    var xMin: Double? = nil       // nil = auto-compute from data
    var xMax: Double? = nil       // nil = auto-compute from data
    var yStep: Double = 10        // grid line interval
    var xTicks: [XTick] = []
    var showYGrid: Bool = true
    var showXGrid: Bool = false
    var showYAxis: Bool = true
    var showXAxis: Bool = true
    var clipToRect: Bool = true
    var yTickLabelOffset: CGFloat = 14   // pixels left of the axis line
    var xTickLabelOffset: CGFloat = 10   // pixels below the axis line
    var gridColor: Color = .gray.opacity(0.15)
    var axisColor: Color = .secondary
    var yTickFont: Font = .caption2
    var xTickFont: Font = .caption2
    var yTickColor: Color = .secondary
    var xTickColor: Color = .secondary

    struct XTick {
        var position: Double    // data-space x
        var label: String
    }
}

// MARK: - Chart Style (Layout)

struct ChartStyle {
    var leftAxisWidth: CGFloat = 36
    var bottomAxisHeight: CGFloat = 20
    var marginTop: CGFloat = 8
    var marginRight: CGFloat = 8
    var marginBottom: CGFloat = 4

    func chartRect(size: CGSize) -> CGRect {
        CGRect(
            x: leftAxisWidth,
            y: marginTop,
            width: size.width - leftAxisWidth - marginRight,
            height: size.height - bottomAxisHeight - marginTop - marginBottom
        )
    }
}

// MARK: - Chart Interaction

struct ChartInteraction: @unchecked Sendable {
    var onHover: (@MainActor (ChartPoint?, CGPoint?) -> Void)?
    var onTap: (@MainActor (ChartPoint?) -> Void)?
    var onZoom: (@MainActor (Double, Double) -> Void)?
    var zoomGestureEnabled: Bool = false
}
