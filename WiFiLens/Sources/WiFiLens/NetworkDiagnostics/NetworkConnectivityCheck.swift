import Foundation
import Network

enum NetworkPathState: Equatable, Sendable {
    case satisfied
    case unsatisfied
    case requiresConnection
}

protocol NetworkPathChecking: Sendable {
    func currentState(timeout: Duration) async -> NetworkPathState?
}

struct SystemNetworkPathChecker: NetworkPathChecking {
    func currentState(timeout: Duration) async -> NetworkPathState? {
        let monitor = NWPathMonitor()
        let stream = AsyncStream<NetworkPathState> { continuation in
            monitor.pathUpdateHandler = { path in
                let state: NetworkPathState = switch path.status {
                case .satisfied: .satisfied
                case .unsatisfied: .unsatisfied
                case .requiresConnection: .requiresConnection
                @unknown default: .requiresConnection
                }
                continuation.yield(state)
                continuation.finish()
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "io.github.kaoru.wifi-lens.network-diagnostics.path"))
        }

        return await withTaskGroup(of: NetworkPathState?.self) { group in
            group.addTask {
                for await state in stream {
                    return state
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            monitor.cancel()
            return first
        }
    }

    func diagnosticEvidence(timeout: Duration) async -> [NetworkDiagnosticEvidence] {
        let monitor = NWPathMonitor()
        let stream = AsyncStream<NWPath> { continuation in
            monitor.pathUpdateHandler = { path in
                continuation.yield(path)
                continuation.finish()
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "io.github.kaoru.wifi-lens.network-diagnostics.path-evidence"))
        }
        defer { monitor.cancel() }
        for await path in stream {
            let activeInterface = path.availableInterfaces
                .filter { path.usesInterfaceType($0.type) }
                .sorted { $0.name < $1.name }
                .first
            guard let activeInterface else { return [] }
            var evidence = [
                NetworkDiagnosticEvidence(code: "path.interface-type", value: activeInterface.type.pathEvidenceName),
                NetworkDiagnosticEvidence(code: "path.interface-name", value: activeInterface.name),
            ]
            if ["utun", "ipsec", "ppp"].contains(where: { activeInterface.name.hasPrefix($0) }) {
                evidence.append(.init(code: "path.routed-tunnel", value: activeInterface.name))
            }
            return evidence
        }
        return []
    }
}

extension NetworkPathChecking {
    func diagnosticEvidence(timeout: Duration) async -> [NetworkDiagnosticEvidence] { [] }
}

struct NetworkConnectivityCheck: DiagnosticCheck {
    let id = NetworkDiagnosticCheckID.path
    private let pathSource: any NetworkPathChecking
    private let timeout: Duration

    init(
        pathSource: any NetworkPathChecking = SystemNetworkPathChecker(),
        timeout: Duration = .seconds(3)
    ) {
        self.pathSource = pathSource
        self.timeout = timeout
    }

    func run() async -> NetworkDiagnosticResult {
        let state = await pathSource.currentState(timeout: timeout)
        let evidence = await pathSource.diagnosticEvidence(timeout: timeout)
        return switch state {
        case .satisfied:
            NetworkDiagnosticResult(
                id: id,
                status: .normal,
                summary: String(
                    localized: "network_diagnostics.path.normal.summary",
                    comment: "Network self-check system path success summary"
                ),
                detail: String(
                    localized: "network_diagnostics.path.normal.summary",
                    comment: "Network self-check system path success detail"
                ),
                evidence: evidence
            )
        case .unsatisfied:
            NetworkDiagnosticResult(
                id: id,
                status: .abnormal,
                summary: String(localized: "network_diagnostics.path.abnormal.summary", comment: "Network self-check system path failure summary"),
                evidence: evidence
            )
        case .requiresConnection, nil:
            NetworkDiagnosticResult(
                id: id,
                status: .indeterminate,
                summary: String(localized: "network_diagnostics.path.indeterminate.summary", comment: "Network self-check system path indeterminate summary"),
                evidence: evidence
            )
        }
    }
}

private extension NWInterface.InterfaceType {
    var pathEvidenceName: String {
        switch self {
        case .wifi: "wifi"
        case .wiredEthernet: "wiredEthernet"
        case .cellular: "cellular"
        case .loopback: "loopback"
        case .other: "other"
        @unknown default: "other"
        }
    }
}
