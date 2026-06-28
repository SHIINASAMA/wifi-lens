import Testing
@testable import WiFi_Lens

struct SecondaryToolbarAttachmentTests {

    @Test func channelsPageProvidesSecondaryToolbarDescriptor() {
        #expect(SecondaryToolbarDescriptor.forPage(.channels) != nil)
    }

    @Test func overviewPageProvidesNoSecondaryToolbarDescriptor() {
        #expect(SecondaryToolbarDescriptor.forPage(.overview) == nil)
    }

    @Test func secondaryToolbarSelections_defaultValuesMatchPageDefaults() {
        let selections = SecondaryToolbarSelections()

        #expect(selections.selection(for: .channels) == .channelsSimple)
        #expect(selections.selection(for: .interfaces) == .interfacesSimple)
        #if PRO
        #expect(selections.selection(for: .spectrum) == .spectrumLive)
        #endif
        #expect(selections.selection(for: .overview) == nil)
    }

    @Test func secondaryToolbarSelections_updatesOnlyTargetPage() {
        var selections = SecondaryToolbarSelections()

        selections.setSelection(.channelsTable, for: .channels)

        #expect(selections.selection(for: .channels) == .channelsTable)
        #expect(selections.selection(for: .interfaces) == .interfacesSimple)
        #if PRO
        #expect(selections.selection(for: .spectrum) == .spectrumLive)
        #endif
    }

    #if PRO
    @Test func spectrumRecordingSessionResolver_preservesExistingViewModel() {
        let scannerViewModel = ScannerViewModel()
        let existing = RecordingViewModel(scannerViewModel: scannerViewModel)

        let resolved = SpectrumRecordingSessionResolver.resolve(
            current: existing,
            mode: .recording,
            scannerViewModel: scannerViewModel
        )

        #expect(resolved === existing)
    }

    @Test func spectrumRecordingSessionResolver_createsViewModelWhenMissing() {
        let scannerViewModel = ScannerViewModel()

        let resolved = SpectrumRecordingSessionResolver.resolve(
            current: nil,
            mode: .recording,
            scannerViewModel: scannerViewModel
        )

        #expect(resolved != nil)
        #expect(resolved?.scannerViewModel === scannerViewModel)
    }
    #endif
}

@Suite @MainActor
struct SpectrumLegacyCompatibilityTests {

    private func makeNetwork(
        ssid: String,
        bssid: String,
        band: ChannelBand,
        channel: Int,
        rssi: Int
    ) -> WiFiNetwork {
        WiFiNetwork(
            ssid: ssid,
            bssid: bssid,
            rssi: rssi,
            channel: WiFiChannel(band: band, channelNumber: channel, channelWidthMHz: 20)
        )
    }

    @Test func panelFiltersRemainIndependent() {
        let viewModel = ScannerViewModel()
        viewModel.debugApplyNetworksForTesting([
            makeNetwork(ssid: "Alpha", bssid: "aa:aa:aa:aa:aa:aa", band: .band24GHz, channel: 1, rssi: -45),
            makeNetwork(ssid: "Beta", bssid: "bb:bb:bb:bb:bb:bb", band: .band24GHz, channel: 6, rssi: -52)
        ], supportedBands: [.band24GHz])

        viewModel.setFilterQuery("Alpha", for: .primary)

        let primaryVisible = viewModel
            .bandViewModel(for: .primary, selection: .band24)
            .visibleSeriesData()
            .map(\.displaySSID)
        let secondaryVisible = viewModel
            .bandViewModel(for: .secondary, selection: .band24)
            .visibleSeriesData()
            .map(\.displaySSID)

        #expect(primaryVisible == ["Alpha"])
        #expect(Set(secondaryVisible) == ["Alpha", "Beta"])
    }

    @Test func visibilityLockSurvivesRefresh() {
        let viewModel = ScannerViewModel()
        let network = makeNetwork(
            ssid: "Alpha",
            bssid: "aa:aa:aa:aa:aa:aa",
            band: .band5GHz,
            channel: 44,
            rssi: -48
        )

        viewModel.debugApplyNetworksForTesting([network], supportedBands: [.band5GHz])
        viewModel.toggleVisibilityLocked(seriesID: network.id)
        viewModel.toggleVisibility(seriesID: network.id)
        viewModel.debugApplyNetworksForTesting([network], supportedBands: [.band5GHz])

        let row = try? #require(viewModel.combinedTableRows.first)
        #expect(row?.isVisible == false)
        #expect(row?.visibilityLocked == true)
    }
}
