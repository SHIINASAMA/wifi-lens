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
}
