import Foundation

actor MACVendorDatabaseStore {
    typealias CommitPendingFile = @Sendable (_ pendingURL: URL, _ databaseURL: URL) throws -> Void

    private struct SchemaEnvelope: Codable {
        let schemaVersion: Int
    }

    private let baseDirectory: URL
    private let fileManager: FileManager
    private let commitPendingFile: CommitPendingFile

    private var databaseURL: URL {
        baseDirectory.appending(path: "database-v1.json")
    }

    init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default,
        commitPendingFile: CommitPendingFile? = nil
    ) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory ?? fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "WiFi Lens/MACVendorDatabase", directoryHint: .isDirectory)
        self.commitPendingFile = commitPendingFile ?? { pendingURL, databaseURL in
            if FileManager.default.fileExists(atPath: databaseURL.path) {
                _ = try FileManager.default.replaceItemAt(databaseURL, withItemAt: pendingURL)
            } else {
                try FileManager.default.moveItem(at: pendingURL, to: databaseURL)
            }
        }
    }

    func load() throws -> MACVendorDatabase? {
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            return nil
        }

        let data: Data
        let schemaVersion: Int
        do {
            data = try Data(contentsOf: databaseURL)
            schemaVersion = try JSONDecoder()
                .decode(SchemaEnvelope.self, from: data)
                .schemaVersion
        } catch {
            throw MACVendorDatabaseError.persistenceFailure
        }

        guard schemaVersion == MACVendorDatabase.schemaVersion else {
            throw MACVendorDatabaseError.unsupportedSchema(schemaVersion)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(MACVendorDatabase.self, from: data)
        } catch {
            throw MACVendorDatabaseError.persistenceFailure
        }
    }

    func replace(with database: MACVendorDatabase) throws {
        let pendingURL = databaseURL.appendingPathExtension("pending")

        do {
            try fileManager.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: pendingURL.path) {
                try fileManager.removeItem(at: pendingURL)
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(database).write(to: pendingURL)

            let handle = try FileHandle(forWritingTo: pendingURL)
            do {
                try handle.synchronize()
                try handle.close()
            } catch {
                try? handle.close()
                throw error
            }

            try commitPendingFile(pendingURL, databaseURL)
        } catch {
            try? fileManager.removeItem(at: pendingURL)
            throw MACVendorDatabaseError.persistenceFailure
        }
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: databaseURL)
        } catch {
            throw MACVendorDatabaseError.persistenceFailure
        }
    }

    func readImportFiles(_ urls: [URL]) throws -> [MACVendorRegistryInput] {
        var inputs: [MACVendorRegistryInput] = []
        inputs.reserveCapacity(urls.count)

        for url in urls {
            try Task.checkCancellation()
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data: Data
            do {
                data = try Data(contentsOf: url, options: .mappedIfSafe)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw MACVendorDatabaseError.fileReadFailed(url.lastPathComponent)
            }

            try Task.checkCancellation()
            inputs.append(
                MACVendorRegistryInput(displayName: url.lastPathComponent, data: data)
            )
        }

        return inputs
    }
}
