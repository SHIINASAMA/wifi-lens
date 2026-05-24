import SwiftUI

// MARK: - Catmull-Rom Spline

/// Append Catmull-Rom spline curves to an existing path without an initial `move(to:)`.
func addCatmullRomSpline(to path: inout Path, points: [CGPoint]) {
    guard points.count >= 2 else { return }
    for i in 0..<(points.count - 1) {
        let p0 = i > 0 ? points[i - 1] : points[0]
        let p1 = points[i]
        let p2 = points[i + 1]
        let p3 = i + 2 < points.count ? points[i + 2] : points[points.count - 1]

        let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
        let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        path.addCurve(to: p2, control1: cp1, control2: cp2)
    }
}

/// Catmull-Rom spline as a standalone Path (includes initial `move(to:)`).
func catmullRomSpline(points: [CGPoint]) -> Path {
    var path = Path()
    guard points.count >= 2 else { return path }
    path.move(to: points[0])
    addCatmullRomSpline(to: &path, points: points)
    return path
}


/// Clamped cubic spline — control points are clamped within each segment's Y range to prevent overshoot.
func clampedCubicSpline(points: [CGPoint]) -> Path {
    var path = Path()
    guard points.count >= 2 else { return path }
    path.move(to: points[0])
    for i in 1..<points.count {
        let p0 = points[max(0, i - 2)]
        let p1 = points[i - 1]
        let p2 = points[i]
        let p3 = points[min(points.count - 1, i + 1)]

        let yMin = min(p1.y, p2.y)
        let yMax = max(p1.y, p2.y)

        let rawCP1y = p1.y + (p2.y - p0.y) / 6
        let rawCP2y = p2.y - (p3.y - p1.y) / 6

        let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                          y: min(max(rawCP1y, yMin), yMax))
        let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                          y: min(max(rawCP2y, yMin), yMax))
        path.addCurve(to: p2, control1: cp1, control2: cp2)
    }
    return path
}
