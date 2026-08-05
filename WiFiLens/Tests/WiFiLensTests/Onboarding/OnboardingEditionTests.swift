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
        #expect(config.proURL?.absoluteString == "https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=oss_invite&mt=8")
    }
}
