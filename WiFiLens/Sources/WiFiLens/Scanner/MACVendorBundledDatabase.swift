import Foundation

struct MACVendorBundledDatabaseSummary: Equatable, Sendable {
    let sourceUpdatedAt: String
    let sourceUpdatedDate: Date?
    let totalRecordCount: Int

    var legacyDatabaseSummary: MACVendorDatabaseSummary {
        MACVendorDatabaseSummary(
            source: .ieeeDownload,
            createdAt: sourceUpdatedDate ?? .distantPast,
            registryCounts: [:],
            totalRecordCount: totalRecordCount
        )
    }
}

struct MACVendorBundledDatabase: Decodable, Equatable, Sendable {
    struct Source: Decodable, Equatable, Sendable {
        let url: String
        let lastModifiedAt: String?
    }

    let schemaVersion: Int
    let retrievedAt: String
    let sourceUpdatedAt: String
    let sources: [Source]
    let entries: [MACVendorEntry]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case retrievedAt
        case sourceUpdatedAt
        case sources
        case entries
    }

    var totalRecordCount: Int { entries.count }

    var sourceUpdatedDate: Date? {
        ISO8601DateFormatter().date(from: sourceUpdatedAt)
    }

    var summary: MACVendorBundledDatabaseSummary {
        MACVendorBundledDatabaseSummary(
            sourceUpdatedAt: sourceUpdatedAt,
            sourceUpdatedDate: sourceUpdatedDate,
            totalRecordCount: totalRecordCount
        )
    }

    static func load(from bundle: Bundle = .main) -> MACVendorBundledDatabase? {
        guard let url = bundle.url(forResource: "mac-vendor-database", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            AppLogger.scanner.warning("Bundled MAC vendor database resource is unavailable")
            return nil
        }

        do {
            let database = try JSONDecoder().decode(Self.self, from: data)
            guard database.schemaVersion == 1 else {
                AppLogger.scanner.warning(
                    "Unsupported bundled MAC vendor database schema: \(database.schemaVersion)"
                )
                return nil
            }
            return database
        } catch {
            AppLogger.scanner.error("Failed to decode bundled MAC vendor database: \(error)")
            return nil
        }
    }
}
