import Foundation
import Observation

enum NetworkDiagnosticsPagePhase: Equatable, Sendable {
    case idle
    case running
    case completed
}

enum NetworkDiagnosticExecutionPhase: Equatable, Sendable {
    case waiting
    case checking
    case completed
}

enum NetworkDiagnosticsWorkbenchLayoutMode: Equatable, Sendable {
    case compact
    case condensed
    case regular
}

enum NetworkDiagnosticsWorkbenchLayout {
    static func mode(for availableWidth: Double) -> NetworkDiagnosticsWorkbenchLayoutMode {
        if availableWidth >= 720 { return .regular }
        if availableWidth >= 520 { return .condensed }
        return .compact
    }
}

enum NetworkDiagnosticsTablePresentation {
    static let minimumRowHeight = 54.0
    static let usesAlternatingRowBackgrounds = false
}

struct NetworkDiagnosticsWorkbenchRow: Equatable, Identifiable, Sendable {
    let id: NetworkDiagnosticCheckID
    let executionPhase: NetworkDiagnosticExecutionPhase
    let result: NetworkDiagnosticResult?
}

enum NetworkDiagnosticsPresentation {
    static func workbenchRows(
        pagePhase: NetworkDiagnosticsPagePhase,
        executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase],
        results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult]
    ) -> [NetworkDiagnosticsWorkbenchRow] {
        guard pagePhase != .idle else { return [] }

        return NetworkDiagnosticCheckID.allCases.compactMap { id in
            let executionPhase = executionPhases[id] ?? .waiting
            if pagePhase == .running, executionPhase == .waiting {
                return nil
            }
            guard pagePhase != .completed || results[id] != nil else {
                return nil
            }
            return NetworkDiagnosticsWorkbenchRow(
                id: id,
                executionPhase: executionPhase,
                result: results[id]
            )
        }
    }

}

@MainActor
@Observable
final class NetworkDiagnosticsViewModel {
    static let defaultMinimumStepDuration = Duration.milliseconds(800)

    private(set) var phase = NetworkDiagnosticsPagePhase.idle
    private(set) var executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase]
    private(set) var results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [:]
    private(set) var conclusion: NetworkDiagnosticConclusion?

    @ObservationIgnored private let checks: [any DiagnosticCheck]
    @ObservationIgnored private let minimumStepDuration: Duration
    @ObservationIgnored private var activeTask: Task<Void, Never>?

    init(checks: [any DiagnosticCheck] = [
        NetworkConnectivityCheck(),
        DNSResolutionCheck(),
        SystemProxyCheck(),
    ], minimumStepDuration: Duration = NetworkDiagnosticsViewModel.defaultMinimumStepDuration) {
        self.checks = checks
        self.minimumStepDuration = minimumStepDuration
        self.executionPhases = Dictionary(
            uniqueKeysWithValues: NetworkDiagnosticCheckID.allCases.map { ($0, .waiting) }
        )
    }

    deinit {
        activeTask?.cancel()
    }

    @discardableResult
    func start() -> Bool {
        guard activeTask == nil else { return false }

        results = [:]
        conclusion = nil
        phase = .running
        executionPhases = Dictionary(
            uniqueKeysWithValues: NetworkDiagnosticCheckID.allCases.map { ($0, .waiting) }
        )
        if let first = NetworkDiagnosticCheckID.allCases.first {
            executionPhases[first] = .checking
        }

        let runner = DiagnosticRunner(
            checks: checks,
            minimumStepDuration: minimumStepDuration
        )
        activeTask = Task { [weak self] in
            let results = await runner.run { [weak self] result in
                await self?.accept(result)
            }
            self?.finish(results)
        }
        return true
    }

    func waitForCompletion() async {
        let task = activeTask
        await task?.value
    }

    private func accept(_ result: NetworkDiagnosticResult) {
        results[result.id] = result
        executionPhases[result.id] = .completed

        guard let index = NetworkDiagnosticCheckID.allCases.firstIndex(of: result.id) else { return }
        let nextIndex = NetworkDiagnosticCheckID.allCases.index(after: index)
        if nextIndex < NetworkDiagnosticCheckID.allCases.endIndex {
            executionPhases[NetworkDiagnosticCheckID.allCases[nextIndex]] = .checking
        }
    }

    private func finish(_ orderedResults: [NetworkDiagnosticResult]) {
        defer { activeTask = nil }
        guard !Task.isCancelled, let conclusion = NetworkDiagnosticConclusion.evaluate(orderedResults) else {
            phase = .idle
            return
        }
        self.conclusion = conclusion
        phase = .completed
    }
}
