import Foundation
import Testing
@testable import WiFi_Lens

struct ExternalLinksTests {
    @Test("privacy policy maps to the website privacy anchor")
    func privacyPolicyURL() {
        #expect(ExternalLinks.url(for: .privacyPolicy)?.absoluteString == "https://wifi-lens.shiinalabs.com/privacy")
    }

    @Test("app store maps to the Pro product page")
    func appStoreURL() {
        #expect(ExternalLinks.url(for: .appStore)?.absoluteString == "https://apps.apple.com/app/wifi-lens-pro/id6776590746")
    }

    @Test("dependency repositories keep their current public locations")
    func dependencyRepositoryURLs() {
        #expect(ExternalLinks.url(for: .chartLensRepository)?.absoluteString == "https://github.com/SHIINASAMA/chart-lens")
        #expect(ExternalLinks.url(for: .mcpSwiftSDKRepository)?.absoluteString == "https://github.com/nicklama/mcp-swift-sdk")
        #expect(ExternalLinks.url(for: .sparkleRepository)?.absoluteString == "https://github.com/sparkle-project/Sparkle")
    }
}
