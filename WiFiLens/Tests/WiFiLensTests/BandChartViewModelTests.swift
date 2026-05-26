import Foundation
import Testing
@testable import WiFiLens

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
        ChartSeriesData(
            id: id, ssid: ssid, bssid: bssid,
            channel: channel, left: channel - 2, apex: Double(channel),
            right: channel + 2, rssi: rssi,
            displayRSSI: Double(rssi), phyMode: phyMode,
            channelWidth: channelWidth, supportsK: supportsK,
            supportsR: supportsR, supportsV: supportsV,
            isHiddenSSID: isHiddenSSID
        )
    }

    // MARK: - Freeze / Unfreeze

    @Test func freezeCapturesCurrentState() {
        let vm = BandChartViewModel(band: .band24GHz)
        vm.debugInject(series: [makeSeries(ssid: "BeforeFreeze", rssi: -40)])

        #expect(!vm.isFrozen)
        #expect(vm.renderedAllSeriesData.first?.ssid == "BeforeFreeze")

        vm.setFreeze(true)

        #expect(vm.isFrozen)
        // Frozen snapshot should still show old data
        #expect(vm.renderedAllSeriesData.first?.ssid == "BeforeFreeze")

        // Inject new data while frozen
        vm.debugInject(series: [makeSeries(ssid: "AfterFreeze", rssi: -60)])
        // Still shows frozen data
        #expect(vm.renderedAllSeriesData.first?.ssid == "BeforeFreeze")
    }

    @Test func unfreezeRestoresLiveData() {
        let vm = BandChartViewModel(band: .band24GHz)
        vm.debugInject(series: [makeSeries(ssid: "Initial", rssi: -40)])

        vm.setFreeze(true)
        vm.debugInject(series: [makeSeries(ssid: "NewData", rssi: -60)])
        #expect(vm.renderedAllSeriesData.first?.ssid == "Initial")

        vm.setFreeze(false)
        #expect(!vm.isFrozen)
        #expect(vm.renderedAllSeriesData.first?.ssid == "NewData")
    }

    @Test func toggleFreezeFlipsState() {
        let vm = BandChartViewModel(band: .band24GHz)
        #expect(!vm.isFrozen)
        vm.toggleFreeze()
        #expect(vm.isFrozen)
        vm.toggleFreeze()
        #expect(!vm.isFrozen)
    }

    @Test func syncFreezeStateToTrueDoesNothingWhenAlreadyFrozen() {
        let vm = BandChartViewModel(band: .band24GHz)
        vm.debugInject(series: [makeSeries(ssid: "Initial")])
        vm.setFreeze(true)
        vm.debugInject(series: [makeSeries(ssid: "After")])
        // Sync to true again should keep frozen snapshot
        vm.syncFreezeState(from: true)
        #expect(vm.renderedAllSeriesData.first?.ssid == "Initial")
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
        #expect(!vm.showFilterPopover)
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
        // High RSSI + uncongested + all protocols + wide channel → high score
        #expect(score > 85)
    }

    @Test func computeScorePoorConditions() {
        let score = BandChartViewModel.computeScore(
            rssi: -90, channelCount: 10,
            supportsK: false, supportsR: false, supportsV: false,
            channelWidth: "20"
        )
        // Low RSSI + congested + no protocols + narrow channel → low score
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

    @Test func settingIsViewVisibleDoesNotCrashWhenNoData() {
        let vm = BandChartViewModel(band: .band24GHz)
        vm.isViewVisible = false
        #expect(!vm.isViewVisible)
        vm.isViewVisible = true
        #expect(vm.isViewVisible)
    }
}
