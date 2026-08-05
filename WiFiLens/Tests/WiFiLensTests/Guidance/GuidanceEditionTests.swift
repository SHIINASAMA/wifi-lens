import Testing
@testable import WiFi_Lens

struct GuidanceEditionTests {
    @Test func ossGuidanceConfigurationEnablesInvitationsOnly() {
        let config = EditionComposition.guidanceConfiguration

        #expect(config.invitationEnabled == true)
        #expect(config.reviewEnabled == false)
    }

    @Test func ossExportSuccessPresentationIsBanner() {
        #expect(EditionComposition.exportSuccessPresentation == .banner)
    }
}
