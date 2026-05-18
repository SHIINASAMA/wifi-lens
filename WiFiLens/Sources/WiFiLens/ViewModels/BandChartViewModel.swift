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
    var chartSize: CGSize = .zero

    var hasFilter: Bool { !currentFilterQuery.trimmingCharacters(in: .whitespaces).isEmpty }
    var isEmpty: Bool { allSeriesData.isEmpty }

    init(band: ChannelBand) {
        self.band = band
    }

    func updateNetworks(_ networks: [WiFiNetwork], colorHasher: SSIDColorHasher, filterQuery: String, trends: [String: (direction: TrendDirection, delta: Int)] = [:], snapshots: [String: [NetworkSnapshot]] = [:], hiddenBSSIDs: Set<String> = []) {
        let dataArray = ChannelSpanCalculator.toSeriesData(networks, colorHasher: colorHasher, trends: trends, hiddenBSSIDs: hiddenBSSIDs)
        allSeriesData = dataArray
        allSnapshots = snapshots
        currentFilterQuery = filterQuery
        if !isFrozen {
            applyFilter(filterQuery)
        }
    }

    func updateInterfaceName(_ name: String) {
        interfaceName = name
    }

    func applyFilter(_ filterQuery: String? = nil) {
        if let filterQuery {
            currentFilterQuery = filterQuery
        }
        let needle = currentFilterQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if needle.isEmpty {
            displayedSeriesData = allSeriesData.map { s in
                var s = s
                s.isFilteredOut = false
                return s
            }
        } else {
            displayedSeriesData = allSeriesData.map { s in
                var s = s
                s.isFilteredOut = !(s.ssid.lowercased().contains(needle)
                    || s.bssid.lowercased().contains(needle))
                return s
            }
        }
    }

    func toggleFreeze() {
        isFrozen.toggle()
        if !isFrozen {
            applyFilter()
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
