import Testing
@testable import WiFi_Lens

struct EditionCompositionTests {

    @Test("shared Timeline route remains available to OSS")
    func sharedTimelineRouteRemainsAvailable() {
        #expect(SidebarPage.allCases.contains(.timeline))
    }

    @Test("OSS timeline contribution remains a locked preview")
    func ossTimelineContributionIsLockedPreview() {
        #expect(EditionComposition.timelineToolbarDescriptor == nil)
        #expect(EditionComposition.isTimelineLockedPreview)
    }

    @Test("OSS recording segment remains locked")
    func ossRecordingSegmentRemainsLocked() {
        let descriptor = EditionComposition.spectrumToolbarDescriptor
        #expect(descriptor.items.first { $0.id == .spectrumRecording }?.isLocked == true)
    }
}
