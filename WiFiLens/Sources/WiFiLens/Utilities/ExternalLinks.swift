import Foundation

enum ExternalDestination {
    case privacyPolicy
    case appStore
    case appStoreWriteReview
    case appStoreCampaign
    case website
    case github
    case xAccount
    case developerProfile
    case chartLensRepository
    case mcpSwiftSDKRepository
    case sparkleRepository
}

enum ExternalLinks {
    static func url(for destination: ExternalDestination) -> URL? {
        let value = switch destination {
        case .privacyPolicy:
            "https://wifi-lens.shiinalabs.com/privacy"
        case .appStore:
            "https://apps.apple.com/app/wifi-lens-pro/id6776590746"
        case .appStoreWriteReview:
            "https://apps.apple.com/app/wifi-lens-pro/id6776590746?action=write-review"
        case .appStoreCampaign:
            // Official App Store Connect "oss_invite" Campaign Link. Regenerate
            // from App Analytics -> Campaigns if the campaign changes; never
            // handcraft the pt/ct parameters.
            "https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=oss_invite&mt=8"
        case .website:
            "https://wifi-lens.shiinalabs.com"
        case .github:
            "https://github.com/SHIINASAMA/wifi-lens"
        case .xAccount:
            "https://x.com/WiFiLens"
        case .developerProfile:
            "https://x.com/KAORU11843779"
        case .chartLensRepository:
            "https://github.com/SHIINASAMA/chart-lens"
        case .mcpSwiftSDKRepository:
            "https://github.com/nicklama/mcp-swift-sdk"
        case .sparkleRepository:
            "https://github.com/sparkle-project/Sparkle"
        }

        return URL(string: value)
    }
}
