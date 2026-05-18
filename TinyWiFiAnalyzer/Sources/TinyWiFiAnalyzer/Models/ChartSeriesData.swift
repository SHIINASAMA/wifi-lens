import SwiftUI
import Foundation

struct ChartSeriesData: Identifiable {
    let id: String  // "bssid-channel" for uniqueness
    let ssid: String
    let bssid: String
    let channel: Int
    let left: Int
    let apex: Double
    let right: Int
    let rssi: Int
    var color: Color = .gray
    var isFilteredOut: Bool = false

    var displaySSID: String { ssid.isEmpty ? "n/a" : ssid }

    /// Gaussian bell curve points from `left` to `right`.
    /// The curve is centered at the primary channel and drops to near the noise floor at the edges.
    var curvePoints: [(x: Double, y: Double)] {
        // Center at block midpoint (matching original Python app's apex)
        let center = Double(left + right) / 2.0
        let halfWidth = Double(right - left) / 2.0
        let sigma = halfWidth / 3.0  // curve drops to ~0 at edges
        let amplitude = Double(rssi - Constants.rssiNoiseFloor)  // positive value above floor
        let floor = Double(Constants.rssiNoiseFloor)
        let steps = 80
        var points: [(x: Double, y: Double)] = []

        for i in 0...steps {
            let x = Double(left) + (Double(right - left) * Double(i) / Double(steps))
            let d = x - center
            let g = exp(-(d * d) / (2 * sigma * sigma))
            let y = floor + amplitude * g
            points.append((x, y))
        }
        return points
    }
}
