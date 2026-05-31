import Foundation

/// Coordinate mapping between data space and chart pixel space.
struct ChartGeometry {
    let chartRect: CGRect
    let xMin: Double
    let xMax: Double
    let yMin: Double
    let yMax: Double

    var scaleX: CGFloat { chartRect.width / max(1e-6, xMax - xMin) }
    var scaleY: CGFloat { chartRect.height / max(1e-6, yMax - yMin) }

    func dataToPoint(x: Double, y: Double) -> CGPoint {
        CGPoint(
            x: chartRect.minX + (x - xMin) * scaleX,
            y: chartRect.maxY - (y - yMin) * scaleY
        )
    }

    func pointToData(screenPoint: CGPoint) -> (x: Double, y: Double) {
        let x = xMin + (screenPoint.x - chartRect.minX) / scaleX
        let y = yMin + (chartRect.maxY - screenPoint.y) / scaleY
        return (x, y)
    }
}
