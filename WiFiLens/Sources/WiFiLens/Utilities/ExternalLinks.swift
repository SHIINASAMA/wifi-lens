import Foundation

enum ExternalDestination {
    case privacyPolicy
    case appStore
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
            "https://shiinasama.github.io/wifi-lens/#privacy"
        case .appStore:
            "https://apps.apple.com/app/wifi-lens-pro/id6776590746"
        case .website:
            "https://shiinasama.github.io/wifi-lens/"
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
