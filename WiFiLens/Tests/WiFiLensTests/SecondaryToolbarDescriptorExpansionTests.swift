import Testing
@testable import WiFi_Lens

struct SecondaryToolbarDescriptorExpansionTests {

    @Test func interfacesPageProvidesSecondaryToolbarDescriptor() {
        let descriptor = SecondaryToolbarDescriptor.forPage(.interfaces)
        #expect(descriptor != nil)
        #expect(descriptor?.items.map(\.id) == [.interfacesSimple, .interfacesDetails, .interfacesMonitor])
    }

#if PRO
    @Test func spectrumPageProvidesSecondaryToolbarDescriptor() {
        let descriptor = SecondaryToolbarDescriptor.forPage(.spectrum)
        #expect(descriptor != nil)
        #expect(descriptor?.items.map(\.id) == [.spectrumLive, .spectrumRecording])
    }
#endif
}
