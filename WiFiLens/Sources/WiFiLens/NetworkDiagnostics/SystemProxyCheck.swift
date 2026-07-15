import CFNetwork
import Foundation
import Network

struct ProxyEndpoint: Hashable, Sendable {
    let host: String
    let port: UInt16

    init(host: String, port: UInt16) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.port = port
    }
}

struct SystemProxyConfiguration: Equatable, Sendable {
    var endpoints: [ProxyEndpoint] = []
    var pacEnabled = false
    var pacURL: String?
    var autoDiscoveryEnabled = false
    var hasInvalidExplicitProxy = false

    static let disabled = SystemProxyConfiguration()

    init(
        endpoints: [ProxyEndpoint] = [],
        pacEnabled: Bool = false,
        pacURL: String? = nil,
        autoDiscoveryEnabled: Bool = false,
        hasInvalidExplicitProxy: Bool = false
    ) {
        self.endpoints = endpoints
        self.pacEnabled = pacEnabled
        self.pacURL = pacURL
        self.autoDiscoveryEnabled = autoDiscoveryEnabled
        self.hasInvalidExplicitProxy = hasInvalidExplicitProxy
    }

    init(settings: [String: Any]) {
        var endpoints: [ProxyEndpoint] = []
        var seen: Set<ProxyEndpoint> = []
        var invalid = false

        for keys in [
            ("HTTPEnable", "HTTPProxy", "HTTPPort"),
            ("HTTPSEnable", "HTTPSProxy", "HTTPSPort"),
            ("SOCKSEnable", "SOCKSProxy", "SOCKSPort"),
        ] where Self.isEnabled(settings[keys.0]) {
            guard
                let rawHost = settings[keys.1] as? String,
                !rawHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                let rawPort = Self.integer(settings[keys.2]),
                (1...Int(UInt16.max)).contains(rawPort)
            else {
                invalid = true
                continue
            }

            let endpoint = ProxyEndpoint(host: rawHost, port: UInt16(rawPort))
            if seen.insert(endpoint).inserted {
                endpoints.append(endpoint)
            }
        }

        self.init(
            endpoints: endpoints,
            pacEnabled: Self.isEnabled(settings["ProxyAutoConfigEnable"]),
            pacURL: Self.nonemptyString(settings["ProxyAutoConfigURLString"]),
            autoDiscoveryEnabled: Self.isEnabled(settings["ProxyAutoDiscoveryEnable"]),
            hasInvalidExplicitProxy: invalid
        )
    }

    private static func isEnabled(_ value: Any?) -> Bool {
        integer(value).map { $0 != 0 } ?? false
    }

    private static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        return value as? Int
    }

    private static func nonemptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

protocol SystemProxySettingsReading: Sendable {
    func read() -> SystemProxyConfiguration?
}

struct SystemProxySettingsReader: SystemProxySettingsReading {
    func read() -> SystemProxyConfiguration? {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return SystemProxyConfiguration(settings: settings)
    }
}

protocol ProxyEndpointConnecting: Sendable {
    func canConnect(to endpoint: ProxyEndpoint, timeout: Duration) async -> Bool
}

struct NetworkProxyEndpointConnector: ProxyEndpointConnecting {
    func canConnect(to endpoint: ProxyEndpoint, timeout: Duration) async -> Bool {
        guard let port = NWEndpoint.Port(rawValue: endpoint.port) else { return false }
        let connection = NWConnection(host: NWEndpoint.Host(endpoint.host), port: port, using: .tcp)

        return await withCheckedContinuation { continuation in
            let context = ProxyConnectionContext(connection: connection, continuation: continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    context.finish(true)
                case .failed, .cancelled:
                    context.finish(false)
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue(label: "io.github.kaoru.wifi-lens.network-diagnostics.proxy"))
            Task {
                try? await Task.sleep(for: timeout)
                context.finish(false)
            }
        }
    }
}

private final class ProxyConnectionContext: @unchecked Sendable {
    private let lock = NSLock()
    private let connection: NWConnection
    private var continuation: CheckedContinuation<Bool, Never>?

    init(connection: NWConnection, continuation: CheckedContinuation<Bool, Never>) {
        self.connection = connection
        self.continuation = continuation
    }

    func finish(_ reachable: Bool) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        connection.cancel()
        continuation.resume(returning: reachable)
    }
}

struct SystemProxyCheck: DiagnosticCheck {
    let id = NetworkDiagnosticCheckID.proxy
    private let settingsReader: any SystemProxySettingsReading
    private let connector: any ProxyEndpointConnecting
    private let timeout: Duration

    init(
        settingsReader: any SystemProxySettingsReading = SystemProxySettingsReader(),
        connector: any ProxyEndpointConnecting = NetworkProxyEndpointConnector(),
        timeout: Duration = .seconds(3)
    ) {
        self.settingsReader = settingsReader
        self.connector = connector
        self.timeout = timeout
    }

    func run() async -> NetworkDiagnosticResult {
        guard let configuration = settingsReader.read() else {
            return result(.indeterminate, key: "network_diagnostics.proxy.indeterminate.summary")
        }

        let allReachable = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            for endpoint in configuration.endpoints {
                group.addTask {
                    await connector.canConnect(to: endpoint, timeout: timeout)
                }
            }
            for await reachable in group where !reachable {
                group.cancelAll()
                return false
            }
            return true
        }

        if !allReachable {
            return result(.abnormal, key: "network_diagnostics.proxy.abnormal.summary")
        }
        if configuration.hasInvalidExplicitProxy
            || configuration.pacEnabled
            || configuration.autoDiscoveryEnabled {
            return result(.indeterminate, key: "network_diagnostics.proxy.indeterminate.summary")
        }
        if configuration.endpoints.isEmpty {
            return result(.normal, key: "network_diagnostics.proxy.disabled.summary")
        }
        return result(.normal, key: "network_diagnostics.proxy.normal.summary")
    }

    private func result(_ status: NetworkDiagnosticStatus, key: String.LocalizationValue) -> NetworkDiagnosticResult {
        NetworkDiagnosticResult(
            id: id,
            status: status,
            summary: String(localized: key, comment: "Network self-check system proxy result summary")
        )
    }
}
