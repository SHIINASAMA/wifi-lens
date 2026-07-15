import Foundation
import dnssd

enum DNSResolutionOutcome: Equatable, Sendable {
    case resolved
    case failed
    case indeterminate
}

protocol DNSResolving: Sendable {
    func resolve(host: String, timeout: Duration) async -> DNSResolutionOutcome
}

struct SystemDNSResolver: DNSResolving {
    func resolve(host: String, timeout: Duration) async -> DNSResolutionOutcome {
        await withCheckedContinuation { continuation in
            let context = DNSResolutionContext(continuation: continuation)
            var serviceRef: DNSServiceRef?
            let opaqueContext = Unmanaged.passUnretained(context).toOpaque()
            let error = DNSServiceGetAddrInfo(
                &serviceRef,
                0,
                0,
                0,
                host,
                { _, _, _, errorCode, _, address, _, opaqueContext in
                    guard let opaqueContext else { return }
                    let context = Unmanaged<DNSResolutionContext>
                        .fromOpaque(opaqueContext)
                        .takeUnretainedValue()
                    if errorCode == kDNSServiceErr_NoError, address != nil {
                        context.finish(.resolved)
                    } else {
                        context.finish(.failed)
                    }
                },
                opaqueContext
            )

            guard error == kDNSServiceErr_NoError, let serviceRef else {
                context.finish(.failed)
                return
            }

            context.install(serviceRef: serviceRef)
            DNSServiceSetDispatchQueue(
                serviceRef,
                DispatchQueue(label: "io.github.kaoru.wifi-lens.network-diagnostics.dns")
            )

            Task {
                try? await Task.sleep(for: timeout)
                context.finish(.indeterminate)
            }
        }
    }
}

private final class DNSResolutionContext: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<DNSResolutionOutcome, Never>?
    private var serviceRef: DNSServiceRef?

    init(continuation: CheckedContinuation<DNSResolutionOutcome, Never>) {
        self.continuation = continuation
    }

    func install(serviceRef: DNSServiceRef) {
        lock.lock()
        if continuation == nil {
            lock.unlock()
            DNSServiceRefDeallocate(serviceRef)
            return
        }
        self.serviceRef = serviceRef
        lock.unlock()
    }

    func finish(_ outcome: DNSResolutionOutcome) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        let serviceRef = self.serviceRef
        self.serviceRef = nil
        lock.unlock()

        if let serviceRef {
            DNSServiceRefDeallocate(serviceRef)
        }
        continuation.resume(returning: outcome)
    }
}

struct DNSResolutionCheck: DiagnosticCheck {
    let id = NetworkDiagnosticCheckID.dns
    private let resolver: any DNSResolving
    private let host: String
    private let timeout: Duration

    init(
        resolver: any DNSResolving = SystemDNSResolver(),
        host: String = "example.com",
        timeout: Duration = .seconds(5)
    ) {
        self.resolver = resolver
        self.host = host
        self.timeout = timeout
    }

    func run() async -> NetworkDiagnosticResult {
        let outcome = await resolver.resolve(host: host, timeout: timeout)
        return switch outcome {
        case .resolved:
            NetworkDiagnosticResult(
                id: id,
                status: .normal,
                summary: String(localized: "network_diagnostics.dns.normal.summary", comment: "Network self-check DNS success summary")
            )
        case .failed:
            NetworkDiagnosticResult(
                id: id,
                status: .abnormal,
                summary: String(localized: "network_diagnostics.dns.abnormal.summary", comment: "Network self-check DNS failure summary")
            )
        case .indeterminate:
            NetworkDiagnosticResult(
                id: id,
                status: .indeterminate,
                summary: String(localized: "network_diagnostics.dns.indeterminate.summary", comment: "Network self-check DNS indeterminate summary")
            )
        }
    }
}
