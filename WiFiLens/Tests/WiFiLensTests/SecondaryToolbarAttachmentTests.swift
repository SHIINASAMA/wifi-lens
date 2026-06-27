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

    @Test func spectrumDashboardLayout_usesPureRatiosWhenViewportIsComfortable() {
        let layout = SpectrumDashboardLayout(viewportHeight: 1000)

        #expect(layout.primaryHeight == 350)
        #expect(layout.secondaryHeight == 350)
        #expect(layout.tableHeight == 300)
    }

    @Test func spectrumDashboardLayout_usesSameRatiosForSmallerViewports() {
        let layout = SpectrumDashboardLayout(viewportHeight: 640)

        #expect(layout.primaryHeight == 224)
        #expect(layout.secondaryHeight == 224)
        #expect(layout.tableHeight == 192)
        #expect(layout.primaryHeight + layout.secondaryHeight + layout.tableHeight == 640)
    }
}
