enum DiagnosticCheckRerunPolicy: Equatable, Sendable {
    case networkSensitive
    case configurationOnly
}

protocol DiagnosticCheck: Sendable {
    var id: NetworkDiagnosticCheckID { get }
    var rerunPolicy: DiagnosticCheckRerunPolicy { get }
    func run() async -> NetworkDiagnosticResult
}

extension DiagnosticCheck {
    var rerunPolicy: DiagnosticCheckRerunPolicy { .networkSensitive }
}

struct DiagnosticRunner: Sendable {
    let checks: [any DiagnosticCheck]
    var minimumStepDuration: Duration = .zero

    func run(
        retaining retainedResults: [NetworkDiagnosticResult] = [],
        onResult: @escaping @Sendable (NetworkDiagnosticResult) async -> Void
    ) async -> [NetworkDiagnosticResult] {
        var results: [NetworkDiagnosticResult] = []
        let retainedByID = Dictionary(uniqueKeysWithValues: retainedResults.map { ($0.id, $0) })
        let clock = ContinuousClock()

        for check in checks {
            guard !Task.isCancelled else { break }
            if let retainedResult = retainedByID[check.id] {
                results.append(retainedResult)
                continue
            }
            if let blocker = blockingResult(for: check.id, from: results) {
                let result = NetworkDiagnosticResult(
                    id: check.id,
                    status: .blocked,
                    summary: blocker.summary,
                    detail: blocker.summary,
                    evidence: [.init(code: "blocked.by", value: blocker.id.rawValue)]
                )
                results.append(result)
                await onResult(result)
                continue
            }
            let started = clock.now
            let result = await check.run()
            try? await clock.sleep(until: started.advanced(by: minimumStepDuration))
            guard !Task.isCancelled else { break }
            results.append(result)
            await onResult(result)
        }

        return results
    }

    private func blockingResult(
        for id: NetworkDiagnosticCheckID,
        from results: [NetworkDiagnosticResult]
    ) -> NetworkDiagnosticResult? {
        let dependencies: [NetworkDiagnosticCheckID] = switch id {
        case .path:
            []
        case .dns:
            [.path]
        case .internet, .ipv6:
            [.path, .dns]
        case .proxy:
            [.path]
        }
        return dependencies.compactMap { dependency in
            results.first { $0.id == dependency }
        }.first { $0.status != .normal }
    }
}
