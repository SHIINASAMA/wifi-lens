import Foundation

// MARK: - Regulatory Domain

enum RegulatoryDomain: String, CaseIterable, Codable, Sendable {
    case US
    case JP
    case CN
    case EU
    case unknown

    var displayName: String {
        switch self {
        case .US: "United States (FCC)"
        case .JP: "Japan (MIC)"
        case .CN: "China (SRRC)"
        case .EU: "European Union (ETSI)"
        case .unknown: String(localized: "Unknown")
        }
    }

    /// Map a locale region identifier (ISO 3166-1 alpha-2) onto a regulatory domain.
    static func from(localeRegionCode: String?) -> Self {
        guard let code = localeRegionCode?.uppercased() else { return .unknown }
        switch code {
        case "US", "CA", "MX": return .US
        case "JP": return .JP
        case "CN": return .CN
        case "GB", "DE", "FR", "IT", "ES", "NL", "BE", "SE", "DK", "FI",
             "PT", "IE", "AT", "PL", "CZ", "SK", "HU", "RO", "BG", "HR",
             "SI", "LT", "LV", "EE", "LU", "MT", "CY", "GR", "NO", "CH",
             "IS", "LI": return .EU
        default: return .unknown
        }
    }
}

// MARK: - Inference Confidence

enum InferenceConfidence: Comparable, Sendable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high: String(localized: "High confidence")
        case .medium: String(localized: "Medium confidence")
        case .low: String(localized: "Low confidence")
        }
    }
}

// MARK: - Region Source

struct RegionSource: Sendable {
    enum Kind: String, Sendable {
        case systemLocale
        case supportedChannels
        case apBeaconCountry
        case userOverride
    }

    let kind: Kind
    let rawValue: String
    let inferredDomain: RegulatoryDomain?

    var description: String {
        let domainStr = inferredDomain?.rawValue ?? "unknown"
        return "[\(kind.rawValue)] raw=\(rawValue) → \(domainStr)"
    }
}

// MARK: - Region Conflict

struct RegionConflict: Sendable {
    let sourceA: RegionSource
    let sourceB: RegionSource
    let resolution: String
}

// MARK: - Inference Result

struct RegionInferenceResult: Sendable {
    let domain: RegulatoryDomain
    let confidence: InferenceConfidence
    let contributions: [RegionSource]
    let conflicts: [RegionConflict]

    var summary: String {
        var lines = ["Region: \(domain.rawValue) (\(confidence.label))"]
        for c in contributions {
            lines.append("  ← \(c.description)")
        }
        for conflict in conflicts {
            lines.append("  ⚠ \(conflict.resolution)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Device PHY Capabilities

struct DevicePHYCapabilities: Sendable {
    let supportsAX: Bool
    let supportsAC: Bool
    let supportsN: Bool
    let supportsBE: Bool
    let supports6GHz: Bool
    let supportsDFS: Bool
    let supports160MHz: Bool

    static let `default` = DevicePHYCapabilities(
        supportsAX: false,
        supportsAC: true,
        supportsN: true,
        supportsBE: false,
        supports6GHz: false,
        supportsDFS: true,
        supports160MHz: false
    )

    var phySummary: String {
        var parts: [String] = []
        if supportsBE { parts.append("be") }
        if supportsAX { parts.append("ax") }
        if supportsAC { parts.append("ac") }
        if supportsN { parts.append("n") }
        return parts.isEmpty ? "unknown" : parts.joined(separator: "/")
    }
}
