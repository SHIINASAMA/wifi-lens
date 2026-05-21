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
    var displayRSSI: Double = 0.0
    var color: Color = .gray
    var isFilteredOut: Bool = false
    var phyMode: String = ""
    var channelWidth: String = ""
    var supportsK: Bool = false
    var supportsR: Bool = false
    var supportsV: Bool = false
    var supportsWPA3: Bool = false
    var isHiddenSSID: Bool = false
    var security: String = ""
    var mcs: String = ""
    var nss: String = ""
    var country: String = ""
    var isVisible: Bool = true
    var qualityScore: Int = 0  // 0–100 composite score
    var trendArrow: String = ""   // ▲ / ▼ / ●
    var trendDelta: Int = 0

    var displaySSID: String { ssid.isEmpty ? "n/a" : ssid }

    /// Gaussian bell curve points spanning beyond `left`/`right` so the curve
    /// decays to near zero at the edges, creating a smooth tangent to the noise floor.
    var curvePoints: [(x: Double, y: Double)] {
        let center = Double(left + right) / 2.0
        let halfWidth = Double(right - left) / 2.0
        let sigma = halfWidth / 3.0
        let amplitude = Double(rssi - Constants.rssiNoiseFloor)
        let floor = Double(Constants.rssiNoiseFloor)
        let steps = 80

        // Extend by halfWidth on each side so the curve reaches ~exp(-18) ≈ 0 at the edges
        let startX = Double(left) - halfWidth
        let endX = Double(right) + halfWidth

        var points: [(x: Double, y: Double)] = []
        for i in 0...steps {
            let x = startX + (endX - startX) * Double(i) / Double(steps)
            let d = x - center
            let g = exp(-(d * d) / (2 * sigma * sigma))
            let y = floor + amplitude * g
            points.append((x, y))
        }
        return points
    }

    /// Same Gaussian curve but driven by `displayRSSI` for smooth animated transitions.
    var displayCurvePoints: [(x: Double, y: Double)] {
        let center = Double(left + right) / 2.0
        let halfWidth = Double(right - left) / 2.0
        let sigma = halfWidth / 3.0
        let amplitude = displayRSSI - Double(Constants.rssiNoiseFloor)
        let floor = Double(Constants.rssiNoiseFloor)
        let steps = 80

        let startX = Double(left) - halfWidth
        let endX = Double(right) + halfWidth

        var points: [(x: Double, y: Double)] = []
        for i in 0...steps {
            let x = startX + (endX - startX) * Double(i) / Double(steps)
            let d = x - center
            let g = exp(-(d * d) / (2 * sigma * sigma))
            let y = floor + amplitude * g
            points.append((x, y))
        }
        return points
    }
}
