import Foundation

enum MACVendorRegistry: String, CaseIterable, Codable, Hashable, Sendable {
    case maL = "MA-L"
    case maM = "MA-M"
    case maS = "MA-S"
    case iab = "IAB"

    var prefixLength: Int {
        switch self {
        case .maL: 24
        case .maM: 28
        case .maS, .iab: 36
        }
    }

    var downloadURL: URL {
        switch self {
        case .maL: URL(string: "https://standards-oui.ieee.org/oui/oui.csv")!
        case .maM: URL(string: "https://standards-oui.ieee.org/oui28/mam.csv")!
        case .maS: URL(string: "https://standards-oui.ieee.org/oui36/oui36.csv")!
        case .iab: URL(string: "https://standards-oui.ieee.org/iab/iab.csv")!
        }
    }
}

enum MACVendorDatabaseSource: String, Codable, Equatable, Sendable {
    case ieeeDownload
    case manualImport
}

struct MACVendorRegistryInput: Sendable {
    let displayName: String
    let data: Data
}

struct MACVendorRegistryMetadata: Codable, Equatable, Sendable {
    let registry: MACVendorRegistry
    let validRecordCount: Int
    let sha256: String
    let sourceURL: URL?
}

struct MACVendorEntry: Codable, Equatable, Sendable {
    let prefix: String
    let prefixLength: Int
    let organization: String
}

struct MACVendorDatabase: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    let schemaVersion: Int
    let createdAt: Date
    let source: MACVendorDatabaseSource
    let registries: [MACVendorRegistryMetadata]
    let entries: [MACVendorEntry]

    var summary: MACVendorDatabaseSummary {
        MACVendorDatabaseSummary(
            source: source,
            createdAt: createdAt,
            registryCounts: Dictionary(uniqueKeysWithValues: registries.map { ($0.registry, $0.validRecordCount) }),
            totalRecordCount: entries.count
        )
    }
}

struct MACVendorDatabaseSummary: Equatable, Sendable {
    let source: MACVendorDatabaseSource
    let createdAt: Date
    let registryCounts: [MACVendorRegistry: Int]
    let totalRecordCount: Int
}

enum MACVendorDatabaseError: Error, Equatable, Sendable {
    case wrongFileCount(expected: Int, actual: Int)
    case fileTooLarge(file: String, maximumBytes: Int)
    case totalSizeExceeded(maximumBytes: Int)
    case invalidEncoding(file: String)
    case malformedCSV(file: String)
    case missingColumns(file: String, columns: [String])
    case mixedRegistries(file: String)
    case duplicateRegistry(MACVendorRegistry)
    case missingRegistry(MACVendorRegistry)
    case invalidAssignment(file: String, registry: MACVendorRegistry, assignment: String)
    case invalidOrganization(file: String)
    case tooFewRecords(registry: MACVendorRegistry, minimum: Int, actual: Int)
    case conflictingAssignment(prefix: String, prefixLength: Int)
    case invalidHTTPStatus(registry: MACVendorRegistry, statusCode: Int)
    case disallowedRedirect(URL)
    case downloadFailed(MACVendorRegistry)
    case automaticDownloadFailed
    case fileReadFailed(String)
    case unsupportedSchema(Int)
    case persistenceFailure
    case noPreparedImport
}
