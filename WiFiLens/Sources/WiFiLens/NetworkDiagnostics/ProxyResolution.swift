import CFNetwork
import Foundation

enum EffectiveProxy: Equatable, Sendable {
    case direct
    case http(ProxyEndpoint)
    case https(ProxyEndpoint)
    case socks(ProxyEndpoint)
    case unavailable(String)
}

protocol ProxyResolving: Sendable {
    func resolve(for url: URL) async -> EffectiveProxy
}

enum ProxyResolutionDirective: Equatable, Sendable {
    case direct
    case http(ProxyEndpoint)
    case https(ProxyEndpoint)
    case socks(ProxyEndpoint)
    case pac(URL)
    case unavailable(String)

    var effectiveProxy: EffectiveProxy {
        switch self {
        case .direct:
            .direct
        case .http(let endpoint):
            .http(endpoint)
        case .https(let endpoint):
            .https(endpoint)
        case .socks(let endpoint):
            .socks(endpoint)
        case .pac:
            .unavailable("pac-execution-invalid")
        case .unavailable(let reason):
            .unavailable(reason)
        }
    }
}

protocol ProxyConfigurationResolving: Sendable {
    func resolution(for url: URL) -> ProxyResolutionDirective
}

protocol PACResolving: Sendable {
    func resolve(pacURL: URL, targetURL: URL, timeout: Duration) async -> EffectiveProxy
}

struct SystemProxyResolver: ProxyResolving {
    private let pacTimeout: Duration
    private let configurationResolver: any ProxyConfigurationResolving
    private let pacResolver: any PACResolving

    init(
        pacTimeout: Duration = .seconds(5),
        configurationResolver: any ProxyConfigurationResolving = CFNetworkProxyConfigurationResolver(),
        pacResolver: any PACResolving = SystemPACResolver()
    ) {
        self.pacTimeout = pacTimeout
        self.configurationResolver = configurationResolver
        self.pacResolver = pacResolver
    }

    func resolve(for url: URL) async -> EffectiveProxy {
        let resolution = configurationResolver.resolution(for: url)
        guard case .pac(let pacURL) = resolution else {
            return resolution.effectiveProxy
        }
        return await pacResolver.resolve(pacURL: pacURL, targetURL: url, timeout: pacTimeout)
    }

    static func directive(from value: Any) -> ProxyResolutionDirective {
        guard
            let dictionary = value as? NSDictionary,
            let type = dictionary[kCFProxyTypeKey] as? NSString
        else {
            return .unavailable("resolution-invalid")
        }

        if type == kCFProxyTypeNone as NSString {
            return .direct
        }
        if type == kCFProxyTypeAutoConfigurationURL as NSString {
            guard let pacURL = dictionary[kCFProxyAutoConfigurationURLKey] as? URL else {
                return .unavailable("pac-url-unavailable")
            }
            return .pac(pacURL)
        }
        if type == kCFProxyTypeAutoConfigurationJavaScript as NSString {
            return .unavailable("pac-url-unavailable")
        }
        if type == kCFProxyTypeHTTP as NSString {
            return endpoint(in: dictionary).map(ProxyResolutionDirective.http)
                ?? .unavailable("proxy-endpoint-invalid")
        }
        if type == kCFProxyTypeHTTPS as NSString {
            return endpoint(in: dictionary).map(ProxyResolutionDirective.https)
                ?? .unavailable("proxy-endpoint-invalid")
        }
        if type == kCFProxyTypeSOCKS as NSString {
            return endpoint(in: dictionary).map(ProxyResolutionDirective.socks)
                ?? .unavailable("proxy-endpoint-invalid")
        }
        return .unavailable("proxy-type-unsupported")
    }

    private static func endpoint(in dictionary: NSDictionary) -> ProxyEndpoint? {
        guard
            let host = dictionary[kCFProxyHostNameKey] as? String,
            let portNumber = dictionary[kCFProxyPortNumberKey] as? NSNumber,
            (1...Int(UInt16.max)).contains(portNumber.intValue)
        else {
            return nil
        }
        return ProxyEndpoint(host: host, port: UInt16(portNumber.intValue))
    }
}

struct CFNetworkProxyConfigurationResolver: ProxyConfigurationResolving {
    func resolution(for url: URL) -> ProxyResolutionDirective {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() else {
            return .unavailable("settings-unavailable")
        }

        let proxyList = CFNetworkCopyProxiesForURL(url as CFURL, settings).takeRetainedValue()
        guard let firstProxy = (proxyList as NSArray).firstObject else {
            return .unavailable("resolution-empty")
        }

        return SystemProxyResolver.directive(from: firstProxy)
    }
}

struct SystemPACResolver: PACResolving {
    func resolve(pacURL: URL, targetURL: URL, timeout: Duration) async -> EffectiveProxy {
        let context = PACResolutionContext()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                context.start(
                    pacURL: pacURL,
                    targetURL: targetURL,
                    timeout: timeout,
                    continuation: continuation
                )
            }
        } onCancel: {
            context.cancel()
        }
    }
}

private final class PACResolutionContext: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<EffectiveProxy, Never>?
    private var source: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var cancellationRequested = false

    func start(
        pacURL: URL,
        targetURL: URL,
        timeout: Duration,
        continuation: CheckedContinuation<EffectiveProxy, Never>
    ) {
        lock.lock()
        guard !cancellationRequested else {
            lock.unlock()
            continuation.resume(returning: .unavailable("pac-cancelled"))
            return
        }
        self.continuation = continuation
        lock.unlock()

        var clientContext = CFStreamClientContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let source = CFNetworkExecuteProxyAutoConfigurationURL(
            pacURL as CFURL,
            targetURL as CFURL,
            proxyAutoConfigurationCallback,
            &clientContext
        )

        lock.lock()
        guard self.continuation != nil else {
            lock.unlock()
            CFRunLoopSourceInvalidate(source)
            return
        }
        self.source = source
        lock.unlock()

        DispatchQueue(label: "io.github.kaoru.wifi-lens.network-diagnostics.pac").async { [self] in
            run(timeout: timeout)
        }
    }

    func receive(proxyList: CFArray, error: CFError?) {
        guard error == nil, let firstProxy = (proxyList as NSArray).firstObject else {
            finish(.unavailable("pac-execution-failed"))
            return
        }
        finish(SystemProxyResolver.directive(from: firstProxy).effectiveProxy)
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let hasContinuation = continuation != nil
        lock.unlock()
        if hasContinuation {
            finish(.unavailable("pac-cancelled"))
        }
    }

    private func run(timeout: Duration) {
        let runLoop = CFRunLoopGetCurrent()

        lock.lock()
        guard continuation != nil, let source else {
            lock.unlock()
            return
        }
        self.runLoop = runLoop
        lock.unlock()

        CFRunLoopAddSource(runLoop, source, .defaultMode)
        CFRunLoopRunInMode(.defaultMode, timeout.proxyResolutionTimeInterval, false)
        finish(.unavailable("pac-timeout"))
    }

    private func finish(_ resolution: EffectiveProxy) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        let source = self.source
        self.source = nil
        let runLoop = self.runLoop
        self.runLoop = nil
        lock.unlock()

        if let source {
            CFRunLoopSourceInvalidate(source)
        }
        if let runLoop {
            CFRunLoopStop(runLoop)
            CFRunLoopWakeUp(runLoop)
        }
        continuation.resume(returning: resolution)
    }
}

private func proxyAutoConfigurationCallback(
    client: UnsafeMutableRawPointer,
    proxyList: CFArray,
    error: CFError?
) {
    Unmanaged<PACResolutionContext>
        .fromOpaque(client)
        .takeUnretainedValue()
        .receive(proxyList: proxyList, error: error)
}

private extension Duration {
    var proxyResolutionTimeInterval: TimeInterval {
        let components = self.components
        return max(
            0.001,
            Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
        )
    }
}
