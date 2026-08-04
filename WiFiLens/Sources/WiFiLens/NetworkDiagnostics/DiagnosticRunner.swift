enum DiagnosticCheckRerunPolicy: Equatable, Sendable {
    case networkSensitive
    case configurationOnly
}

protocol DiagnosticCheck: Sendable {
    var id: NetworkDiagnosticCheckID { get }
    var rerunPolicy: DiagnosticCheckRerunPolicy { get }
    func run() async throws -> NetworkDiagnosticResult
}

extension DiagnosticCheck {
    var rerunPolicy: DiagnosticCheckRerunPolicy { .networkSensitive }
}

extension NetworkDiagnosticStatus: Hashable {}

private struct DiagnosticDependency {
    let id: NetworkDiagnosticCheckID
    let blockingStatuses: Set<NetworkDiagnosticStatus>
}

struct DiagnosticRunner: Sendable {
    let checks: [any DiagnosticCheck]
    var minimumStepDuration: Duration = .zero
    var sessionBudget: Duration = .seconds(30)

    func run(
        retaining retainedResults: [NetworkDiagnosticResult] = [],
        onResult: @escaping @Sendable (NetworkDiagnosticResult) async -> Void
    ) async -> [NetworkDiagnosticResult] {
        var results: [NetworkDiagnosticResult] = []
        let retainedByID = Dictionary(uniqueKeysWithValues: retainedResults.map { ($0.id, $0) })
        let clock = ContinuousClock()
        let sessionDeadline = clock.now.advanced(by: sessionBudget)

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
            guard let result = await run(check, until: sessionDeadline) else { break }
            let presentationDeadline = started.advanced(by: minimumStepDuration)
            try? await clock.sleep(until: min(presentationDeadline, sessionDeadline))
            guard !Task.isCancelled else { break }
            results.append(result)
            await onResult(result)
        }

        return results
    }

    private func run(
        _ check: any DiagnosticCheck,
        until deadline: ContinuousClock.Instant
    ) async -> NetworkDiagnosticResult? {
        let clock = ContinuousClock()
        let remaining = clock.now.duration(to: deadline)
        guard remaining > .zero else { return nil }
        let task = Task { try await check.run() }
        return await withTaskGroup(of: NetworkDiagnosticResult?.self) { group in
            group.addTask {
                do {
                    return try await task.value
                } catch {
                    return nil
                }
            }
            group.addTask {
                try? await clock.sleep(for: remaining)
                task.cancel()
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    private func blockingResult(
        for id: NetworkDiagnosticCheckID,
        from results: [NetworkDiagnosticResult]
    ) -> NetworkDiagnosticResult? {
        let hardFailureStatuses: Set<NetworkDiagnosticStatus> = [.abnormal, .blocked]
        let dependencies: [DiagnosticDependency] = switch id {
        case .path:
            []
        case .gatewayReachability:
            [.init(id: .path, blockingStatuses: hardFailureStatuses)]
        case .dns:
            [.init(id: .path, blockingStatuses: hardFailureStatuses)]
        case .internet, .ipv6:
            [
                .init(id: .path, blockingStatuses: hardFailureStatuses),
                .init(id: .dns, blockingStatuses: hardFailureStatuses),
            ]
        case .proxy:
            [.init(id: .path, blockingStatuses: hardFailureStatuses)]
        }
        return dependencies.compactMap { dependency -> NetworkDiagnosticResult? in
            guard let result = results.first(where: { $0.id == dependency.id }),
                  dependency.blockingStatuses.contains(result.status) else {
                return nil
            }
            return result
        }.first
    }
}
