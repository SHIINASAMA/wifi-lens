import Foundation

protocol GatewayLatencyProviding: Sendable {
    func measure(routerIP: String?) async -> GatewayLatencyResult
}

protocol GatewayPinging: Sendable {
    func ping(host: String) async -> Double?
}

extension GatewayPinger: GatewayPinging {}

struct GatewayLatencyProvider: GatewayLatencyProviding {
    private let pinger: GatewayPinging

    init(pinger: GatewayPinging = GatewayPinger()) {
        self.pinger = pinger
    }

    func measure(routerIP: String?) async -> GatewayLatencyResult {
        guard let routerIP else {
            return GatewayLatencyResult(
                timestamp: Date(),
                error: .missingRouterIP
            )
        }
        let latency = await pinger.ping(host: routerIP)
        guard let latency else {
            return GatewayLatencyResult(
                timestamp: Date(),
                routerIP: routerIP,
                error: .gatewayPingFailed(routerIP)
            )
        }
        return GatewayLatencyResult(
            timestamp: Date(),
            routerIP: routerIP,
            latencyMs: latency
        )
    }
}
