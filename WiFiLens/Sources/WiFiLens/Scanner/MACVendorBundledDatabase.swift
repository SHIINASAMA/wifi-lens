import Foundation

struct MACVendorBundledDatabase: Decodable, Equatable, Sendable {
    let schemaVersion: Int
    let sourceUpdatedAt: String
    let sources: [String]
    let entries: [MACVendorEntry]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case sourceUpdatedAt = "retrievedAt"
        case sources
        case entries
    }

    var totalRecordCount: Int { entries.count }

    var sourceUpdatedDate: Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: sourceUpdatedAt)
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
