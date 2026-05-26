import SwiftUI

@MainActor
@Observable
final class BandChartViewModel {
    private struct RenderSnapshot {
        var allSeriesData: [ChartSeriesData]
        var displayedSeriesData: [ChartSeriesData]
        var snapshots: [String: [NetworkSnapshot]]
        var channelOccupancy: [Int: Int]
    }

    let band: ChannelBand

    var isFrozen: Bool = false
    var isExpanded: Bool = false
    var zoomMin: Double?
    var zoomMax: Double?
    var showFilterPopover: Bool = false

    private(set) var allSeriesData: [ChartSeriesData] = []
    private(set) var displayedSeriesData: [ChartSeriesData] = []
    private(set) var interfaceName: String = ""
    private(set) var currentFilterQuery: String = ""
    private(set) var allSnapshots: [String: [NetworkSnapshot]] = [:]  // bssid → snapshots
    private(set) var channelOccupancy: [Int: Int] = [:]  // channel → network count
    private var currentHiddenBands: Set<String> = []
    private var currentHideHiddenSSIDs: Bool = false
    private var frozenSnapshot: RenderSnapshot?
    private var animationTimer: Timer?
    var chartSize: CGSize = .zero

    var hasFilter: Bool { !currentFilterQuery.trimmingCharacters(in: .whitespaces).isEmpty }
    var renderedAllSeriesData: [ChartSeriesData] { frozenSnapshot?.allSeriesData ?? allSeriesData }
    var renderedDisplayedSeriesData: [ChartSeriesData] { frozenSnapshot?.displayedSeriesData ?? displayedSeriesData }
    var renderedSnapshots: [String: [NetworkSnapshot]] { frozenSnapshot?.snapshots ?? allSnapshots }
    var renderedChannelOccupancy: [Int: Int] { frozenSnapshot?.channelOccupancy ?? channelOccupancy }
    var renderedNetworkCount: Int { renderedAllSeriesData.count }
    var renderedIsEmpty: Bool { renderedAllSeriesData.isEmpty }

    init(band: ChannelBand) {
        self.band = band
    }

    private func makeDisplayedSeriesData(from source: [ChartSeriesData], hiddenBands: Set<String>, hideHiddenSSIDs: Bool) -> [ChartSeriesData] {
        let needle = currentFilterQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let bandHidden = hiddenBands.contains(band.id)
        return source.map { series in
            var series = series
            let textFilter = needle.isEmpty
                || series.ssid.lowercased().contains(needle)
                || series.bssid.lowercased().contains(needle)
            let hiddenSSIDFilter = !hideHiddenSSIDs || !series.isHiddenSSID
            series.isFilteredOut = bandHidden || !textFilter || !hiddenSSIDFilter
            return series
        }
    }

    private func currentRenderSnapshot() -> RenderSnapshot {
        RenderSnapshot(
            allSeriesData: allSeriesData,
            displayedSeriesData: displayedSeriesData,
            snapshots: allSnapshots,
            channelOccupancy: channelOccupancy
        )
    }

    private func refreshRenderedState() {
        displayedSeriesData = makeDisplayedSeriesData(
            from: allSeriesData,
            hiddenBands: currentHiddenBands,
            hideHiddenSSIDs: currentHideHiddenSSIDs
        )
    }

    private func selectedSeriesExists(_ selectedNetworkID: String?) -> Bool {
        guard let selectedNetworkID else { return true }
        return renderedAllSeriesData.contains { $0.id == selectedNetworkID }
    }

    func validateSelection(_ selectedNetworkID: String?) -> Bool {
        selectedSeriesExists(selectedNetworkID)
    }

    func renderedSnapshots(for selectedNetworkID: String?) -> [NetworkSnapshot]? {
        guard let selectedNetworkID,
              let series = renderedDisplayedSeriesData.first(where: { $0.id == selectedNetworkID })
        else { return nil }
        return renderedSnapshots[series.bssid]
    }

    func renderedSeries(for selectedNetworkID: String?) -> ChartSeriesData? {
        guard let selectedNetworkID else { return nil }
        return renderedDisplayedSeriesData.first(where: { $0.id == selectedNetworkID })
    }

    func setFreeze(_ frozen: Bool) {
        guard isFrozen != frozen else { return }
        isFrozen = frozen
        if frozen {
            frozenSnapshot = currentRenderSnapshot()
        } else {
            frozenSnapshot = nil
            refreshRenderedState()
        }
    }

    func toggleFreeze() {
        setFreeze(!isFrozen)
    }

    func syncFreezeState(from frozen: Bool) {
        setFreeze(frozen)
    }

    func visibleSeriesData() -> [ChartSeriesData] {
        renderedDisplayedSeriesData.filter { $0.isVisible && !$0.isFilteredOut }
    }

    func strongestRenderedRSSI() -> Int {
        Int(visibleSeriesData().map(\.displayRSSI).max() ?? 0)
    }

    // MARK: - RSSI animation

    var isViewVisible = true {
        didSet {
            if isViewVisible {
                if !allSeriesData.isEmpty { startAnimation() }
            } else {
                stopAnimation()
            }
        }
    }

    private func startAnimation() {
        guard animationTimer == nil, isViewVisible else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickAnimation()
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func tickAnimation() {
        var anyAnimating = false
        for i in allSeriesData.indices {
            let target = Double(allSeriesData[i].rssi)
            let delta = target - allSeriesData[i].displayRSSI
            if abs(delta) < 0.2 { continue }
            anyAnimating = true
            allSeriesData[i].displayRSSI += delta * 0.25
        }
        if !isFrozen {
            refreshRenderedState()
        }
        if !anyAnimating {
            stopAnimation()
        }
    }
}

extension BandChartViewModel {

    func updateNetworks(_ networks: [WiFiNetwork], colorHasher: SSIDColorHasher, filterQuery: String, trends: [String: (direction: TrendDirection, delta: Int)] = [:], snapshots: [String: [NetworkSnapshot]] = [:], hiddenBSSIDs: Set<String> = [], hiddenBands: Set<String> = [], hideHiddenSSIDs: Bool = false) {
        var dataArray = ChannelSpanCalculator.toSeriesData(networks, colorHasher: colorHasher, trends: trends, hiddenBSSIDs: hiddenBSSIDs)

        // Carry displayRSSI forward so animation continues from the current visual position
        let prevByID = Dictionary(uniqueKeysWithValues: allSeriesData.map { ($0.id, $0.displayRSSI) })
        for i in dataArray.indices {
            dataArray[i].displayRSSI = prevByID[dataArray[i].id] ?? Double(dataArray[i].rssi)
        }

        var occ: [Int: Int] = [:]
        for s in dataArray { occ[s.channel, default: 0] += 1 }
        channelOccupancy = occ
        for i in dataArray.indices {
            dataArray[i].qualityScore = Self.computeScore(
                rssi: dataArray[i].rssi,
                channelCount: occ[dataArray[i].channel] ?? 1,
                supportsK: dataArray[i].supportsK,
                supportsR: dataArray[i].supportsR,
                supportsV: dataArray[i].supportsV,
                channelWidth: dataArray[i].channelWidth
            )
        }
        allSeriesData = dataArray
        allSnapshots = snapshots
        currentHiddenBands = hiddenBands
        currentHideHiddenSSIDs = hideHiddenSSIDs
        currentFilterQuery = filterQuery
        if !isFrozen {
            refreshRenderedState()
        }
        startAnimation()
    }

    static func computeScore(rssi: Int, channelCount: Int, supportsK: Bool, supportsR: Bool, supportsV: Bool, channelWidth: String) -> Int {
        let rssiScore = max(0, min(100, Int(Double(rssi + 100) * 1.4)))
        let congScore: Int = switch channelCount {
        case 1: 100; case 2: 70; case 3: 50; case 4: 35; default: 20
        }
        let protoCount = [supportsK, supportsR, supportsV].filter { $0 }.count
        let protoScore = [0, 40, 70, 100][protoCount]
        let widthScore: Int = switch channelWidth {
        case "160": 100; case "80": 75; case "40": 50; default: 25
        }
        let total = Double(rssiScore) * 0.4 + Double(congScore) * 0.3 + Double(protoScore) * 0.2 + Double(widthScore) * 0.1
        return Int(total.rounded())
    }

    func updateInterfaceName(_ name: String) {
        interfaceName = name
    }

    func applyFilter(_ filterQuery: String? = nil,
                      hiddenBands: Set<String> = [],
                      hideHiddenSSIDs: Bool = false) {
        if let filterQuery {
            currentFilterQuery = filterQuery
        }
        currentHiddenBands = hiddenBands
        currentHideHiddenSSIDs = hideHiddenSSIDs
        if !isFrozen {
            refreshRenderedState()
        }
    }

    func toggleExpand() {
        isExpanded.toggle()
    }

    func clearFilter() {
        applyFilter("")
        showFilterPopover = false
    }

    func resetZoom() {
        zoomMin = nil
        zoomMax = nil
    }

    func applyZoom(lo: Double, hi: Double) {
        let clampedMin = Swift.max(Double(band == .band24GHz ? 1 : 1), lo)
        let clampedMax = Swift.min(Double(band.maxChannel), hi)
        let range = clampedMax - clampedMin
        guard range >= Double(Constants.minZoomRange) else { return }
        zoomMin = clampedMin
        zoomMax = clampedMax
    }
}

#if DEBUG
extension BandChartViewModel {
    /// Feed pre-built series data directly (bypasses WiFiNetwork → ChannelSpanCalculator pipeline).
    func debugInject(series: [ChartSeriesData]) {
        var dataArray = series
        let prevByID = Dictionary(uniqueKeysWithValues: allSeriesData.map { ($0.id, $0.displayRSSI) })
        var occ: [Int: Int] = [:]
        for i in dataArray.indices {
            dataArray[i].displayRSSI = prevByID[dataArray[i].id] ?? Double(dataArray[i].rssi)
            occ[dataArray[i].channel, default: 0] += 1
        }
        channelOccupancy = occ
        for i in dataArray.indices {
            dataArray[i].qualityScore = Self.computeScore(
                rssi: dataArray[i].rssi,
                channelCount: occ[dataArray[i].channel] ?? 1,
                supportsK: dataArray[i].supportsK,
                supportsR: dataArray[i].supportsR,
                supportsV: dataArray[i].supportsV,
                channelWidth: dataArray[i].channelWidth
            )
        }
        allSeriesData = dataArray
        if !isFrozen {
            refreshRenderedState()
        }
        startAnimation()
    }
}
#endif
