import SwiftUI

@MainActor
@Observable
final class BandChartViewModel {
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
    var chartSize: CGSize = .zero

    var hasFilter: Bool { !currentFilterQuery.trimmingCharacters(in: .whitespaces).isEmpty }
    var isEmpty: Bool { allSeriesData.isEmpty }

    init(band: ChannelBand) {
        self.band = band
    }

    func updateNetworks(_ networks: [WiFiNetwork], colorHasher: SSIDColorHasher, filterQuery: String, trends: [String: (direction: TrendDirection, delta: Int)] = [:], snapshots: [String: [NetworkSnapshot]] = [:], hiddenBSSIDs: Set<String> = [], hiddenBands: Set<String> = [], hideHiddenSSIDs: Bool = false) {
        var dataArray = ChannelSpanCalculator.toSeriesData(networks, colorHasher: colorHasher, trends: trends, hiddenBSSIDs: hiddenBSSIDs)

        // Compute per-channel occupancy and quality scores
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
            applyFilter(filterQuery, hiddenBands: hiddenBands, hideHiddenSSIDs: hideHiddenSSIDs)
        }
    }

    static func computeScore(rssi: Int, channelCount: Int, supportsK: Bool, supportsR: Bool, supportsV: Bool, channelWidth: String) -> Int {
        // RSSI: -30 → 98, -70 → 42, -90 → 14
        let rssiScore = max(0, min(100, Int(Double(rssi + 100) * 1.4)))
        // Congestion: fewer neighbors = better
        let congScore: Int = switch channelCount {
        case 1: 100; case 2: 70; case 3: 50; case 4: 35; default: 20
        }
        // Roaming protocols
        let protoCount = [supportsK, supportsR, supportsV].filter { $0 }.count
        let protoScore = [0, 40, 70, 100][protoCount]
        // Channel width
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
        let needle = currentFilterQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let bandHidden = hiddenBands.contains(band.id)
        displayedSeriesData = allSeriesData.map { s in
            var s = s
            let textFilter = needle.isEmpty
                || s.ssid.lowercased().contains(needle)
                || s.bssid.lowercased().contains(needle)
            let hiddenSSIDFilter = !hideHiddenSSIDs || !s.isHiddenSSID
            s.isFilteredOut = bandHidden || !textFilter || !hiddenSSIDFilter
            return s
        }
    }

    func toggleFreeze() {
        isFrozen.toggle()
        if !isFrozen {
            applyFilter(currentFilterQuery, hiddenBands: currentHiddenBands, hideHiddenSSIDs: currentHideHiddenSSIDs)
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
