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

    @Test("app store write-review maps to the manual rating destination")
    func appStoreWriteReviewURL() {
        #expect(
            ExternalLinks.url(for: .appStoreWriteReview)?.absoluteString
                == "https://apps.apple.com/app/wifi-lens-pro/id6776590746?action=write-review"
        )
    }

    @Test("app store campaign URLs use distinct ct values per entry surface")
    func appStoreCampaignURL() {
        #expect(
            ExternalLinks.url(for: .appStoreCampaignWelcome)?.absoluteString
                == "https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=oss_welcome&mt=8"
        )
        #expect(
            ExternalLinks.url(for: .appStoreCampaignDiagnosis)?.absoluteString
                == "https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=oss_diagnosis&mt=8"
        )
        #expect(
            ExternalLinks.url(for: .appStoreCampaignExport)?.absoluteString
                == "https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=oss_export&mt=8"
        )
        #expect(
            ExternalLinks.url(for: .appStoreCampaignPreviewLock)?.absoluteString
                == "https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=oss_preview_lock&mt=8"
        )
    }

    @Test("dependency repositories keep their current public locations")
    func dependencyRepositoryURLs() {
        #expect(ExternalLinks.url(for: .chartLensRepository)?.absoluteString == "https://github.com/SHIINASAMA/chart-lens")
        #expect(ExternalLinks.url(for: .mcpSwiftSDKRepository)?.absoluteString == "https://github.com/modelcontextprotocol/swift-sdk")
        #expect(ExternalLinks.url(for: .sparkleRepository)?.absoluteString == "https://github.com/sparkle-project/Sparkle")
    }
}
