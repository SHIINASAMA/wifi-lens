import Testing
@testable import WiFi_Lens

struct SecondaryToolbarAttachmentTests {

    @Test func channelsPageProvidesSecondaryToolbarDescriptor() {
        #expect(SecondaryToolbarDescriptor.forPage(.channels) != nil)
    }

@Test func overviewPageProvidesNoSecondaryToolbarDescriptor() {
    #expect(SecondaryToolbarDescriptor.forPage(.overview) == nil)
}

@Test func detailPageRenderPolicy_onlyRendersSelectedPage() {
    #expect(DetailPageRenderPolicy.shouldRender(.interfaces, selectedPage: .interfaces))
    #expect(!DetailPageRenderPolicy.shouldRender(.spectrum, selectedPage: .interfaces))
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
