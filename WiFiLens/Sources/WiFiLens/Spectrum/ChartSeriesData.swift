import SwiftUI
import Foundation
import ChartLens

struct ChartSeriesDomainData: Identifiable {
    let id: String
    let ssid: String
    let bssid: String
    let channel: Int
    let left: Int
    let apex: Double
    let right: Int
    let rssi: Int
    let phyMode: String
    let channelWidth: String
    let supportsK: Bool
    let supportsR: Bool
    let supportsV: Bool
    let supportsWPA3: Bool
    let isHiddenSSID: Bool
    let security: String
    let mcs: String
    let nss: String
    let country: String
}

struct ChartSeriesRenderState {
    var displayRSSI: Double = 0.0
    var color: Color = .gray
    var isFilteredOut: Bool = false
    var isVisible: Bool = true
    var visibilityLocked: Bool = false
    var qualityScore: Int = 0
    var trendArrow: String = ""
    var trendDelta: Int = 0
}

struct ChartSeriesData: Identifiable {
    let domain: ChartSeriesDomainData
    var render: ChartSeriesRenderState

    init(domain: ChartSeriesDomainData, render: ChartSeriesRenderState = .init()) {
        self.domain = domain
        self.render = render
    }

    init(
        id: String,
        ssid: String,
        bssid: String,
        channel: Int,
        left: Int,
        apex: Double,
        right: Int,
        rssi: Int,
        displayRSSI: Double = 0.0,
        color: Color = .gray,
        isFilteredOut: Bool = false,
        phyMode: String = "",
        channelWidth: String = "",
        supportsK: Bool = false,
        supportsR: Bool = false,
        supportsV: Bool = false,
        supportsWPA3: Bool = false,
        isHiddenSSID: Bool = false,
        security: String = "",
        mcs: String = "",
        nss: String = "",
        country: String = "",
        isVisible: Bool = true,
        visibilityLocked: Bool = false,
        qualityScore: Int = 0,
        trendArrow: String = "",
        trendDelta: Int = 0
    ) {
        self.domain = ChartSeriesDomainData(
            id: id,
            ssid: ssid,
            bssid: bssid,
            channel: channel,
            left: left,
            apex: apex,
            right: right,
            rssi: rssi,
            phyMode: phyMode,
            channelWidth: channelWidth,
            supportsK: supportsK,
            supportsR: supportsR,
            supportsV: supportsV,
            supportsWPA3: supportsWPA3,
            isHiddenSSID: isHiddenSSID,
            security: security,
            mcs: mcs,
            nss: nss,
            country: country
        )
        self.render = ChartSeriesRenderState(
            displayRSSI: displayRSSI,
            color: color,
            isFilteredOut: isFilteredOut,
            isVisible: isVisible,
            visibilityLocked: visibilityLocked,
            qualityScore: qualityScore,
            trendArrow: trendArrow,
            trendDelta: trendDelta
        )
    }

    var id: String { domain.id }
    var ssid: String { domain.ssid }
    var bssid: String { domain.bssid }
    var channel: Int { domain.channel }
    var left: Int { domain.left }
    var apex: Double { domain.apex }
    var right: Int { domain.right }
    var rssi: Int { domain.rssi }
    var phyMode: String { domain.phyMode }
    var channelWidth: String { domain.channelWidth }
    var supportsK: Bool { domain.supportsK }
    var supportsR: Bool { domain.supportsR }
    var supportsV: Bool { domain.supportsV }
    var supportsWPA3: Bool { domain.supportsWPA3 }
    var isHiddenSSID: Bool { domain.isHiddenSSID }
    var security: String { domain.security }
    var mcs: String { domain.mcs }
    var nss: String { domain.nss }
    var country: String { domain.country }

    var displayRSSI: Double {
        get { render.displayRSSI }
        set { render.displayRSSI = newValue }
    }

    var color: Color {
        get { render.color }
        set { render.color = newValue }
    }

    var isFilteredOut: Bool {
        get { render.isFilteredOut }
        set { render.isFilteredOut = newValue }
    }

    var isVisible: Bool {
        get { render.isVisible }
        set { render.isVisible = newValue }
    }

    var visibilityLocked: Bool {
        get { render.visibilityLocked }
        set { render.visibilityLocked = newValue }
    }

    var qualityScore: Int {
        get { render.qualityScore }
        set { render.qualityScore = newValue }
    }

    var trendArrow: String {
        get { render.trendArrow }
        set { render.trendArrow = newValue }
    }

    var trendDelta: Int {
        get { render.trendDelta }
        set { render.trendDelta = newValue }
    }

    var displaySSID: String { ssid.isEmpty ? "n/a" : ssid }

    var curvePoints: [(x: Double, y: Double)] {
        gaussianEnvelope(peakY: Double(rssi)).sampledPoints(count: 81)
    }

    var displayCurvePoints: [(x: Double, y: Double)] {
        gaussianEnvelope(peakY: displayRSSI).sampledPoints(count: 81)
    }

    private func gaussianEnvelope(peakY: Double) -> GaussianEnvelope {
        GaussianEnvelope(
            leftX: Double(left),
            rightX: Double(right),
            peakY: peakY,
            baselineY: Double(Constants.rssiNoiseFloor),
            sigma: Double(right - left) / 8.0
        )
    }
}
