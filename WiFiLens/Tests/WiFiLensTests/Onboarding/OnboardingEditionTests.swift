import Foundation
import Testing
@testable import WiFi_Lens

@MainActor
final class OnboardingEditionTests {
    @Test func ossEnablesWelcomeWithProLink() {
        let config = EditionComposition.onboardingConfiguration

        #expect(config.welcomeEnabled == true)
        #expect(config.showsProLink == true)
        #expect(config.startRoute == .overview)
        #expect(config.startToolbarSelection == nil)
        #expect(config.primaryActionKey == "onboarding.welcome.start")
        #expect(config.highlights.map(\.titleKey) == [
            "onboarding.welcome.highlight.live",
            "onboarding.welcome.highlight.diagnostics",
            "onboarding.welcome.highlight.export"
        ])
        #expect(config.proURL?.absoluteString == "https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=oss_invite&mt=8")
    }
}
