import Foundation
import Observation

enum MACVendorDatabaseAvailability: Equatable, Sendable {
    case loading
    case notInstalled
    case installed(MACVendorDatabaseSummary)
    case unavailable(MACVendorDatabaseError)
}

enum MACVendorDatabaseOperation: Equatable, Sendable {
    case idle
    case downloading(completed: Int, total: Int)
    case readingFiles
    case validating
    case installing
    case clearing
}

@MainActor
@Observable
final class MACVendorDatabaseManager {
    struct CancellationHandle: Sendable {
        fileprivate let operationID: UUID
        fileprivate let task: Task<Void, Never>
    }

    private(set) var availability: MACVendorDatabaseAvailability = .loading
    private(set) var operation: MACVendorDatabaseOperation = .idle
    private(set) var pendingManualImport: MACVendorDatabaseSummary?
    private(set) var databaseRevision = 0
    var presentedError: MACVendorDatabaseError?

    private let resolver: MACVendorResolver
    private let service: any MACVendorDatabaseServicing
    private var preparedManualDatabase: MACVendorDatabase?
    private var currentTask: Task<Void, Never>?
    private var currentOperationID: UUID?

    init(
        resolver: MACVendorResolver,
        service: any MACVendorDatabaseServicing
    ) {
        self.resolver = resolver
        self.service = service
    }

    func loadInstalledDatabase() async {
        guard availability == .loading else { return }
        await run(operation: .idle) { [weak self] in
            await self?.performLoad()
        }
    }

    func downloadAndInstall() async {
        await run(
            operation: .downloading(completed: 0, total: MACVendorRegistry.allCases.count)
        ) { [weak self] in
            await self?.performDownloadAndInstall()
        }
    }

    func prepareManualImport(urls: [URL]) async {
        await run(operation: .readingFiles) { [weak self] in
            await self?.performManualPreparation(urls: urls)
        }
    }

    func confirmManualImport() async {
        guard currentTask == nil else { return }
        guard let preparedManualDatabase else {
            presentedError = .noPreparedImport
            return
        }

        await run(operation: .installing) { [weak self] in
            await self?.performInstall(preparedManualDatabase, clearsPreparedImport: true)
        }
    }

    func discardPreparedManualImport() {
        guard currentTask == nil else { return }
        preparedManualDatabase = nil
        pendingManualImport = nil
    }

    func clear() async {
        await run(operation: .clearing) { [weak self] in
            await self?.performClear()
        }
    }

    @discardableResult
    func cancelCurrentOperation() -> CancellationHandle? {
        switch operation {
        case .downloading, .readingFiles, .validating:
            break
        case .idle, .installing, .clearing:
            return nil
        }

        guard let operationID = currentOperationID, let task = currentTask else {
            return nil
        }

        let handle = CancellationHandle(operationID: operationID, task: task)
        task.cancel()
        return handle
    }

    func waitForCancellation(_ handle: CancellationHandle) async {
        await handle.task.value
        settleOperation(id: handle.operationID)
    }

    private func run(
        operation initialOperation: MACVendorDatabaseOperation,
        body: @escaping @MainActor @Sendable () async -> Void
    ) async {
        guard currentTask == nil else { return }

        let operationID = UUID()
        operation = initialOperation
        let task = Task { @MainActor in
            await body()
        }
        currentOperationID = operationID
        currentTask = task

        await task.value
        settleOperation(id: operationID)
    }

    private func settleOperation(id operationID: UUID) {
        guard currentOperationID == operationID else { return }
        currentTask = nil
        currentOperationID = nil
        operation = .idle
    }

    private func performLoad() async {
        do {
            let database = try await service.load()
            if let database {
                resolver.replaceEntries(database.entries)
                availability = .installed(database.summary)
            } else {
                resolver.replaceEntries([])
                availability = .notInstalled
            }
            databaseRevision &+= 1
            presentedError = nil
        } catch is CancellationError {
            return
        } catch let error as MACVendorDatabaseError {
            availability = .unavailable(error)
        } catch {
            availability = .unavailable(.persistenceFailure)
        }
    }

    private func performDownloadAndInstall() async {
        do {
            let database = try await service.download(createdAt: Date()) { [weak self] completed in
                await self?.publishDownloadProgress(completed)
            }
            try Task.checkCancellation()
            operation = .installing
            try await service.install(database)
            publishInstalled(database, clearsPreparedImport: false)
        } catch is CancellationError {
            return
        } catch where Task.isCancelled {
            return
        } catch let error as MACVendorDatabaseError {
            presentedError = error
        } catch {
            presentedError = .downloadFailed(.maL)
        }
    }

    private func publishDownloadProgress(_ completed: Int) {
        let total = MACVendorRegistry.allCases.count
        guard completed < total else {
            operation = .validating
            return
        }
        operation = .downloading(completed: max(0, completed), total: total)
    }

    private func performManualPreparation(urls: [URL]) async {
        do {
            let database = try await service.prepareManualImport(urls: urls, createdAt: Date())
            try Task.checkCancellation()
            preparedManualDatabase = database
            pendingManualImport = database.summary
            presentedError = nil
        } catch is CancellationError {
            return
        } catch where Task.isCancelled {
            return
        } catch let error as MACVendorDatabaseError {
            presentedError = error
        } catch {
            presentedError = .fileReadFailed(urls.first?.lastPathComponent ?? "")
        }
    }

    private func performInstall(
        _ database: MACVendorDatabase,
        clearsPreparedImport: Bool
    ) async {
        do {
            try await service.install(database)
            publishInstalled(database, clearsPreparedImport: clearsPreparedImport)
        } catch let error as MACVendorDatabaseError {
            presentedError = error
        } catch {
            presentedError = .persistenceFailure
        }
    }

    private func publishInstalled(
        _ database: MACVendorDatabase,
        clearsPreparedImport: Bool
    ) {
        resolver.replaceEntries(database.entries)
        availability = .installed(database.summary)
        if clearsPreparedImport {
            preparedManualDatabase = nil
            pendingManualImport = nil
        }
        databaseRevision &+= 1
        presentedError = nil
    }

    private func performClear() async {
        do {
            try await service.clear()
            resolver.replaceEntries([])
            availability = .notInstalled
            preparedManualDatabase = nil
            pendingManualImport = nil
            databaseRevision &+= 1
            presentedError = nil
        } catch let error as MACVendorDatabaseError {
            presentedError = error
        } catch {
            presentedError = .persistenceFailure
        }
    }
}
