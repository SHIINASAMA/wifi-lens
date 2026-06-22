import Foundation

protocol GatewayLatencyProviding: Sendable {
    func measure(routerIP: String?) async -> GatewayLatencyResult
}

struct GatewayLatencyProvider: GatewayLatencyProviding {
    private let pinger = GatewayPinger()

    func measure(routerIP: String?) async -> GatewayLatencyResult {
        guard let routerIP else {
            return GatewayLatencyResult(
                timestamp: Date(),
                error: .missingRouterIP
            )
        }
        let latency = await pinger.ping(host: routerIP)
        return GatewayLatencyResult(
            timestamp: Date(),
            routerIP: routerIP,
            latencyMs: latency
        )
    }
}
