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

struct ProxyEgressResponse: Equatable, Sendable {
    let statusCode: Int?
    let errorCode: String?
}

protocol ProxyEgressLoading: Sendable {
    func load(
        url: URL,
        through proxy: EffectiveProxy,
        timeout: Duration
    ) async -> ProxyEgressResponse
}

struct SystemProxyEgressLoader: ProxyEgressLoading {
    func load(
        url: URL,
        through proxy: EffectiveProxy,
        timeout: Duration
    ) async -> ProxyEgressResponse {
        guard let configuration = Self.configuration(for: proxy, timeout: timeout) else {
            return ProxyEgressResponse(statusCode: nil, errorCode: "proxy-type-unavailable")
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout.proxyCheckTimeInterval
        )
        request.httpMethod = "GET"

        let session = URLSession(
            configuration: configuration,
            delegate: ProxyEgressRedirectDelegate(),
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        do {
            let (_, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                return ProxyEgressResponse(statusCode: nil, errorCode: "non-http-response")
            }
            return ProxyEgressResponse(statusCode: response.statusCode, errorCode: nil)
        } catch let error as URLError {
            return Self.response(for: error)
        } catch {
            return ProxyEgressResponse(statusCode: nil, errorCode: "request-failed")
        }
    }

    static func response(for error: URLError) -> ProxyEgressResponse {
        if error.code == .userAuthenticationRequired {
            return ProxyEgressResponse(statusCode: 407, errorCode: nil)
        }
        return ProxyEgressResponse(statusCode: nil, errorCode: String(error.code.rawValue))
    }

    static func configuration(
        for proxy: EffectiveProxy,
        timeout: Duration
    ) -> URLSessionConfiguration? {
        let proxyConfiguration: ProxyConfiguration
        switch proxy {
        case .http(let endpoint):
            guard let networkEndpoint = endpoint.networkEndpoint else { return nil }
            proxyConfiguration = ProxyConfiguration(
                httpCONNECTProxy: networkEndpoint
            )
        case .https(let endpoint):
            guard let networkEndpoint = endpoint.networkEndpoint else { return nil }
            proxyConfiguration = ProxyConfiguration(
                httpCONNECTProxy: networkEndpoint,
                tlsOptions: NWProtocolTLS.Options()
            )
        case .socks(let endpoint):
            guard let networkEndpoint = endpoint.networkEndpoint else { return nil }
            proxyConfiguration = ProxyConfiguration(socksv5Proxy: networkEndpoint)
        case .direct, .unavailable:
            return nil
        }

        var selectedProxyConfiguration = proxyConfiguration
        selectedProxyConfiguration.allowFailover = false

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = timeout.proxyCheckTimeInterval
        configuration.timeoutIntervalForResource = timeout.proxyCheckTimeInterval
        configuration.proxyConfigurations = [selectedProxyConfiguration]
        return configuration
    }
}

private extension ProxyEndpoint {
    var networkEndpoint: NWEndpoint? {
        guard let networkPort = NWEndpoint.Port(rawValue: port) else { return nil }
        return .hostPort(
            host: NWEndpoint.Host(host),
            port: networkPort
        )
    }
}

struct SystemProxyCheck: DiagnosticCheck {
    let id = NetworkDiagnosticCheckID.proxy
    private let resolver: any ProxyResolving
    private let connector: any ProxyEndpointConnecting
    private let egressLoader: any ProxyEgressLoading
    private let controlURL: URL
    private let timeout: Duration

    init(
        resolver: any ProxyResolving = SystemProxyResolver(),
        connector: any ProxyEndpointConnecting = NetworkProxyEndpointConnector(),
        egressLoader: any ProxyEgressLoading = SystemProxyEgressLoader(),
        controlURL: URL = HTTPSControlEndpointCheck().captivePortalEndpoint,
        timeout: Duration = .seconds(3)
    ) {
        self.resolver = resolver
        self.connector = connector
        self.egressLoader = egressLoader
        self.controlURL = controlURL
        self.timeout = timeout
    }

    func run() async -> NetworkDiagnosticResult {
        let proxy = await resolver.resolve(for: controlURL)
        if proxy == .direct {
            return result(.normal, key: "network_diagnostics.proxy.disabled.summary")
        }

        if case .unavailable(let reason) = proxy {
            if reason.hasPrefix("pac-") {
                return result(
                    .indeterminate,
                    key: "network_diagnostics.proxy.pac_unavailable.summary",
                    evidence: [.init(code: "proxy.pac-unavailable", value: reason)]
                )
            }
            return result(
                .indeterminate,
                key: "network_diagnostics.proxy.indeterminate.summary",
                evidence: [.init(code: "proxy.resolution-unavailable", value: reason)]
            )
        }

        guard let endpoint = proxy.endpoint else {
            return result(.indeterminate, key: "network_diagnostics.proxy.indeterminate.summary")
        }
        guard await connector.canConnect(to: endpoint, timeout: timeout) else {
            return result(
                .abnormal,
                key: "network_diagnostics.proxy.endpoint_unavailable.summary",
                evidence: [.init(code: "proxy.endpoint-unavailable", value: nil)]
            )
        }

        let response = await egressLoader.load(url: controlURL, through: proxy, timeout: timeout)
        if response.statusCode == 407 {
            return result(
                .abnormal,
                key: "network_diagnostics.proxy.authentication_required.summary",
                evidence: [.init(code: "proxy.authentication-required", value: "407")]
            )
        }
        guard let statusCode = response.statusCode, (200..<300).contains(statusCode) else {
            return result(
                .abnormal,
                key: "network_diagnostics.proxy.egress_unavailable.summary",
                evidence: [
                    .init(
                        code: "proxy.egress-unavailable",
                        value: response.errorCode ?? response.statusCode.map(String.init) ?? "unknown"
                    ),
                ]
            )
        }
        return result(
            .normal,
            key: "network_diagnostics.proxy.normal.summary",
            evidence: [.init(code: "proxy.egress-available", value: String(statusCode))]
        )
    }

    private func result(
        _ status: NetworkDiagnosticStatus,
        key: String.LocalizationValue,
        evidence: [NetworkDiagnosticEvidence] = []
    ) -> NetworkDiagnosticResult {
        NetworkDiagnosticResult(
            id: id,
            status: status,
            summary: String(localized: key, comment: "Network self-check system proxy result summary"),
            evidence: evidence
        )
    }
}

private extension EffectiveProxy {
    var endpoint: ProxyEndpoint? {
        switch self {
        case .http(let endpoint), .https(let endpoint), .socks(let endpoint):
            endpoint
        case .direct, .unavailable:
            nil
        }
    }
}

private final class ProxyEgressRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private extension Duration {
    var proxyCheckTimeInterval: TimeInterval {
        let components = self.components
        return max(
            0.001,
            Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
        )
    }
}
