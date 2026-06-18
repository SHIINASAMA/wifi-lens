import Foundation

struct ChartAxisLabelRects: Equatable, Sendable {
    let yAxis: CGRect
    let xAxis: CGRect
}

struct ChartRegions: Equatable, Sendable {
    let frameRect: CGRect
    let plotRect: CGRect
    let annotationRect: CGRect
    let axisLabelRects: ChartAxisLabelRects
}

/// Coordinate mapping between data space and chart pixel space.
struct ChartGeometry: Sendable {
    let frameRect: CGRect
    let plotRect: CGRect
    let annotationRect: CGRect
    let axisLabelRects: ChartAxisLabelRects
    let xMin: Double
    let xMax: Double
    let yMin: Double
    let yMax: Double

    var chartRect: CGRect { plotRect }
    var scaleX: CGFloat { plotRect.width / max(1e-6, xMax - xMin) }
    var scaleY: CGFloat { plotRect.height / max(1e-6, yMax - yMin) }

    init(
        frameRect: CGRect,
        plotRect: CGRect,
        annotationRect: CGRect,
        axisLabelRects: ChartAxisLabelRects,
        xMin: Double,
        xMax: Double,
        yMin: Double,
        yMax: Double
    ) {
        self.frameRect = frameRect
        self.plotRect = plotRect
        self.annotationRect = annotationRect
        self.axisLabelRects = axisLabelRects
        self.xMin = xMin
        self.xMax = xMax
        self.yMin = yMin
        self.yMax = yMax
    }

    init(chartRect: CGRect, xMin: Double, xMax: Double, yMin: Double, yMax: Double) {
        self.init(
            frameRect: chartRect,
            plotRect: chartRect,
            annotationRect: chartRect,
            axisLabelRects: ChartAxisLabelRects(yAxis: .zero, xAxis: .zero),
            xMin: xMin,
            xMax: xMax,
            yMin: yMin,
            yMax: yMax
        )
    }

    func dataToPoint(x: Double, y: Double) -> CGPoint {
        CGPoint(
            x: plotRect.minX + (x - xMin) * scaleX,
            y: plotRect.maxY - (y - yMin) * scaleY
        )
    }

    func pointToData(screenPoint: CGPoint) -> (x: Double, y: Double) {
        let x = xMin + (screenPoint.x - plotRect.minX) / scaleX
        let y = yMin + (plotRect.maxY - screenPoint.y) / scaleY
        return (x, y)
    }
}
