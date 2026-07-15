protocol DiagnosticCheck: Sendable {
    func run() async -> NetworkDiagnosticResult
}

struct DiagnosticRunner: Sendable {
    let checks: [any DiagnosticCheck]
    var minimumStepDuration: Duration = .zero

    func run(
        onResult: @escaping @Sendable (NetworkDiagnosticResult) async -> Void
    ) async -> [NetworkDiagnosticResult] {
        var results: [NetworkDiagnosticResult] = []
        let clock = ContinuousClock()

        for check in checks {
            guard !Task.isCancelled else { break }
            let started = clock.now
            let result = await check.run()
            try? await clock.sleep(until: started.advanced(by: minimumStepDuration))
            guard !Task.isCancelled else { break }
            results.append(result)
            await onResult(result)
        }

        return results
    }
}
