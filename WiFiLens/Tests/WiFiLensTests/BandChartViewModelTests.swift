import Foundation
import SwiftUI
import Testing
import ChartLens
@testable import WiFi_Lens

@Suite @MainActor struct BandChartViewModelTests {

    private func makeSeries(
        id: String = "test-1",
        ssid: String = "TestNet",
        bssid: String = "aa:bb:cc:dd:ee:ff",
        channel: Int = 6,
        rssi: Int = -50,
        phyMode: String = "ax",
        channelWidth: String = "80",
        supportsK: Bool = true,
        supportsR: Bool = true,
        supportsV: Bool = true,
        isHiddenSSID: Bool = false
    ) -> ChartSeriesData {
        let domain = ChartSeriesDomainData(
            id: id,
            ssid: ssid,
            bssid: bssid,
            channel: channel,
            left: channel - 2,
            apex: Double(channel),
            right: channel + 2,
            rssi: rssi,
            phyMode: phyMode,
            channelWidth: channelWidth,
            supportsK: supportsK,
            supportsR: supportsR,
            supportsV: supportsV,
            supportsWPA3: false,
            isHiddenSSID: isHiddenSSID,
            security: "",
            mcs: "",
            nss: "",
            country: ""
        )
        return ChartSeriesData(domain: domain, render: ChartSeriesRenderState(displayRSSI: Double(rssi)))
    }

    // MARK: - Filter

    @Test func filterByQueryHidesNonMatchingNetworks() {
        let vm = BandChartViewModel(band: .band24GHz)
        vm.debugInject(series: [
            makeSeries(id: "1", ssid: "Alpha"),
            makeSeries(id: "2", ssid: "Beta"),
            makeSeries(id: "3", ssid: "Gamma"),
        ])

        vm.applyFilter("Beta")
        let visible = vm.visibleSeriesData()
        #expect(visible.count == 1)
        #expect(visible.first?.ssid == "Beta")
    }

    @Test func filterByHiddenBandsRemovesBand() {
        let vm = BandChartViewModel(band: .band24GHz)
        vm.debugInject(series: [
            makeSeries(id: "1", ssid: "Net1"),
            makeSeries(id: "2", ssid: "Net2"),
        ])

        vm.applyFilter(hiddenBands: ["24"])
        let visible = vm.visibleSeriesData()
        #expect(visible.isEmpty)
    }

    @Test func filterByHiddenSSIDsExcludesEmptySSID() {
        let vm = BandChartViewModel(band: .band24GHz)
        vm.debugInject(series: [
            makeSeries(id: "1", ssid: "Visible"),
            makeSeries(id: "2", ssid: "", isHiddenSSID: true),
        ])

        vm.applyFilter(hideHiddenSSIDs: true)
        let visible = vm.visibleSeriesData()
        #expect(visible.count == 1)
        #expect(visible.first?.ssid == "Visible")
    }

    @Test func debugInjectPreservesInjectedFilteredState() {
        let vm = BandChartViewModel(band: .band24GHz)
        var visibleSeries = makeSeries(id: "1", ssid: "Visible")
        visibleSeries.isFilteredOut = false
        var filteredSeries = makeSeries(id: "2", ssid: "Filtered")
        filteredSeries.isFilteredOut = true

        vm.debugInject(series: [visibleSeries, filteredSeries])

        #expect(vm.displayedSeriesData.count == 2)
        #expect(vm.displayedSeriesData.first { $0.id == "2" }?.isFilteredOut == true)
        #expect(vm.visibleSeriesData().map(\.id) == ["1"])
    }

    @Test func clearFilterRestoresAllVisible() {
        let vm = BandChartViewModel(band: .band24GHz)
        vm.debugInject(series: [
            makeSeries(id: "1", ssid: "Alpha"),
            makeSeries(id: "2", ssid: "Beta"),
        ])

        vm.applyFilter("Alpha")
        #expect(vm.visibleSeriesData().count == 1)

        vm.clearFilter()
        #expect(vm.visibleSeriesData().count == 2)
    }

    @Test func hasFilterReflectsFilterState() {
        let vm = BandChartViewModel(band: .band24GHz)
        #expect(!vm.hasFilter)
        vm.applyFilter("test")
        #expect(vm.hasFilter)
        vm.clearFilter()
        #expect(!vm.hasFilter)
    }

    // MARK: - Validation

    @Test func validateSelectionReturnsTrueForExistingSeries() {
        let vm = BandChartViewModel(band: .band24GHz)
        vm.debugInject(series: [
            makeSeries(id: "valid-id", ssid: "Net"),
        ])
        #expect(vm.validateSelection("valid-id"))
        #expect(!vm.validateSelection("missing-id"))
    }

    // MARK: - computeScore

    @Test func computeScoreExcellentConditions() {
        let score = BandChartViewModel.computeScore(
            rssi: -30, channelCount: 1,
            supportsK: true, supportsR: true, supportsV: true,
            channelWidth: "160"
        )
        #expect(score > 85)
    }

    @Test func computeScorePoorConditions() {
        let score = BandChartViewModel.computeScore(
            rssi: -90, channelCount: 10,
            supportsK: false, supportsR: false, supportsV: false,
            channelWidth: "20"
        )
        #expect(score < 40)
    }

    @Test func computeScoreChannelCountAffectsScore() {
        let single = BandChartViewModel.computeScore(
            rssi: -50, channelCount: 1,
            supportsK: true, supportsR: true, supportsV: false,
            channelWidth: "80"
        )
        let crowded = BandChartViewModel.computeScore(
            rssi: -50, channelCount: 10,
            supportsK: true, supportsR: true, supportsV: false,
            channelWidth: "80"
        )
        #expect(single > crowded)
    }

    // MARK: - isViewVisible

    @Test func isViewVisibleDefaultTrue() {
        let vm = BandChartViewModel(band: .band24GHz)
        #expect(vm.isViewVisible)
    }

    // MARK: - BandChartLayout

    @Test func axisTickValuesSkipChannelsBelowStart() {
        let ticks = BandChartLayout.axisTickValues(xMin: -1, xMax: 14, maxChannel: 14, axisTickStartChannel: 1)
        #expect(!ticks.isEmpty)
        #expect(ticks.allSatisfy { $0 >= 1 })
        #expect(ticks.first == 1)
    }

    @Test func heatmapBinsGroupByApex() {
        let series = [
            makeSeries(id: "1", ssid: "A", channel: 6),
            makeSeries(id: "2", ssid: "B", channel: 6),
            makeSeries(id: "3", ssid: "C", channel: 11),
        ]
        let heatmap = BandChartLayout.heatmapBins(series: series)
        #expect(heatmap.bins.count == 2)
        #expect(heatmap.maxCount == 2)
        #expect(heatmap.bins.first?.colors.count == 2)
        #expect(heatmap.bins.last?.colors.count == 1)
    }

    @Test func placeLabelsKeepsSelectedSeries() {
        let selected = makeSeries(id: "selected", ssid: "Selected", channel: 6, rssi: -40)
        let other = makeSeries(id: "other", ssid: "Other", channel: 6, rssi: -45)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let labels = BandChartLayout.placeLabels(
            seriesData: [other, selected],
            plotRect: rect,
            annotationRect: rect,
            xMin: 1,
            scaleX: 10,
            scaleY: 1,
            yMin: Double(Constants.rssiNoiseFloor),
            selectedNetworkID: "selected"
        )
        #expect(labels.contains { $0.series.id == "selected" })
    }

    @Test func placeLabelsKeepLeftAndTopEdgeInsideAnnotationRect() throws {
        let series = makeSeries(
            id: "left-edge",
            ssid: "DIRECT-XX-HP Laser XXXXnw",
            channel: 1,
            rssi: -40
        )
        let plotRect = CGRect(x: 38, y: 6, width: 320, height: 160)
        let annotationRect = CGRect(x: 58, y: 26, width: 280, height: 120)

        let labels = BandChartLayout.placeLabels(
            seriesData: [series],
            plotRect: plotRect,
            annotationRect: annotationRect,
            xMin: 1,
            scaleX: 24,
            scaleY: 160 / 60,
            yMin: Double(Constants.rssiNoiseFloor),
            selectedNetworkID: nil
        )

        let label = try #require(labels.first)
        let rect = BandChartLayout.estimatedLabelRect(for: label)
        #expect(annotationRect.contains(rect))
    }

    @Test func placeLabelsUseDownwardLaneNearTopBoundary() throws {
        let first = makeSeries(id: "first", ssid: "Collision-A", channel: 52, rssi: -40)
        let second = makeSeries(id: "second", ssid: "Collision-B", channel: 52, rssi: -41)
        let plotRect = CGRect(x: 38, y: 6, width: 360, height: 180)
        let annotationRect = CGRect(x: 58, y: 26, width: 320, height: 140)

        let labels = BandChartLayout.placeLabels(
            seriesData: [first, second],
            plotRect: plotRect,
            annotationRect: annotationRect,
            xMin: 36,
            scaleX: 8,
            scaleY: 180 / 60,
            yMin: Double(Constants.rssiNoiseFloor),
            selectedNetworkID: nil
        )

        #expect(labels.count == 2)
        let rects = labels.map { BandChartLayout.estimatedLabelRect(for: $0) }
        #expect(rects.allSatisfy { annotationRect.contains($0) })
        #expect(!rects[0].intersects(rects[1]))
    }

    @Test func acceptedLabelRectIsCenteredOnPlacementPosition() throws {
        let series = makeSeries(id: "centered", ssid: "Centered", channel: 11, rssi: -90)
        let plotRect = CGRect(x: 38, y: 6, width: 320, height: 160)
        let annotationRect = CGRect(x: 58, y: 26, width: 280, height: 120)

        let labels = BandChartLayout.placeLabels(
            seriesData: [series],
            plotRect: plotRect,
            annotationRect: annotationRect,
            xMin: 1,
            scaleX: 24,
            scaleY: 160 / 60,
            yMin: Double(Constants.rssiNoiseFloor),
            selectedNetworkID: nil
        )

        let label = try #require(labels.first)
        let rect = BandChartLayout.estimatedLabelRect(for: label)
        #expect(rect.midX == label.x)
        #expect(rect.midY == label.y)
        #expect(annotationRect.contains(rect))
    }

    @Test func regularLabelSitsAboveCurveApex() throws {
        let series = makeSeries(id: "above", ssid: "Above", channel: 6, rssi: -60)
        let plotRect = CGRect(x: 38, y: 6, width: 320, height: 160)
        let annotationRect = CGRect(x: 58, y: 26, width: 280, height: 120)
        let scaleY = plotRect.height / 60
        let yMin = Double(Constants.rssiNoiseFloor)

        let labels = BandChartLayout.placeLabels(
            seriesData: [series],
            plotRect: plotRect,
            annotationRect: annotationRect,
            xMin: 1,
            scaleX: 24,
            scaleY: scaleY,
            yMin: yMin,
            selectedNetworkID: nil
        )

        let label = try #require(labels.first)
        let rect = BandChartLayout.estimatedLabelRect(for: label)
        let apexY = plotRect.maxY - (series.displayRSSI - yMin) * scaleY

        #expect(rect.maxY <= apexY - 8)
    }

    @Test func longSSIDPlacementUsesCappedContainedLabelSize() throws {
        let series = makeSeries(
            id: "long",
            ssid: "This network name is intentionally far longer than the label estimate may draw without truncation",
            channel: 6,
            rssi: -40
        )
        let plotRect = CGRect(x: 38, y: 6, width: 320, height: 160)
        let annotationRect = CGRect(x: 58, y: 26, width: 280, height: 120)

        let labels = BandChartLayout.placeLabels(
            seriesData: [series],
            plotRect: plotRect,
            annotationRect: annotationRect,
            xMin: 1,
            scaleX: 24,
            scaleY: 160 / 60,
            yMin: Double(Constants.rssiNoiseFloor),
            selectedNetworkID: nil
        )

        let label = try #require(labels.first)
        let rect = BandChartLayout.estimatedLabelRect(for: label)
        #expect(label.size.width == 220)
        #expect(rect.width == label.size.width)
        #expect(annotationRect.contains(rect))
    }

    @Test func selectedLabelFallsBackInsideTooSmallAnnotationRect() throws {
        let selected = makeSeries(id: "selected", ssid: "SelectedNameCannotFit", channel: 6, rssi: -40)
        let plotRect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let annotationRect = CGRect(x: 20, y: 20, width: 5, height: 5)

        let labels = BandChartLayout.placeLabels(
            seriesData: [selected],
            plotRect: plotRect,
            annotationRect: annotationRect,
            xMin: 1,
            scaleX: 10,
            scaleY: 1,
            yMin: Double(Constants.rssiNoiseFloor),
            selectedNetworkID: "selected"
        )

        let label = try #require(labels.first)
        let rect = BandChartLayout.estimatedLabelRect(for: label)
        #expect(label.series.id == "selected")
        #expect(label.kind == .marker)
        #expect(annotationRect.contains(rect))
    }

    @Test func nearestSeriesFindsClosestCurve() {
        let series = makeSeries(id: "hit", ssid: "Hit", channel: 6, rssi: -40)
        let geo = ChartGeometry(
            chartRect: CGRect(x: 0, y: 0, width: 200, height: 120),
            xMin: 1,
            xMax: 14,
            yMin: Double(Constants.rssiNoiseFloor),
            yMax: 0
        )
        let point = geo.dataToPoint(x: Double(series.apex), y: Double(series.displayRSSI))
        let hit = BandChartLayout.nearestSeries(at: point, in: [series], geometry: geo, radius: 20)
        #expect(hit?.0.id == "hit")
    }

    // MARK: - SnapshotToChartAdapter

    @Test func channelWidthMHzParsesCorrectly() {
        #expect(SnapshotToChartAdapter.channelWidthMHz(from: "160") == 160)
        #expect(SnapshotToChartAdapter.channelWidthMHz(from: "80") == 80)
        #expect(SnapshotToChartAdapter.channelWidthMHz(from: "40") == 40)
        #expect(SnapshotToChartAdapter.channelWidthMHz(from: "20") == 20)
        #expect(SnapshotToChartAdapter.channelWidthMHz(from: "") == 20)
        #expect(SnapshotToChartAdapter.channelWidthMHz(from: "invalid") == 20)
    }

    @Test func toSeriesDataFiltersByBand() {
        let snap24 = NetworkSnapshot(
            timestamp: Date(), bssid: "aa:bb:cc:dd:ee:01", ssid: "Net2G",
            rssi: -50, channel: 6, band: "24", phyMode: "ax",
            channelWidth: "40", mcs: "", nss: "", security: "",
            country: "", supportsK: true, supportsR: true,
            supportsV: true, supportsWPA3: false, isHiddenSSID: false
        )
        let snap5 = NetworkSnapshot(
            timestamp: Date(), bssid: "aa:bb:cc:dd:ee:02", ssid: "Net5G",
            rssi: -45, channel: 52, band: "5", phyMode: "ac",
            channelWidth: "80", mcs: "", nss: "", security: "",
            country: "", supportsK: false, supportsR: false,
            supportsV: false, supportsWPA3: true, isHiddenSSID: false
        )
        let dict = ["bssid1": snap24, "bssid2": snap5]
        let hasher = SSIDColorHasher()

        let series2G = SnapshotToChartAdapter.toSeriesData(snapshotsByBSSID: dict, band: .band24GHz, colorHasher: hasher)
        #expect(series2G.count == 1)
        #expect(series2G.first?.ssid == "Net2G")

        let series5G = SnapshotToChartAdapter.toSeriesData(snapshotsByBSSID: dict, band: .band5GHz, colorHasher: hasher)
        #expect(series5G.count == 1)
        #expect(series5G.first?.ssid == "Net5G")
    }

    @Test func toSeriesDataEmptyInputProducesEmptyOutput() {
        let series = SnapshotToChartAdapter.toSeriesData(
            snapshotsByBSSID: [:],
            band: .band5GHz,
            colorHasher: SSIDColorHasher()
        )
        #expect(series.isEmpty)
    }

    @Test func toSeriesDataSkipsInvalidBand() {
        let snap = NetworkSnapshot(
            timestamp: Date(), bssid: "aa:bb:cc:dd:ee:03", ssid: "BadBand",
            rssi: -50, channel: 6, band: "99", phyMode: "ax",
            channelWidth: "20", mcs: "", nss: "", security: "",
            country: "", supportsK: false, supportsR: false,
            supportsV: false, supportsWPA3: false, isHiddenSSID: false
        )
        let series = SnapshotToChartAdapter.toSeriesData(
            snapshotsByBSSID: ["bssid": snap],
            band: .band5GHz,
            colorHasher: SSIDColorHasher()
        )
        #expect(series.isEmpty)
    }
}
